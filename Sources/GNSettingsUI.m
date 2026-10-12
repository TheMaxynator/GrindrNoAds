#import "Includes/GNCommon.h"
#import <objc/runtime.h>

// The user explicitly invokes these settings. No always-visible overlay,
// cross-process preferences, PreferenceLoader or sandbox exceptions are required.
static const void *kGNGestureKey = &kGNGestureKey;

@interface GNSettingsGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@end
@implementation GNSettingsGestureDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
@end

static GNSettingsGestureDelegate *gGestureDelegate;
static id gGestureHandler;

static UIViewController *GNTopController(UIWindow *window) {
    UIViewController *presenter = window.rootViewController;
    if (!presenter) return nil;
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
        presenter = presenter.presentedViewController;
    }
    return presenter;
}

static void GNShowSettings(UIWindow *window);

static void GNToggle(NSString *key, BOOL enabled, UIWindow *window) {
    NSString *prefKey = [@"GNA." stringByAppendingString:key];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:prefKey];
    GNLoadConfiguration();
    GNInstallConfiguredHooks();
    // A previously hidden/detached view cannot be restored without reloading that screen.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ GNShowSettings(window); });
}

static void GNAddSetting(UIAlertController *panel, NSString *label, NSString *key,
                         BOOL enabled, UIWindow *window) {
    NSString *title = [NSString stringWithFormat:@"%@ %@", enabled ? @"☑" : @"☐", label];
    [panel addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
            if ([key isEqualToString:@"AggressiveManagerResetEnabled"] && !enabled) {
                UIViewController *presenter = GNTopController(window);
                UIAlertController *warning = [UIAlertController alertControllerWithTitle:@"Experimentele optie"
                    message:@"Deze optie kan na app-updates instabiliteit veroorzaken. Alleen inschakelen voor diagnostiek."
                    preferredStyle:UIAlertControllerStyleAlert];
                [warning addAction:[UIAlertAction actionWithTitle:@"Annuleren" style:UIAlertActionStyleCancel handler:nil]];
                [warning addAction:[UIAlertAction actionWithTitle:@"Inschakelen" style:UIAlertActionStyleDestructive
                      handler:^(UIAlertAction *confirm) { GNToggle(key, YES, window); }]];
                [presenter presentViewController:warning animated:YES completion:nil];
            } else {
                GNToggle(key, !enabled, window);
            }
        }]];
}

static void GNShowSettings(UIWindow *window) {
    if (!window || !window.rootViewController) return;
    UIViewController *presenter = GNTopController(window);
    if (!presenter || [presenter isKindOfClass:[UIAlertController class]] ||
        presenter.isBeingPresented || presenter.isBeingDismissed) return;
    UIAlertController *panel = [UIAlertController alertControllerWithTitle:@"GrindrNoAds"
      message:@"Tik op een optie om deze om te schakelen. Sluit Grindr volledig af en start opnieuw om alle wijzigingen te zien."
      preferredStyle:UIAlertControllerStyleAlert];
    GNAddSetting(panel, @"Netwerkblokkering", @"NetworkBlockingEnabled", GNIsNetworkFilteringEnabled(), window);
    GNAddSetting(panel, @"Advertentieviews", @"ViewRemovalEnabled", GNIsViewRemovalEnabled(), window);
    GNAddSetting(panel, @"Lege advertentieruimte", @"ContainerCleanupEnabled", GNIsContainerCleanupEnabled(), window);
    GNAddSetting(panel, @"Debuglogging", @"DebugLoggingEnabled", GNDebugEnabled(), window);
    GNAddSetting(panel, @"Manager-reset (risicovol)", @"AggressiveManagerResetEnabled",
                 GNIsAggressiveManagerResetEnabled(), window);
    [panel addAction:[UIAlertAction actionWithTitle:@"Sluiten" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:panel animated:YES completion:nil];
}

@interface GNSettingsGestureHandler : NSObject
- (void)openSettings:(UILongPressGestureRecognizer *)gesture;
@end
@implementation GNSettingsGestureHandler
- (void)openSettings:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIWindow *window = (UIWindow *)gesture.view;
    GNShowSettings(window);
}
@end

static void GNAttachGesture(UIWindow *window) {
    if (!window || objc_getAssociatedObject(window, kGNGestureKey)) return;
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
        initWithTarget:gGestureHandler action:@selector(openSettings:)];
    gesture.minimumPressDuration = 1.2;
    gesture.numberOfTouchesRequired = 2;
    gesture.cancelsTouchesInView = NO;
    gesture.delegate = gGestureDelegate;
    [window addGestureRecognizer:gesture];
    objc_setAssociatedObject(window, kGNGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void GNInstallSettingsGesture(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t token;
        dispatch_once(&token, ^{
            gGestureDelegate = [GNSettingsGestureDelegate new];
            gGestureHandler = [GNSettingsGestureHandler new];
        });
        UIApplication *app = [UIApplication sharedApplication];
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.windowLevel != UIWindowLevelNormal) continue;
                GNAttachGesture(window);
            }
        }
    });
}
