#import "Includes/GNCommon.h"
#import <objc/runtime.h>
#import <math.h>

// Only act on an immediate wrapper whose *sole* child is an already-known ad view.
// Do not alter global insets, the profile grid, navigation bars, or tab bars.
static const void *kGNAdHostCollapsedKey = &kGNAdHostCollapsedKey;

static BOOL GNIsUnsafeContainer(UIView *view) {
    return [view isKindOfClass:[UIWindow class]] ||
           [view isKindOfClass:[UIScrollView class]] ||
           [view isKindOfClass:[UITableViewCell class]] ||
           [view isKindOfClass:[UICollectionViewCell class]] ||
           [view isKindOfClass:[UITabBar class]] ||
           [view isKindOfClass:[UINavigationBar class]] ||
           [view isKindOfClass:[UIStackView class]];
}

static BOOL GNEligibleAdOnlyHost(UIView *host, UIView *adView) {
    if (!host || !adView || GNIsUnsafeContainer(host)) return NO;
    if (host.subviews.count != 1 || host.subviews.firstObject != adView) return NO;
    UIWindow *window = host.window;
    if (!window || host == window.rootViewController.view || host.superview == window) return NO;
    if (!host.superview ||
        (GNIsUnsafeContainer(host.superview) &&
         ![host.superview isKindOfClass:[UIStackView class]])) return NO;

    CGRect frame = [host convertRect:host.bounds toView:window];
    CGFloat screenHeight = CGRectGetHeight(window.bounds);
    CGFloat screenWidth = CGRectGetWidth(window.bounds);
    CGFloat height = CGRectGetHeight(frame);
    CGFloat width = CGRectGetWidth(frame);
    // Deliberately conservative. If the reserve is outside this range,
    // use the on-device hierarchy diagnostic instead of guessing.
    if (!isfinite(height) || !isfinite(width) || !isfinite(screenHeight) ||
        height < 8.0 || height > 180.0 || width < MIN(200.0, screenWidth * 0.6)) return NO;
    if (CGRectGetMaxY(frame) < screenHeight - 190.0) return NO;
    return YES;
}

static BOOL GNZeroOwnFixedHeight(UIView *host) {
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:host.constraints];
    if (host.superview) [constraints addObjectsFromArray:host.superview.constraints];
    BOOL found = NO;
    for (NSLayoutConstraint *constraint in constraints) {
        if (!constraint.active || constraint.relation != NSLayoutRelationEqual) continue;
        if (constraint.firstItem == host &&
            constraint.firstAttribute == NSLayoutAttributeHeight &&
            constraint.secondItem == nil) {
            if (fabs(constraint.constant) > 0.1) constraint.constant = 0.0;
            found = YES;
        }
    }
    return found;
}

void GNHandleKnownAdViewHost(UIView *adView) {
    if (!GNIsContainerCleanupEnabled() || !GNIsViewRemovalEnabled() || !adView) return;
    UIView *host = adView.superview;
    if (!GNEligibleAdOnlyHost(host, adView)) return;
    if (objc_getAssociatedObject(host, kGNAdHostCollapsedKey)) return;

    // Mark first: changing constraints can trigger another layout pass.
    objc_setAssociatedObject(host, kGNAdHostCollapsedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    host.hidden = YES;
    host.alpha = 0.0;

    BOOL hasFixedHeight = GNZeroOwnFixedHeight(host);
    if (!hasFixedHeight && !host.translatesAutoresizingMaskIntoConstraints) {
        NSLayoutConstraint *zero = [host.heightAnchor constraintEqualToConstant:0.0];
        zero.priority = 999;
        zero.identifier = @"GrindrNoAds.dedicatedAdHost.heightZero";
        zero.active = YES;
    }
    // A UIStackView automatically collapses hidden arranged subviews.
    [host.superview setNeedsLayout];
    GNLog(@"Collapsed dedicated ad-only host %@ (original height %.0f)",
          NSStringFromClass(host.class), CGRectGetHeight(host.bounds));
}
