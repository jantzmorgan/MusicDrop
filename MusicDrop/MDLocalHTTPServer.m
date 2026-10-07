#import "MDLocalHTTPServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <signal.h>

@interface MDLocalHTTPServer ()
@property (nonatomic) int serverFD;
@property (nonatomic) uint16_t port;
@property (nonatomic, strong) dispatch_queue_t acceptQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *files;
@end

@implementation MDLocalHTTPServer

+ (instancetype)sharedServer {
    static MDLocalHTTPServer *server;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ server = [MDLocalHTTPServer new]; });
    return server;
}

- (instancetype)init {
    if ((self = [super init])) {
        _serverFD = -1;
        _acceptQueue = dispatch_queue_create("com.jantzmorgan.musicdrop.http.accept", DISPATCH_QUEUE_SERIAL);
        _files = [NSMutableDictionary dictionary];
        signal(SIGPIPE, SIG_IGN);
    }
    return self;
}

- (BOOL)start:(NSError **)error {
    @synchronized (self) {
        if (self.serverFD >= 0) return YES;

        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return [self fail:error message:@"Could not create local import bridge."];

        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

        struct sockaddr_in addr = {0};
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port = htons(0);
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) { close(fd); return [self fail:error message:@"Could not bind local import bridge."]; }
        if (listen(fd, 16) != 0) { close(fd); return [self fail:error message:@"Could not start local import bridge."]; }

        socklen_t len = sizeof(addr);
        if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) { close(fd); return [self fail:error message:@"Could not determine local import port."]; }

        self.serverFD = fd;
        self.port = ntohs(addr.sin_port);
        dispatch_async(self.acceptQueue, ^{ [self acceptLoop]; });
        return YES;
    }
}

- (BOOL)fail:(NSError **)error message:(NSString *)message {
    if (error) *error = [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.http" code:4001 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}

- (NSURL *)URLForFileURL:(NSURL *)fileURL error:(NSError **)error {
    if (![self start:error]) return nil;
    if (!fileURL.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        if (error) *error = [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.http" code:4002 userInfo:@{NSLocalizedDescriptionKey:@"Selected audio file is unavailable."}];
        return nil;
    }
    NSString *key = [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString.lowercaseString,
                     fileURL.pathExtension.lowercaseString.length ? fileURL.pathExtension.lowercaseString : @"bin"];
    @synchronized (self.files) { self.files[key] = fileURL; }
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu/%@", self.port, key]];
}

- (void)acceptLoop {
    while (true) {
        int fd = self.serverFD;
        if (fd < 0) break;
        int client = accept(fd, NULL, NULL);
        if (client < 0) continue;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [self handleClient:client];
            close(client);
        });
    }
}

- (BOOL)sendBytes:(int)fd bytes:(const void *)bytes length:(NSUInteger)length {
    const uint8_t *cursor = bytes;
    NSUInteger remaining = length;
    while (remaining) {
        ssize_t n = send(fd, cursor, remaining, MSG_NOSIGNAL);
        if (n <= 0) return NO;
        cursor += n;
        remaining -= (NSUInteger)n;
    }
    return YES;
}

- (BOOL)sendData:(int)fd data:(NSData *)data {
    return [self sendBytes:fd bytes:data.bytes length:data.length];
}

- (void)handleClient:(int)client {
    NSMutableData *requestData = [NSMutableData data];
    char buf[4096];
    while (requestData.length < 32768) {
        ssize_t n = recv(client, buf, sizeof(buf), 0);
        if (n <= 0) return;
        [requestData appendBytes:buf length:(NSUInteger)n];
        NSData *marker = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        if ([requestData rangeOfData:marker options:0 range:NSMakeRange(0, requestData.length)].location != NSNotFound) break;
    }

    NSString *request = [[NSString alloc] initWithData:requestData encoding:NSUTF8StringEncoding];
    if (!request) return;
    NSArray<NSString *> *lines = [request componentsSeparatedByString:@"\r\n"];
    NSArray<NSString *> *first = [lines.firstObject componentsSeparatedByString:@" "];
    if (first.count < 2) return;
    NSString *method = first[0];
    NSString *key = [first[1] stringByRemovingPercentEncoding];
    if ([key hasPrefix:@"/"]) key = [key substringFromIndex:1];

    NSURL *fileURL;
    @synchronized (self.files) { fileURL = self.files[key]; }
    NSDictionary *attrs = fileURL ? [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil] : nil;
    unsigned long long fileSize = attrs.fileSize;
    if (!fileURL || !attrs || fileSize == 0) {
        [self sendData:client data:[@"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }

    unsigned long long start = 0, end = fileSize - 1;
    BOOL partial = NO;
    for (NSString *line in lines) {
        if ([[line lowercaseString] hasPrefix:@"range: bytes="]) {
            NSString *range = [[line componentsSeparatedByString:@"="] lastObject];
            NSArray *bounds = [range componentsSeparatedByString:@"-"];
            if (bounds.firstObject.length) start = strtoull(bounds.firstObject.UTF8String, NULL, 10);
            if (bounds.count > 1 && [bounds[1] length]) end = strtoull([bounds[1] UTF8String], NULL, 10);
            if (end >= fileSize) end = fileSize - 1;
            if (start <= end && start < fileSize) partial = YES;
            break;
        }
    }

    if (start >= fileSize || end < start) {
        NSString *h = [NSString stringWithFormat:@"HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */%llu\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", fileSize];
        [self sendData:client data:[h dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }

    unsigned long long length = end - start + 1;
    NSMutableString *header = [NSMutableString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: audio/%@\r\nAccept-Ranges: bytes\r\nContent-Length: %llu\r\n",
                               partial ? @"206 Partial Content" : @"200 OK",
                               fileURL.pathExtension.lowercaseString ?: @"mpeg", length];
    if (partial) [header appendFormat:@"Content-Range: bytes %llu-%llu/%llu\r\n", start, end, fileSize];
    [header appendString:@"Connection: close\r\n\r\n"];
    if (![self sendData:client data:[header dataUsingEncoding:NSUTF8StringEncoding]]) return;
    if ([method isEqualToString:@"HEAD"]) return;

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:fileURL.path];
    [handle seekToFileOffset:start];
    unsigned long long remaining = length;
    while (remaining) {
        @autoreleasepool {
            NSUInteger chunkSize = (NSUInteger)MIN((unsigned long long)(64 * 1024), remaining);
            NSData *chunk = [handle readDataOfLength:chunkSize];
            if (!chunk.length || ![self sendData:client data:chunk]) break;
            remaining -= chunk.length;
        }
    }
    [handle closeFile];
}
@end
