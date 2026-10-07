#import "MDMediaConverter.h"
#import <AVFoundation/AVFoundation.h>

@implementation MDMediaConverter
+ (void)convertMediaAtURL:(NSURL *)url completion:(MDConversionCompletion)completion {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!session) {
        if (completion) completion(nil, [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.convert" code:3001 userInfo:@{NSLocalizedDescriptionKey:@"This media file cannot be converted to M4A."}]);
        return;
    }

    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MusicDropConverted"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *base = url.URLByDeletingPathExtension.lastPathComponent.length ? url.URLByDeletingPathExtension.lastPathComponent : @"Converted Audio";
    NSURL *output = [NSURL fileURLWithPath:[[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", base, NSUUID.UUID.UUIDString]] stringByAppendingPathExtension:@"m4a"]];
    [[NSFileManager defaultManager] removeItemAtURL:output error:nil];

    session.outputURL = output;
    session.outputFileType = AVFileTypeAppleM4A;
    [session exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (session.status == AVAssetExportSessionStatusCompleted) {
                if (completion) completion(output, nil);
            } else {
                NSError *error = session.error ?: [NSError errorWithDomain:@"com.jantzmorgan.musicdrop.convert" code:3002 userInfo:@{NSLocalizedDescriptionKey:@"Audio conversion failed."}];
                if (completion) completion(nil, error);
            }
        });
    }];
}
@end
