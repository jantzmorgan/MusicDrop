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
    return nil;
}

static void MDPresentTester(void) {
    if (MDPresentedThisActivation) return;

    UIWindow *window = MDActiveWindow();
    UIViewController *root = window.rootViewController;
    if (!root || root.presentedViewController) return;

    MDPresentedThisActivation = YES;
    MDImportViewController *controller = [MDImportViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [root presentViewController:nav animated:YES completion:nil];
}

%hook MusicApplicationDelegate
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    MDPresentedThisActivation = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        MDPresentTester();
    });
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] Loaded v0.0.3");
    }
}
