#import "Includes/GNCommon.h"
#import <substrate.h>

// Both Swift ad-view variants may be present depending on Grindr version.
// Each class/selector pair has its own original IMP.
typedef void (*GNVoidIMP)(id, SEL);
static GNVoidIMP gOrigImplDidMove;
static GNVoidIMP gOrigImplLayout;
static GNVoidIMP gOrigAdsDidMove;
static GNVoidIMP gOrigAdsLayout;
static BOOL gImplDidMoveInstalled = NO;
static BOOL gImplLayoutInstalled = NO;
static BOOL gAdsDidMoveInstalled = NO;
static BOOL gAdsLayoutInstalled = NO;

static void GNAdDidMove(id object, SEL cmd, GNVoidIMP original) {
    if (original) original(object, cmd);
    if (!GNIsViewRemovalEnabled() || ![object isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)object;
    if (!view.superview) return;
    // Inspect the dedicated wrapper before detaching its sole child.
    GNHandleKnownAdViewHost(view);
    view.hidden = YES;
    [view removeFromSuperview];
}

static void GNAdLayout(id object, SEL cmd, GNVoidIMP original) {
    if (original) original(object, cmd);
    if (!GNIsViewRemovalEnabled() || ![object isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)object;
    GNHandleKnownAdViewHost(view);
    if (!view.hidden) view.hidden = YES;
    if (view.alpha != 0.0) view.alpha = 0.0;
}

static void GNImplDidMove(id obj, SEL cmd) { GNAdDidMove(obj, cmd, gOrigImplDidMove); }
static void GNImplLayout(id obj, SEL cmd) { GNAdLayout(obj, cmd, gOrigImplLayout); }
static void GNAdsDidMove(id obj, SEL cmd) { GNAdDidMove(obj, cmd, gOrigAdsDidMove); }
static void GNAdsLayout(id obj, SEL cmd) { GNAdLayout(obj, cmd, gOrigAdsLayout); }

static void GNInstallAdViewHook(const char *name, SEL selector, IMP hook,
                                IMP *original, BOOL *installed) {
    if (*installed) return;
    Class cls = objc_getClass(name);
    if (!cls || !class_getInstanceMethod(cls, selector)) {
        GNLog(@"Class or selector missing: %s (%@)", name, NSStringFromSelector(selector));
        return;
    }
    MSHookMessageEx(cls, selector, hook, original);
    *installed = YES;
    GNLog(@"Ad hook installed: %s %@", name, NSStringFromSelector(selector));
}

void GNInstallAdViewHooks(void) {
    GNInstallAdViewHook("GrindrAdsImpl.AdView", @selector(didMoveToWindow),
        (IMP)GNImplDidMove, (IMP *)&gOrigImplDidMove, &gImplDidMoveInstalled);
    GNInstallAdViewHook("GrindrAdsImpl.AdView", @selector(layoutSubviews),
        (IMP)GNImplLayout, (IMP *)&gOrigImplLayout, &gImplLayoutInstalled);
    GNInstallAdViewHook("GrindrAds.AdView", @selector(didMoveToWindow),
        (IMP)GNAdsDidMove, (IMP *)&gOrigAdsDidMove, &gAdsDidMoveInstalled);
    GNInstallAdViewHook("GrindrAds.AdView", @selector(layoutSubviews),
        (IMP)GNAdsLayout, (IMP *)&gOrigAdsLayout, &gAdsLayoutInstalled);
}
