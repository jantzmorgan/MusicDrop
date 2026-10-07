#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MusicDrop/MDHubViewController.h"

static const NSInteger MDTabTag = 9876;

static BOOL MDHasMusicDropTab(UITabBarController *tabController) {
    for (UIViewController *controller in tabController.viewControllers ?: @[]) {
        if (controller.tabBarItem.tag == MDTabTag ||
            [controller.tabBarItem.title isEqualToString:@"MusicDrop"]) {
            return YES;
        }
    }
    return NO;
}

static void MDInstallMusicDropTabIfNeeded(UITabBarController *tabController) {
    if (!tabController || MDHasMusicDropTab(tabController)) return;

    NSArray<UIViewController *> *existing = tabController.viewControllers;
    if (existing.count < 2) return; // Do not touch transient/internal tab controllers.

    MDHubViewController *hub = [MDHubViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:hub];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"MusicDrop"
                                                   image:[UIImage systemImageNamed:@"arrow.down.circle"]
                                                     tag:MDTabTag];

    NSMutableArray<UIViewController *> *controllers = [existing mutableCopy];
    [controllers addObject:nav];

    // Install only after Apple's own controller hierarchy is stable.
    [tabController setViewControllers:controllers animated:NO];
}

%hook UITabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Music"]) return;
    if (self.view.window == nil) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        MDInstallMusicDropTabIfNeeded(self);
    });
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] injected into %@ (%@)",
              NSProcessInfo.processInfo.processName,
              NSBundle.mainBundle.bundleIdentifier);
    }
}
