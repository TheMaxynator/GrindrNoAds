# Rootless-only jailbreak tweak. Compatible with Theos rootless layout.
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET = iphone:clang:latest:15.0
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = Grindr

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GrindrNoAds
GrindrNoAds_FILES = Tweak.xm Sources/GNConfig.m Sources/NetworkHooks.m Sources/AdViewHooks.m Sources/ContainerHooks.m
GrindrNoAds_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -I$(THEOS_PROJECT_DIR)
GrindrNoAds_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
