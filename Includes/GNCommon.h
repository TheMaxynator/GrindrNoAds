#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Settings are read once at process launch. Missing/unreadable files use safe defaults.
FOUNDATION_EXPORT void GNLoadConfiguration(void);
FOUNDATION_EXPORT BOOL GNIsNetworkFilteringEnabled(void);
FOUNDATION_EXPORT BOOL GNIsViewRemovalEnabled(void);
FOUNDATION_EXPORT BOOL GNIsContainerCleanupEnabled(void);
FOUNDATION_EXPORT BOOL GNIsAggressiveManagerResetEnabled(void);
FOUNDATION_EXPORT BOOL GNDebugEnabled(void);
FOUNDATION_EXPORT BOOL GNHostIsBlocked(NSString * _Nullable host);
FOUNDATION_EXPORT void GNLog(NSString * _Nonnull format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT void GNInstallNetworkHooks(void);
FOUNDATION_EXPORT void GNInstallAdViewHooks(void);
FOUNDATION_EXPORT void GNInstallContainerHooks(void);
