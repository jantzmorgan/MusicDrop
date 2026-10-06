#import "MDTrackMetadata.h"

@implementation MDTrackMetadata

+ (instancetype)metadataWithFallbackTitle:(NSString *)title {
    MDTrackMetadata *metadata = [MDTrackMetadata new];
    metadata.title = title.length ? title : @"Unknown Title";
    metadata.artist = @"Unknown Artist";
    metadata.album = @"Unknown Album";
    metadata.albumArtist = @"";
    metadata.genre = @"";
    return metadata;
}

@end
