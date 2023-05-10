DEBUG=0
FINALPACKAGE=1
GO_EASY_ON_ME=1

THEOS_PACKAGE_SCHEME = rootless

THEOS_USE_NEW_ABI=1
TARGET = iphone:14.5:14.5
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME = p4octl

p4octl_FILES = main.m
p4octl_CFLAGS = -fobjc-arc
p4octl_CODESIGN_FLAGS = -Sentitlements.plist
p4octl_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
