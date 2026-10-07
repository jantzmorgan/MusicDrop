#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MDTrackMetadata : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *albumArtist;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, copy) NSString *composer;
@property (nonatomic, nullable, copy) NSNumber *trackNumber;
@property (nonatomic, nullable, copy) NSNumber *discNumber;
@property (nonatomic, nullable, copy) NSNumber *year;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, nullable, strong) UIImage *artwork;
+ (instancetype)metadataWithFallbackTitle:(NSString *)title;
@end

NS_ASSUME_NONNULL_END
