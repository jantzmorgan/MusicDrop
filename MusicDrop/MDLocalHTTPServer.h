#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface MDLocalHTTPServer : NSObject
+ (instancetype)sharedServer;
- (nullable NSURL *)URLForFileURL:(NSURL *)fileURL error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
