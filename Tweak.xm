#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MusicDrop/MDImportViewController.h"

static BOOL MDPresentedThisActivation = NO;

static UIWindow *MDActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:UIWindowScene.class]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
        if (windowScene.windows.firstObject) return windowScene.windows.firstObject;
    }

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) return window;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static UIViewController *MDTopViewController(UIViewController *controller) {
    if (!controller) return nil;
    if ([controller isKindOfClass:UINavigationController.class]) {
        return MDTopViewController(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return MDTopViewController(((UITabBarController *)controller).selectedViewController);
    }
    if (controller.presentedViewController) {
        return MDTopViewController(controller.presentedViewController);
    }
    return controller;
}

static void MDPresentTester(void) {
    if (MDPresentedThisActivation) return;

    UIWindow *window = MDActiveWindow();
    UIViewController *presenter = MDTopViewController(window.rootViewController);
    if (!presenter || !presenter.view.window) return;

    MDPresentedThisActivation = YES;
    MDImportViewController *controller = [MDImportViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [presenter presentViewController:nav animated:YES completion:nil];
}

static void MDApplicationBecameActive(NSNotification *note) {
    MDPresentedThisActivation = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        MDPresentTester();
    });
}

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] Loaded v0.0.4");

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *note) {
                            MDApplicationBecameActive(note);
                        }];

            // If injection happens after Music is already active, still present once.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                MDPresentTester();
            });
        });
    }
}
