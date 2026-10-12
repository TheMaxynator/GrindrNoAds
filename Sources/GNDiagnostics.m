#import "Includes/GNCommon.h"
#import <math.h>

// User-triggered, one-shot layout inspector. It never captures text, images,
// profile content, device identifiers, network traffic, or private app data.
@interface GNGapCaptureHandler : NSObject
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) NSUInteger generation;
- (void)capturedTap:(UITapGestureRecognizer *)gesture;
- (void)clearTap;
@end

static GNGapCaptureHandler *gGapCapture;

static UIViewController *GNDiagPresenter(UIWindow *window) {
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        vc = vc.presentedViewController;
    }
    return vc;
}

static NSString *GNViewGeometry(UIView *view, UIWindow *window) {
    CGRect frame = [view convertRect:view.bounds toView:window];
    return [NSString stringWithFormat:@"%@ x%.0f y%.0f w%.0f h%.0f %@ a%.1f children%lu",
            NSStringFromClass(view.class), frame.origin.x, frame.origin.y,
            frame.size.width, frame.size.height, view.hidden ? @"hidden" : @"visible",
            view.alpha, (unsigned long)view.subviews.count];
}

static NSString *GNRelevantConstraints(UIView *view) {
    NSMutableArray<NSLayoutConstraint *> *candidates = [NSMutableArray arrayWithArray:view.constraints];
    if (view.superview) [candidates addObjectsFromArray:view.superview.constraints];
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (NSLayoutConstraint *c in candidates) {
        if (!c.active || (c.firstItem != view && c.secondItem != view)) continue;
        if (c.firstAttribute != NSLayoutAttributeHeight &&
            c.secondAttribute != NSLayoutAttributeHeight &&
            c.firstAttribute != NSLayoutAttributeBottom &&
            c.secondAttribute != NSLayoutAttributeBottom &&
            c.firstAttribute != NSLayoutAttributeTop &&
            c.secondAttribute != NSLayoutAttributeTop) continue;
        [items addObject:[NSString stringWithFormat:@"%ld/%ld constant %.1f p%.0f",
                (long)c.firstAttribute, (long)c.secondAttribute,
                c.constant, c.priority]];
        if (items.count >= 4) break;
    }
    return items.count ? [items componentsJoinedByString:@"; "] : @"(no direct top/bottom/height constraints)";
}

static NSString *GNGenerateGapReport(UIWindow *window, CGPoint point) {
    UIView *hit = [window hitTest:point withEvent:nil];
    NSMutableString *s = [NSMutableString stringWithFormat:
        @"GrindrNoAds 1.1.1 beta2 | tapped x%.0f y%.0f | window %.0fx%.0f\n",
        point.x, point.y, window.bounds.size.width, window.bounds.size.height];
    [s appendString:@"Ancestor chain (screen geometry only):\n"];
    UIView *current = hit;
    for (NSUInteger depth = 0; current && depth < 12; depth++, current = current.superview) {
        [s appendFormat:@"%lu: %@\n   %@\n", (unsigned long)depth,
            GNViewGeometry(current, window), GNRelevantConstraints(current)];
        if (current == window) break;
    }

    // Include nearby thin wrappers to distinguish a reserved ad host from
    // normal bottom navigation; do not include labels/text or view contents.
    [s appendString:@"Bottom-area nearby direct descendants (max 12):\n"];
    UIView *root = window.rootViewController.view;
    NSMutableArray<UIView *> *queue = [NSMutableArray array];
    if (root) [queue addObject:root];
    NSUInteger visited = 0, recorded = 0;
    while (queue.count && visited < 350 && recorded < 12) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        visited++;
        CGRect fr = [view convertRect:view.bounds toView:window];
        if (view != root && fr.size.height > 1 && fr.size.height < 210 &&
            CGRectGetMaxY(fr) >= window.bounds.size.height - 210 &&
            fr.size.width >= window.bounds.size.width * 0.45) {
            [s appendFormat:@"- %@\n", GNViewGeometry(view, window)];
            recorded++;
        }
        if (queue.count < 200) [queue addObjectsFromArray:view.subviews];
    }
    return s;
}

@implementation GNGapCaptureHandler
- (void)clearTap {
    if (self.tap) [self.window removeGestureRecognizer:self.tap];
    self.tap = nil;
}
- (void)capturedTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    UIWindow *window = self.window;
    CGPoint point = [gesture locationInView:window];
    [self clearTap];
    if (!window) return;
    NSString *report = GNGenerateGapReport(window, point);
    UIViewController *presenter = GNDiagPresenter(window);
    if (!presenter) return;
    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"Layout-diagnose"
       message:@"Alleen classnamen, afmetingen en constraints. Tik op ‘Kopieer rapport’ en plak dit in ChatGPT."
       preferredStyle:UIAlertControllerStyleAlert];
    [dialog addAction:[UIAlertAction actionWithTitle:@"Kopieer rapport"
       style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
           [UIPasteboard generalPasteboard].string = report;
       }]];
    [dialog addAction:[UIAlertAction actionWithTitle:@"Sluiten" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:dialog animated:YES completion:nil];
}
@end

void GNBeginGapDiagnosis(UIWindow *window) {
    if (!window) return;
    UIViewController *presenter = GNDiagPresenter(window);
    if (!presenter || [presenter isKindOfClass:[UIAlertController class]]) return;
    UIAlertController *prompt = [UIAlertController alertControllerWithTitle:@"Lege bannerruimte onderzoeken"
       message:@"Tik straks één keer op het midden van de lege strook onder de profielgrid. De volgende tik wordt uitsluitend gebruikt om layoutinformatie te verzamelen."
       preferredStyle:UIAlertControllerStyleAlert];
    [prompt addAction:[UIAlertAction actionWithTitle:@"Annuleren" style:UIAlertActionStyleCancel handler:nil]];
    [prompt addAction:[UIAlertAction actionWithTitle:@"Start meting" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (!gGapCapture) gGapCapture = [GNGapCaptureHandler new];
                    [gGapCapture clearTap];
                    gGapCapture.window = window;
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                        initWithTarget:gGapCapture action:@selector(capturedTap:)];
                    tap.cancelsTouchesInView = YES;
                    gGapCapture.tap = tap;
                    [window addGestureRecognizer:tap];
                    NSUInteger generation = ++gGapCapture.generation;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
                            if (gGapCapture.generation == generation) [gGapCapture clearTap];
                        });
                });
        }]];
    [presenter presentViewController:prompt animated:YES completion:nil];
}
