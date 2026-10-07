#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^MDConversionCompletion)(NSURL * _Nullable outputURL, NSError * _Nullable error);
@interface MDMediaConverter : NSObject
+ (void)convertMediaAtURL:(NSURL *)url completion:(MDConversionCompletion)completion;
@end
NS_ASSUME_NONNULL_END
