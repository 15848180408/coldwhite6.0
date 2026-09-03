ARCHS = arm64 arm64e
TARGET = iphone:clang:14.5:14.0

BUNDLE_NAME = ColdWhitePrefs
ColdWhitePrefs_RESOURCE_FILES = Root.plist Info.plist
ColdWhitePrefs_OBJC_FILES = CWRootListController.m
ColdWhitePrefs_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
