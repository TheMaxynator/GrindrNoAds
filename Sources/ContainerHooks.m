#import "Includes/GNCommon.h"
#import <substrate.h>
#import <string.h>
#import <stdlib.h> // free(class_copyIvarList result)

typedef void (*GNVoidIMP)(id, SEL);
static GNVoidIMP gOriginalRootViewDidLoad;
static BOOL gRootHookInstalled = NO;

static BOOL GNIsObjectIvar(Ivar ivar) {
    const char *type = ivar_getTypeEncoding(ivar);
    return type && type[0] == '@'; // Never object_setIvar into scalar/opaque Swift storage.
}

static void GNProcessContainerIvars(id controller) {
    // We intentionally do not blank all Swift lazy-storage and manager ivars.
    // That behavior was present in the original tweak but can corrupt version-dependent state.
    // Match known names exactly, not broad substring matches.
    Class current = object_getClass(controller);
    while (current && current != [UIViewController class]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(current, &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (!name || !GNIsObjectIvar(ivar)) continue;
            BOOL viewName = strcmp(name, "adBanner") == 0 || strcmp(name, "adContainerView") == 0;
            BOOL heightName = strcmp(name, "adContainerViewHeight") == 0;
            BOOL managerName = strcmp(name, "$__lazy_storage_$_bannerPresentationManager") == 0 ||
                               strcmp(name, "_persistentAdDisplayManager") == 0;
            if (!viewName && !heightName && !managerName) continue;

            // Safely manipulate only familiar UIKit object types.
            id value = object_getIvar(controller, ivar);
            if (viewName && [value isKindOfClass:[UIView class]]) {
                UIView *adView = (UIView *)value;
                adView.hidden = YES;
                [adView removeFromSuperview];
                GNLog(@"Removed container %s", name);
            } else if (heightName && [value isKindOfClass:[NSLayoutConstraint class]]) {
                NSLayoutConstraint *constraint = (NSLayoutConstraint *)value;
                constraint.constant = 0.0;
                GNLog(@"Collapsed height constraint %s", name);
            } else if (heightName && [value isKindOfClass:[NSNumber class]] &&
                       GNIsAggressiveManagerResetEnabled()) {
                object_setIvar(controller, ivar, @0);
            } else if (managerName && GNIsAggressiveManagerResetEnabled()) {
                // Higher risk: only if user explicitly opts in after verifying app version.
                object_setIvar(controller, ivar, nil);
                GNLog(@"Cleared manager %s (aggressive mode)", name);
            }
        }
        free(ivars);
        current = class_getSuperclass(current);
    }
}

static void GNHookRootViewDidLoad(id object, SEL cmd) {
    if (gOriginalRootViewDidLoad) gOriginalRootViewDidLoad(object, cmd);
    if (![object isKindOfClass:[UIViewController class]]) return;
    GNProcessContainerIvars(object);
}

void GNInstallContainerHooks(void) {
    if (gRootHookInstalled) return;
    Class cls = objc_getClass("grindrx.RootContainerViewController");
    SEL selector = @selector(viewDidLoad);
    if (!cls || !class_getInstanceMethod(cls, selector)) {
        GNLog(@"RootContainerViewController unavailable; omitting hook");
        return;
    }
    gRootHookInstalled = YES;
    MSHookMessageEx(cls, selector, (IMP)GNHookRootViewDidLoad, (IMP *)&gOriginalRootViewDidLoad);
    GNLog(@"Root container hook installed");
}
