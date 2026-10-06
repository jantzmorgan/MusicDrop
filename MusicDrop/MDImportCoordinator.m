#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <AVFoundation/AVFoundation.h>

static NSString * const MDErrorDomain = @"com.jantzmorgan.musicdrop";

@implementation MDImportCoordinator

+ (instancetype)sharedCoordinator {
    static MDImportCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [MDImportCoordinator new];
    });
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
        if (error) {
            *error = [NSError errorWithDomain:MDErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"MusicDrop does not support this audio file yet."}];
        }
        return nil;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    MDTrackMetadata *result = [MDTrackMetadata metadataWithFallbackTitle:url.URLByDeletingPathExtension.lastPathComponent];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (AVMetadataItem *item in asset.commonMetadata) {
        NSString *key = (NSString *)item.commonKey;
        if (![key isKindOfClass:NSString.class]) continue;

        if ([key isEqualToString:AVMetadataCommonKeyTitle] && item.stringValue.length) {
            result.title = item.stringValue;
        } else if ([key isEqualToString:AVMetadataCommonKeyArtist] && item.stringValue.length) {
            result.artist = item.stringValue;
        } else if ([key isEqualToString:AVMetadataCommonKeyAlbumName] && item.stringValue.length) {
            result.album = item.stringValue;
        }
    }
#pragma clang diagnostic pop

    return result;
}

- (void)importAudioAtURL:(NSURL *)url
                metadata:(MDTrackMetadata *)metadata
              completion:(MDImportCompletion)completion {
    if (![self isSupportedAudioURL:url]) {
        NSError *error = [NSError errorWithDomain:MDErrorDomain
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unsupported audio file."}];
        if (completion) completion(NO, error);
        return;
    }

    // Deliberately not faking the hardest part:
    // native Music-library insertion will be implemented after we verify
    // the correct MediaLibrary behavior on the target iOS build.
    NSError *error = [NSError errorWithDomain:MDErrorDomain
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Import backend is not connected yet. File validation and metadata parsing succeeded."}];
    if (completion) completion(NO, error);
}

@end
