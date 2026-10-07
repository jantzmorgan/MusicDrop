#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

static NSString * const MDErrorDomain = @"com.jantzmorgan.musicdrop";

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
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"mp3", @"m4a", @"aac"]];
    });
    return [extensions containsObject:url.pathExtension.lowercaseString];
}

- (MDTrackMetadata *)metadataForAudioURL:(NSURL *)url error:(NSError **)error {
    if (![self isSupportedAudioURL:url]) {
        if (error) *error = [NSError errorWithDomain:MDErrorDomain code:1001
                                            userInfo:@{NSLocalizedDescriptionKey:@"Choose an MP3, M4A, or AAC file."}];
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

- (void)importAudioAtURL:(NSURL *)url
                metadata:(MDTrackMetadata *)metadata
              completion:(MDImportCompletion)completion {
    if (![self isSupportedAudioURL:url]) {
        if (completion) completion(NO, [NSError errorWithDomain:MDErrorDomain code:1001
                                                       userInfo:@{NSLocalizedDescriptionKey:@"Unsupported audio file."}]);
        return;
    }

    // Gate C: do not report success until a native Music-library item is verifiably created.
    NSError *error = [NSError errorWithDomain:MDErrorDomain code:1002
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Native Music-library insertion is the next engineering gate. No fake import was performed."}];
    if (completion) completion(NO, error);
}
@end
