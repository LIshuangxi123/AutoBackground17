export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoBackground17 AutoBackground17App

# SpringBoard 侧：阻止应用被挂起/冻结 = 真后台（主方案）
AutoBackground17_FILES = src/AutoBGSpringBoardHooks.x.m src/AutoBGConfig.m
AutoBackground17_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# 应用侧：静音音频保活（备用方案，需在设置中开启）
AutoBackground17App_FILES = src/AutoBGApp.m src/AutoBGConfig.m
AutoBackground17App_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AutoBackground17App_FRAMEWORKS = UIKit AVFoundation AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

# 设置面板（设置 → 自动真后台）
BUNDLE_NAME = AutoBackground17Settings

AutoBackground17Settings_FILES = settings/AutoBGRootListController.m settings/AutoBGAppListController.m src/AutoBGConfig.m
AutoBackground17Settings_INSTALL_PATH = /Library/PreferenceBundles
AutoBackground17Settings_CFLAGS = -fobjc-arc
AutoBackground17Settings_FRAMEWORKS = UIKit
AutoBackground17Settings_PRIVATE_FRAMEWORKS = Preferences CoreServices MobileCoreServices

include $(THEOS_MAKE_PATH)/bundle.mk

include $(THEOS_MAKE_PATH)/aggregate.mk