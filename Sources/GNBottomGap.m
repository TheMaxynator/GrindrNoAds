#import "Includes/GNCommon.h"
#import <objc/runtime.h>
#import <math.h>

// This is intentionally an opt-in experiment for one layout pattern observed
// on a 390 x 844 device: a hidden, empty 74pt-wide-screen slot placed directly
// below the 49pt UITabBar and above the 34pt bottom safe area. No tabbar frames,
// root view bounds, scroll insets or safe-area constraints are changed.
static const void *kGNBottomSlotDoneKey = &kGNBottomSlotDoneKey;

static CGRect GNWindowFrame(UIView *view, UIWindow *window) {
    return [view convertRect:view.bounds toView:window];
}

static BOOL GNSlotGeometryMatches(UIView *view, UIWindow *window, CGFloat tabBarBottom) {
    if ([view class] != [UIView class] || view.subviews.count != 0 ||
        !(view.hidden || view.alpha < 0.01) || !view.superview ||
        view == window.rootViewController.view || view == window) return NO;
    CGRect frame = GNWindowFrame(view, window);
    CGFloat bottomSafe = window.safeAreaInsets.bottom;
    CGFloat expectedBottom = CGRectGetHeight(window.bounds) - bottomSafe;
    return isfinite(frame.origin.y) && isfinite(frame.size.height) &&
        fabs(CGRectGetMinX(frame)) <= 3.0 &&
        frame.size.width >= CGRectGetWidth(window.bounds) - 6.0 &&
        frame.size.height >= 72.0 && frame.size.height <= 76.0 &&
        fabs(CGRectGetMinY(frame) - tabBarBottom) <= 3.0 &&
        fabs(CGRectGetMaxY(frame) - expectedBottom) <= 4.0;
}

static NSLayoutConstraint *GNFindFixedHeightConstraint(UIView *view) {
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:view.constraints];
    if (view.superview) [constraints addObjectsFromArray:view.superview.constraints];
    for (NSLayoutConstraint *constraint in constraints) {
        if (constraint.active && constraint.relation == NSLayoutRelationEqual &&
            constraint.firstItem == view &&
            constraint.firstAttribute == NSLayoutAttributeHeight &&
            constraint.secondItem == nil &&
            constraint.constant >= 72.0 && constraint.constant <= 76.0) {
            return constraint;
        }
    }
    return nil;
}

void GNApplyBottomGapFix(UIViewController *controller) {
    if (!GNIsContainerCleanupEnabled() || !GNIsExperimentalBottomGapFixEnabled()) return;
    if (![NSThread isMainThread] || ![controller isKindOfClass:[UIViewController class]]) return;
    UIWindow *window = controller.view.window;
    UIView *root = window.rootViewController.view;
    if (!window || !root || window.windowLevel != UIWindowLevelNormal) return;

    // Visit only views belonging to this controller. Never walk the entire app
    // hierarchy outside this scene or modify unrelated windows.
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    CGFloat tabBarBottom = -1.0;
    NSUInteger visited = 0;
    while (queue.count && visited++ < 700) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [views addObject:view];
        if ([view isKindOfClass:[UITabBar class]] && !view.hidden && view.alpha > 0.5) {
            CGRect fr = GNWindowFrame(view, window);
            if (fr.size.height > 40.0 && fr.size.height < 70.0 &&
                CGRectGetMaxY(fr) > tabBarBottom) tabBarBottom = CGRectGetMaxY(fr);
        }
        if (queue.count < 500) [queue addObjectsFromArray:view.subviews];
    }
    if (tabBarBottom < 0.0) return;

    UIView *candidate = nil;
    NSUInteger count = 0;
    for (UIView *view in views) {
        if (!GNSlotGeometryMatches(view, window, tabBarBottom)) continue;
        candidate = view;
        count++;
    }
    if (count != 1 || !candidate || objc_getAssociatedObject(candidate, kGNBottomSlotDoneKey)) return;

    NSLayoutConstraint *fixedHeight = GNFindFixedHeightConstraint(candidate);
    if (!fixedHeight) {
        // No proven owner of the 74pt height: altering the parent's geometry
        // would risk moving the tabbar or destroying the safe area.
        GNLog(@"74pt slot matched, but no own fixed height constraint found; no layout change");
        return;
    }

    // Mark before changing the constraint to prevent layout-loop reentry.
    objc_setAssociatedObject(candidate, kGNBottomSlotDoneKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    fixedHeight.constant = 0.0;
    [candidate.superview setNeedsLayout];
    GNLog(@"Collapsed exact 74pt hidden slot height constraint (experimental)");
}
