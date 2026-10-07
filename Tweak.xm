#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MusicDrop/MDHubViewController.h"

static UITabBarController *MDTabController = nil;
static UIViewController *MDMusicDropController = nil;

static void MDInstallMusicDropTab(UITabBarController *tabController) {
    if (!tabController) return;

    for (UIViewController *controller in tabController.viewControllers) {
        if ([controller.tabBarItem.title isEqualToString:@"MusicDrop"]) {
            MDTabController = tabController;
            MDMusicDropController = controller;
            return;
        }
    }

    MDHubViewController *hub = [MDHubViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:hub];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"MusicDrop"
                                                   image:[UIImage systemImageNamed:@"arrow.down.circle"]
                                                     tag:9876];

    NSMutableArray *controllers = [tabController.viewControllers mutableCopy] ?: [NSMutableArray array];
    [controllers addObject:nav];
    tabController.viewControllers = controllers;

    MDTabController = tabController;
    MDMusicDropController = nav;
}

%hook UITabBarController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if ([bundleID isEqualToString:@"com.apple.Music"]) {
        MDInstallMusicDropTab(self);
    }
}

- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated {
    %orig;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if ([bundleID isEqualToString:@"com.apple.Music"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MDInstallMusicDropTab(self);
        });
    }
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] product build injected into %@ (%@)",
              NSProcessInfo.processInfo.processName,
              NSBundle.mainBundle.bundleIdentifier);

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                    if (![scene isKindOfClass:UIWindowScene.class]) continue;
                    for (UIWindow *window in scene.windows) {
                        UIViewController *root = window.rootViewController;
                        if ([root isKindOfClass:UITabBarController.class]) {
                            MDInstallMusicDropTab((UITabBarController *)root);
                        }
                    }
                }
            });
        }];
    }
}
