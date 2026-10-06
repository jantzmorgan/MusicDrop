#import <Foundation/Foundation.h>

@class MDTrackMetadata;

NS_ASSUME_NONNULL_BEGIN

typedef void (^MDImportCompletion)(BOOL success, NSError * _Nullable error);

@interface MDImportCoordinator : NSObject

+ (instancetype)sharedCoordinator;

- (BOOL)isSupportedAudioURL:(NSURL *)url;
- (MDTrackMetadata *)metadataForAudioURL:(NSURL *)url error:(NSError **)error;
- (void)importAudioAtURL:(NSURL *)url
                metadata:(MDTrackMetadata *)metadata
              completion:(MDImportCompletion)completion;

@end

NS_ASSUME_NONNULL_END
