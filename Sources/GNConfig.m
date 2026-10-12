#import "Includes/GNCommon.h"
#import <rootless.h>
#import <stdarg.h>

static BOOL gNet = YES;
static BOOL gViews = YES;
static BOOL gContainers = YES;
static BOOL gAggressive = NO;
static BOOL gDebug = NO;
static NSSet<NSString *> *gDomains;

static BOOL GNOption(NSDictionary *dict, NSString *key, BOOL defaultValue) {
    // The app-owned defaults domain is always accessible to code running inside Grindr.
    // File-backed defaults remain a fallback for older installations if sandbox permits.
    NSString *localKey = [@"GNA." stringByAppendingString:key];
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:localKey];
    if (value == nil) value = dict[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

void GNLoadConfiguration(void) {
    NSString *dir = ROOT_PATH_NS(@"/Library/Application Support/GrindrNoAds");
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:@"settings.plist"]];
    gNet = GNOption(settings, @"NetworkBlockingEnabled", YES);
    gViews = GNOption(settings, @"ViewRemovalEnabled", YES);
    gContainers = GNOption(settings, @"ContainerCleanupEnabled", YES);
    gAggressive = GNOption(settings, @"AggressiveManagerResetEnabled", NO);
    gDebug = GNOption(settings, @"DebugLoggingEnabled", NO);

    NSArray *fallback = @[@"applovin.com", @"unity3d.com", @"vungle.com", @"doubleclick.net",
        @"adsmoloco.com", @"inmobi.com", @"smadex.com", @"mtgglobals.com", @"tapad.com", @"onelink.me"];
    NSArray *fileDomains = [NSArray arrayWithContentsOfFile:[dir stringByAppendingPathComponent:@"blocked-domains.plist"]];
    // Fail closed to our *known* list if sandbox disallows reading external resources.
    NSArray *candidate = [fileDomains isKindOfClass:[NSArray class]] ? fileDomains : fallback;
    NSMutableSet<NSString *> *valid = [NSMutableSet new];
    for (id item in candidate) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *s = [[(NSString *)item lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([s length] == 0 || [s hasPrefix:@"."] || [s containsString:@"/"] || [s containsString:@":"] || [s containsString:@" "]) continue;
        [valid addObject:s];
    }
    gDomains = [valid copy];
    GNLog(@"Config net=%d views=%d containers=%d aggressive=%d domains=%lu",
          gNet, gViews, gContainers, gAggressive, (unsigned long)[gDomains count]);
}

BOOL GNIsNetworkFilteringEnabled(void) { return gNet; }
BOOL GNIsViewRemovalEnabled(void) { return gViews; }
BOOL GNIsContainerCleanupEnabled(void) { return gContainers; }
BOOL GNIsAggressiveManagerResetEnabled(void) { return gAggressive; }
BOOL GNDebugEnabled(void) { return gDebug; }

BOOL GNHostIsBlocked(NSString *host) {
    if (![host isKindOfClass:[NSString class]] || !host.length) return NO;
    NSString *normalized = [host lowercaseString];
    if ([normalized hasSuffix:@"."]) normalized = [normalized substringToIndex:normalized.length - 1];
    for (NSString *domain in gDomains) {
        // Do NOT block "notapplovin.com" just because it ends in "applovin.com".
        if ([normalized isEqualToString:domain] || [normalized hasSuffix:[@"." stringByAppendingString:domain]]) {
            return YES;
        }
    }
    return NO;
}

void GNLog(NSString *format, ...) {
    if (!gDebug || !format) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[GrindrNoAds] %@", message);
}
