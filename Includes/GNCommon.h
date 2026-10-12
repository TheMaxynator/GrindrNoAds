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
FOUNDATION_EXPORT BOOL GNIsExperimentalBottomGapFixEnabled(void);
FOUNDATION_EXPORT BOOL GNHostIsBlocked(NSString * _Nullable host);
FOUNDATION_EXPORT void GNLog(NSString * _Nonnull format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT void GNInstallNetworkHooks(void);
FOUNDATION_EXPORT void GNInstallAdViewHooks(void);
FOUNDATION_EXPORT void GNInstallContainerHooks(void);

// The settings panel is opened by a two-finger long press inside Grindr.
FOUNDATION_EXPORT void GNInstallSettingsGesture(void);
FOUNDATION_EXPORT void GNInstallConfiguredHooks(void);

// Conservative removal of a dedicated one-child host around a known ad view.
FOUNDATION_EXPORT void GNHandleKnownAdViewHost(UIView * _Nonnull adView);
// Optional on-device inspector. Captures class names/frames only; no user content.
FOUNDATION_EXPORT void GNBeginGapDiagnosis(UIWindow * _Nonnull window);

// Opt-in geometry-matched 74pt ad-placeholder collapse. Never shifts tab/safe areas directly.
FOUNDATION_EXPORT void GNApplyBottomGapFix(UIViewController * _Nonnull controller);
