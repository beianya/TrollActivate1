TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Podcasts

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = TrollActivate

TrollActivate_FILES = TrollActivate.m
TrollActivate_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TrollActivate_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/library.mk
