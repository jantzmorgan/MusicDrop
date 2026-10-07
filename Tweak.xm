#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MusicDrop/MDImportViewController.h"

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

static void MDPresentPendingImport(void) {
    NSString *candidate = UIPasteboard.generalPasteboard.string;
    if (!candidate.length) return;

    NSURL *url = [NSURL URLWithString:candidate];
    if (!url.isFileURL) return;

    UIWindow *window = MDActiveWindow();
    UIViewController *root = window.rootViewController;
    if (!root || root.presentedViewController) return;

    MDImportViewController *controller = [[MDImportViewController alloc] initWithAudioURL:url];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    [root presentViewController:nav animated:YES completion:nil];
}

%hook MusicApplicationDelegate
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        MDPresentPendingImport();
    });
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[MusicDrop] Loaded v0.0.2");
    }
}
