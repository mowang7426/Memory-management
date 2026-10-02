THEOS ?= $(HOME)/theos
ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:15.0
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MemoryManagementPrefs
MemoryManagementPrefs_FILES = MMRootListController.m
MemoryManagementPrefs_FRAMEWORKS = UIKit CoreFoundation
MemoryManagementPrefs_PRIVATE_FRAMEWORKS = Preferences MobileCoreServices
MemoryManagementPrefs_INSTALL_PATH = /Library/PreferenceBundles
MemoryManagementPrefs_CFLAGS = -fobjc-arc
MemoryManagementPrefs_EXTRA_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/bundle.mk
