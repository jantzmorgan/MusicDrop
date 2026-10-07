#import "MDLocalHTTPServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

@interface MDLocalHTTPServer ()
@property (nonatomic) int serverFD;
@property (nonatomic) uint16_t port;
@property (nonatomic, strong) dispatch_queue_t queue;
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
        _queue = dispatch_queue_create("com.jantzmorgan.musicdrop.http", DISPATCH_QUEUE_SERIAL);
        _files = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)start:(NSError **)error {
    if (self.serverFD >= 0) return YES;

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) goto fail;

    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in addr = {0};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(0);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) { close(fd); goto fail; }
    if (listen(fd, 8) != 0) { close(fd); goto fail; }

    socklen_t len = sizeof(addr);
    if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) { close(fd); goto fail; }

    self.serverFD = fd;
    self.port = ntohs(addr.sin_port);

    dispatch_async(self.queue, ^{
        [self acceptLoop];
    });
    return YES;

fail:
    if (error) *error = [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.http" code:4001 userInfo:@{NSLocalizedDescriptionKey:@"MusicDrop could not start its local import bridge."}];
    return NO;
}

- (NSURL *)URLForFileURL:(NSURL *)fileURL error:(NSError **)error {
    if (![self start:error]) return nil;
    if (!fileURL.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        if (error) *error = [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.http" code:4002 userInfo:@{NSLocalizedDescriptionKey:@"The selected audio file is no longer available."}];
        return nil;
    }

    NSString *token = NSUUID.UUID.UUIDString.lowercaseString;
    NSString *ext = fileURL.pathExtension.lowercaseString.length ? fileURL.pathExtension.lowercaseString : @"bin";
    NSString *key = [NSString stringWithFormat:@"%@.%@", token, ext];
    @synchronized (self.files) { self.files[key] = fileURL; }
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu/%@", self.port, key]];
}

- (void)acceptLoop {
    while (self.serverFD >= 0) {
        int client = accept(self.serverFD, NULL, NULL);
        if (client < 0) continue;
        [self handleClient:client];
        close(client);
    }
}

- (void)writeAll:(int)fd data:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t sent = write(fd, bytes, remaining);
        if (sent <= 0) break;
        bytes += sent;
        remaining -= (NSUInteger)sent;
    }
}

- (void)handleClient:(int)client {
    char buffer[4096] = {0};
    ssize_t count = read(client, buffer, sizeof(buffer) - 1);
    if (count <= 0) return;

    NSString *request = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)count encoding:NSUTF8StringEncoding];
    NSString *firstLine = [request componentsSeparatedByString:@"\r\n"].firstObject ?: @"";
    NSArray *parts = [firstLine componentsSeparatedByString:@" "];
    NSString *path = parts.count > 1 ? parts[1] : @"";
    NSString *key = [path stringByRemovingPercentEncoding];
    if ([key hasPrefix:@"/"]) key = [key substringFromIndex:1];

    NSURL *fileURL = nil;
    @synchronized (self.files) { fileURL = self.files[key]; }
    NSDictionary *attrs = fileURL ? [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil] : nil;
    unsigned long long size = [attrs fileSize];

    if (!fileURL || !attrs) {
        NSData *response = [@"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        [self writeAll:client data:response];
        return;
    }

    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: %llu\r\nAccept-Ranges: bytes\r\nConnection: close\r\n\r\n", size];
    [self writeAll:client data:[header dataUsingEncoding:NSUTF8StringEncoding]];

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:fileURL.path];
    while (true) {
        @autoreleasepool {
            NSData *chunk = [handle readDataOfLength:64 * 1024];
            if (!chunk.length) break;
            [self writeAll:client data:chunk];
        }
    }
    [handle closeFile];
}
@end
