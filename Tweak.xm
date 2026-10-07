#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MusicDrop/MDImportViewController.h"

static BOOL MDPresented = NO;

static UIWindow *MDActiveWindow(void) {
    NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;

        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
        for (UIWindow *window in windowScene.windows) {
            if (!window.hidden && window.alpha > 0.0) return window;
        }
    }
    return nil;
}

static UIViewController *MDPresenter(UIViewController *controller) {
    if (!controller) return nil;
    if (controller.presentedViewController) return MDPresenter(controller.presentedViewController);
    if ([controller isKindOfClass:UINavigationController.class]) {
        return MDPresenter(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return MDPresenter(((UITabBarController *)controller).selectedViewController);
    }
    return controller;
}

static void MDTryPresent(void) {
    if (MDPresented) return;
    UIWindow *window = MDActiveWindow();
    UIViewController *presenter = MDPresenter(window.rootViewController);
    if (!presenter || !presenter.viewIfLoaded.window) return;

    MDPresented = YES;
    MDImportViewController *musicDrop = [MDImportViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:musicDrop];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [presenter presentViewController:nav animated:YES completion:nil];
}

static void MDSchedulePresentation(void) {
    MDPresented = NO;
    for (NSNumber *delay in @[@0.75, @1.5, @3.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            MDTryPresent();
        });
    }
}

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] injected into %@ (%@)",
              NSProcessInfo.processInfo.processName,
              NSBundle.mainBundle.bundleIdentifier);

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(__unused NSNotification *note) {
                            MDSchedulePresentation();
                        }];

            MDSchedulePresentation();
        });
    }
}
