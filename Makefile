ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ColdWhite
ColdWhite_FILES = Tweak.xm
ColdWhite_CFLAGS = -fobjc-arc
ColdWhite_FRAMEWORKS = Foundation UIKit
SUBPROJECTS += ColdWhitePrefs
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
