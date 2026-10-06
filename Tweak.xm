#import <Foundation/Foundation.h>

// Milestone 1 deliberately keeps the Music process hook minimal.
// The actual importer is isolated in MDImportCoordinator so private
// Music-library integration can be tested and revised without spreading
// fragile implementation details throughout the tweak.

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] Loaded v0.0.1");
    }
}
