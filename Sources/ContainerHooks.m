#import "Includes/GNCommon.h"
#import <substrate.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
#import <math.h>

// Intentionally scoped to *known* ad-container ivars on the root controller.
// Do not change scroll-view insets or safe-area insets globally: those may contain tabs.
typedef void (*GNVoidIMP)(id, SEL);
typedef void (*GNAppearIMP)(id, SEL, BOOL);
static GNVoidIMP gOriginalRootViewDidLoad;
static GNVoidIMP gOriginalRootViewDidLayoutSubviews;
static GNAppearIMP gOriginalRootViewDidAppear;
static BOOL gLoadInstalled = NO;
static BOOL gLayoutInstalled = NO;
static BOOL gAppearInstalled = NO;
static const void *kGNCollapseConstraintKey = &kGNCollapseConstraintKey;

static BOOL GNIsObjectIvar(Ivar ivar) {
    const char *type = ivar_getTypeEncoding(ivar);
    return type && type[0] == '@';
}

static void GNSetHeightConstraintToZero(NSLayoutConstraint *constraint) {
    if (!constraint) return;
    if (fabs(constraint.constant) > 0.1) {
        constraint.constant = 0.0;
        GNLog(@"Collapsed known ad-height constraint");
    }
}

static void GNCollapseKnownAdContainer(UIView *container) {
    if (!container) return;
    if (!container.hidden) container.hidden = YES;
    if (container.alpha != 0.0) container.alpha = 0.0;

    // A hidden view still participates in ordinary Auto Layout. Collapse only
    // height constraints directly attached to the *known* ad container.
    NSMutableArray<NSLayoutConstraint *> *candidates = [NSMutableArray array];
    [candidates addObjectsFromArray:container.constraints];
    if (container.superview) [candidates addObjectsFromArray:container.superview.constraints];
    for (NSLayoutConstraint *constraint in candidates) {
        if (!constraint.active) continue;
        if (constraint.firstItem == container &&
            constraint.firstAttribute == NSLayoutAttributeHeight &&
            constraint.secondItem == nil) {
            GNSetHeightConstraintToZero(constraint);
        }
    }

    // If there is no explicit height constraint, provide one at priority 999.
    // Never introduce a second required (1000) constraint in an unknown layout.
    if (container.translatesAutoresizingMaskIntoConstraints == NO &&
        objc_getAssociatedObject(container, kGNCollapseConstraintKey) == nil) {
        NSLayoutConstraint *zeroHeight = [container.heightAnchor constraintEqualToConstant:0.0];
        zeroHeight.priority = UILayoutPriorityRequired - 1;
        zeroHeight.identifier = @"GrindrNoAds.knownAdContainer.heightZero";
        zeroHeight.active = YES;
        objc_setAssociatedObject(container, kGNCollapseConstraintKey,
                                 zeroHeight, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        GNLog(@"Installed a soft zero-height constraint for %@", NSStringFromClass([container class]));
    }
}

static void GNProcessContainerIvars(id controller) {
    if (!GNIsContainerCleanupEnabled()) return;
    Class current = object_getClass(controller);
    while (current && current != [UIViewController class]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(current, &count);
        for (unsigned int i = 0; i < count; ++i) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (!name || !GNIsObjectIvar(ivar)) continue;
            BOOL bannerName = strcmp(name, "adBanner") == 0;
            BOOL containerName = strcmp(name, "adContainerView") == 0;
            BOOL heightName = strcmp(name, "adContainerViewHeight") == 0;
            BOOL managerName = strcmp(name, "$__lazy_storage_$_bannerPresentationManager") == 0 ||
                               strcmp(name, "_persistentAdDisplayManager") == 0;
            if (!bannerName && !containerName && !heightName && !managerName) continue;
            id value = object_getIvar(controller, ivar);
            if (containerName && [value isKindOfClass:[UIView class]]) {
                GNCollapseKnownAdContainer((UIView *)value);
            } else if (bannerName && [value isKindOfClass:[UIView class]]) {
                UIView *banner = (UIView *)value;
                if (!banner.hidden) banner.hidden = YES;
                if (banner.superview) [banner removeFromSuperview];
            } else if (heightName && [value isKindOfClass:[NSLayoutConstraint class]]) {
                GNSetHeightConstraintToZero((NSLayoutConstraint *)value);
            } else if (heightName && [value isKindOfClass:[NSNumber class]]) {
                // This is the *named ad height* only, and only when Objective-C object typed.
                NSNumber *number = (NSNumber *)value;
                if (fabs(number.doubleValue) > 0.1) {
                    object_setIvar(controller, ivar, @0);
                    GNLog(@"Set NSNumber-based adContainerViewHeight to 0");
                }
            } else if (managerName && GNIsAggressiveManagerResetEnabled() && value) {
                object_setIvar(controller, ivar, nil);
                GNLog(@"Reset manager %s (opt-in)", name);
            }
        }
        free(ivars);
        current = class_getSuperclass(current);
    }
}

static void GNHookRootViewDidLoad(id object, SEL cmd) {
    if (gOriginalRootViewDidLoad) gOriginalRootViewDidLoad(object, cmd);
    if ([object isKindOfClass:[UIViewController class]]) GNProcessContainerIvars(object);
}

static void GNHookRootViewDidLayoutSubviews(id object, SEL cmd) {
    if (gOriginalRootViewDidLayoutSubviews) gOriginalRootViewDidLayoutSubviews(object, cmd);
    // Some ad containers are not populated until AFTER viewDidLoad.
    if ([object isKindOfClass:[UIViewController class]]) GNProcessContainerIvars(object);
}

static void GNHookRootViewDidAppear(id object, SEL cmd, BOOL animated) {
    if (gOriginalRootViewDidAppear) gOriginalRootViewDidAppear(object, cmd, animated);
    if ([object isKindOfClass:[UIViewController class]]) GNProcessContainerIvars(object);
}

static void GNInstallOne(Class cls, SEL selector, IMP replacement, IMP *original, BOOL *installed) {
    if (*installed || !class_getInstanceMethod(cls, selector)) return;
    MSHookMessageEx(cls, selector, replacement, original);
    *installed = YES;
    GNLog(@"Root container lifecycle hook installed: %@", NSStringFromSelector(selector));
}

void GNInstallContainerHooks(void) {
    Class cls = objc_getClass("grindrx.RootContainerViewController");
    if (!cls) { GNLog(@"RootContainerViewController unavailable; retry later"); return; }
    GNInstallOne(cls, @selector(viewDidLoad), (IMP)GNHookRootViewDidLoad,
                 (IMP *)&gOriginalRootViewDidLoad, &gLoadInstalled);
    GNInstallOne(cls, @selector(viewDidLayoutSubviews), (IMP)GNHookRootViewDidLayoutSubviews,
                 (IMP *)&gOriginalRootViewDidLayoutSubviews, &gLayoutInstalled);
    GNInstallOne(cls, @selector(viewDidAppear:), (IMP)GNHookRootViewDidAppear,
                 (IMP *)&gOriginalRootViewDidAppear, &gAppearInstalled);
}
