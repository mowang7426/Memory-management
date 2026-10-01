THEOS ?= $(HOME)/theos
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MemoryManagement
MemoryManagement_FILES = Tweak.xm
MemoryManagement_FRAMEWORKS = Foundation
MemoryManagement_CFLAGS = -fobjc-arc

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
