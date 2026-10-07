#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MDLocalHTTPServer.h"

static NSString * const MDErrorDomain = @"com.jantzmorgan.musicdrop";

@interface SSDownloadMetadata : NSObject
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end
@interface SSDownload : NSObject
- (instancetype)initWithDownloadMetadata:(SSDownloadMetadata *)metadata;
@end
@interface SSDownloadQueue : NSObject
+ (NSArray *)mediaDownloadKinds;
- (instancetype)initWithDownloadKinds:(NSArray *)downloadKinds;
- (BOOL)addDownload:(SSDownload *)download;
@end

@implementation MDImportCoordinator

+ (instancetype)sharedCoordinator {
    static MDImportCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ coordinator = [MDImportCoordinator new]; });
    return coordinator;
}

- (BOOL)isSupportedAudioURL:(NSURL *)url {
    if (!url.isFileURL) return NO;
    static NSSet<NSString *> *extensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ extensions = [NSSet setWithArray:@[@"mp3", @"m4a", @"aac"]]; });
    return [extensions containsObject:url.pathExtension.lowercaseString];
}

- (MDTrackMetadata *)metadataForAudioURL:(NSURL *)url error:(NSError **)error {
    if (![self isSupportedAudioURL:url]) {
        if (error) *error = [NSError errorWithDomain:MDErrorDomain code:1001 userInfo:@{NSLocalizedDescriptionKey:@"Choose an MP3, M4A, or AAC file."}];
        return nil;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    MDTrackMetadata *result = [MDTrackMetadata metadataWithFallbackTitle:url.URLByDeletingPathExtension.lastPathComponent];
    result.duration = CMTimeGetSeconds(asset.duration);
    if (!isfinite(result.duration) || result.duration < 0) result.duration = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (AVMetadataItem *item in asset.commonMetadata) {
        NSString *key = (NSString *)item.commonKey;
        if (![key isKindOfClass:NSString.class]) continue;
        NSString *value = item.stringValue;
        if ([key isEqualToString:AVMetadataCommonKeyTitle] && value.length) result.title = value;
        else if ([key isEqualToString:AVMetadataCommonKeyArtist] && value.length) result.artist = value;
        else if ([key isEqualToString:AVMetadataCommonKeyAlbumName] && value.length) result.album = value;
        else if ([key isEqualToString:AVMetadataCommonKeyCreator] && value.length) result.composer = value;
        else if ([key isEqualToString:AVMetadataCommonKeyType] && value.length) result.genre = value;
        else if ([key isEqualToString:AVMetadataCommonKeyArtwork]) {
            NSData *data = nil;
            if ([item.value isKindOfClass:NSData.class]) data = (NSData *)item.value;
            else if ([item.value isKindOfClass:NSDictionary.class]) data = ((NSDictionary *)item.value)[@"data"];
            if (data.length) result.artwork = [UIImage imageWithData:data];
        }
    }
#pragma clang diagnostic pop
    return result;
}

- (NSURL *)stagedURLForURL:(NSURL *)source error:(NSError **)error {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MusicDrop"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *name = [NSString stringWithFormat:@"%@-%@", NSUUID.UUID.UUIDString, source.lastPathComponent];
    NSURL *dest = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:name]];
    [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL:source toURL:dest error:error]) return nil;
    return dest;
}

- (void)importAudioAtURL:(NSURL *)url metadata:(MDTrackMetadata *)metadata completion:(MDImportCompletion)completion {
    if (![self isSupportedAudioURL:url]) {
        if (completion) completion(NO, [NSError errorWithDomain:MDErrorDomain code:1001 userInfo:@{NSLocalizedDescriptionKey:@"Unsupported audio file."}]);
        return;
    }

    NSError *stageError = nil;
    NSURL *audioURL = [self stagedURLForURL:url error:&stageError];
    if (!audioURL) {
        if (completion) completion(NO, stageError);
        return;
    }

    Class MetadataClass = NSClassFromString(@"SSDownloadMetadata");
    Class DownloadClass = NSClassFromString(@"SSDownload");
    Class QueueClass = NSClassFromString(@"SSDownloadQueue");
    if (!MetadataClass || !DownloadClass || !QueueClass) {
        if (completion) completion(NO, [NSError errorWithDomain:MDErrorDomain code:2001 userInfo:@{NSLocalizedDescriptionKey:@"This iOS build does not expose the StoreServices import classes MusicDrop needs."}]);
        return;
    }

    NSError *bridgeError = nil;
    NSURL *servedURL = [[MDLocalHTTPServer sharedServer] URLForFileURL:audioURL error:&bridgeError];
    if (!servedURL) {
        if (completion) completion(NO, bridgeError);
        return;
    }

    NSInteger itemID = (NSInteger)arc4random_uniform(90000000) + 10000000;
    NSInteger year = metadata.year.integerValue ?: [[NSCalendar currentCalendar] component:NSCalendarUnitYear fromDate:NSDate.date];
    NSInteger track = metadata.trackNumber.integerValue ?: 1;
    NSInteger durationMS = (NSInteger)llround(MAX(0, metadata.duration) * 1000.0);
    NSString *artist = metadata.artist.length ? metadata.artist : @"Unknown Artist";
    NSString *album = metadata.album.length ? metadata.album : @"Unknown Album";
    NSString *title = metadata.title.length ? metadata.title : audioURL.URLByDeletingPathExtension.lastPathComponent;
    NSString *ext = audioURL.pathExtension.lowercaseString;

    NSDictionary *payload = @{
        @"purchaseDate": NSDate.date,
        @"is-purchased-redownload": @YES,
        @"URL": servedURL.absoluteString,
        @"songId": @(itemID),
        @"metadata": @{
            @"artistName": artist,
            @"albumArtistName": metadata.albumArtist ?: @"",
            @"composerName": metadata.composer ?: @"",
            @"compilation": @NO,
            @"drmVersionNumber": @0,
            @"duration": @(durationMS),
            @"explicit": @0,
            @"fileExtension": ext ?: @"",
            @"gapless": @NO,
            @"genre": metadata.genre ?: @"",
            @"isMasteredForItunes": @NO,
            @"itemId": @(itemID),
            @"itemName": title,
            @"kind": @"song",
            @"playlistArtistName": artist,
            @"playlistName": album,
            @"releaseDate": NSDate.date,
            @"sort-album": album,
            @"sort-artist": artist,
            @"sort-composer": metadata.composer ?: @"",
            @"sort-name": title,
            @"trackCount": @1,
            @"trackNumber": @(track),
            @"year": @(year)
        }
    };

    @try {
        SSDownloadMetadata *downloadMetadata = [[MetadataClass alloc] initWithDictionary:payload];
        SSDownload *download = [[DownloadClass alloc] initWithDownloadMetadata:downloadMetadata];
        NSArray *kinds = [QueueClass mediaDownloadKinds];
        SSDownloadQueue *queue = [[QueueClass alloc] initWithDownloadKinds:kinds];
        BOOL accepted = [queue addDownload:download];

        if (!accepted) {
            if (completion) completion(NO, [NSError errorWithDomain:MDErrorDomain code:2002 userInfo:@{NSLocalizedDescriptionKey:@"Apple's Music import queue rejected the file."}]);
            return;
        }

        if (completion) completion(YES, nil);
    } @catch (NSException *exception) {
        if (completion) completion(NO, [NSError errorWithDomain:MDErrorDomain code:2003 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Native import exception: %@", exception.reason ?: exception.name]}]);
    }
}
@end
