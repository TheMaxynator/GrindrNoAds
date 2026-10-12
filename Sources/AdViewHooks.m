#import "Includes/GNCommon.h"
#import <substrate.h>

typedef void (*GNVoidIMP)(id, SEL);
static GNVoidIMP gOrigDidMoveToWindow;
static GNVoidIMP gOrigLayoutSubviews;
static BOOL gDidMoveHookInstalled = NO;
static BOOL gLayoutHookInstalled = NO;

static void GNHookDidMoveToWindow(id object, SEL cmd) {
    if (gOrigDidMoveToWindow) gOrigDidMoveToWindow(object, cmd);
    if (!GNIsViewRemovalEnabled() || ![object isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)object;
    if (!view.superview) return;
    // Original hook removed the AdView. Hide first to avoid visible flashes.
    view.hidden = YES;
    [view removeFromSuperview];
}

static void GNHookLayoutSubviews(id object, SEL cmd) {
    if (gOrigLayoutSubviews) gOrigLayoutSubviews(object, cmd);
    if (!GNIsViewRemovalEnabled() || ![object isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)object;
    if (!view.hidden) view.hidden = YES;
    if (view.alpha != 0.0) view.alpha = 0.0;
}

static void GNInstallAdViewHook(const char *name, SEL selector, IMP hook, IMP *original, BOOL *installed) {
    if (*installed) return;
    Class cls = objc_getClass(name); // Swift class names include module prefix.
    if (!cls || !class_getInstanceMethod(cls, selector)) { GNLog(@"Class or selector missing: %s", name); return; }
    *installed = YES;
    MSHookMessageEx(cls, selector, hook, original);
    GNLog(@"Ad view hook installed: %s", name);
}

void GNInstallAdViewHooks(void) {
    GNInstallAdViewHook("GrindrAdsImpl.AdView", @selector(didMoveToWindow),
                        (IMP)GNHookDidMoveToWindow, (IMP *)&gOrigDidMoveToWindow, &gDidMoveHookInstalled);
    GNInstallAdViewHook("GrindrAds.AdView", @selector(layoutSubviews),
                        (IMP)GNHookLayoutSubviews, (IMP *)&gOrigLayoutSubviews, &gLayoutHookInstalled);
}
