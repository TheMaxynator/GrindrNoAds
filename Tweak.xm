#import "Includes/GNCommon.h"

// Avoid missing Swift classes when the injection happens before module registration.
// Each module's install method is idempotent and can safely be retried at app lifecycle events.
static void GNInstallConfiguredHooks(void) {
    if (GNIsNetworkFilteringEnabled()) GNInstallNetworkHooks();
    if (GNIsViewRemovalEnabled()) GNInstallAdViewHooks();
    if (GNIsContainerCleanupEnabled()) GNInstallContainerHooks();
}

// Runs in Grindr only; neither original SpringBoard hook nor license code is used.
%ctor {
    @autoreleasepool {
        NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
        if (![identifier isEqualToString:@"com.grindrguy.grindrx"]) return;
        GNLoadConfiguration();
        GNLog(@"Starting in %@", identifier);
        GNInstallConfiguredHooks();
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil
                       usingBlock:^(NSNotification *note) { GNInstallConfiguredHooks(); }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil
                       usingBlock:^(NSNotification *note) { GNInstallConfiguredHooks(); }];
    }
}
