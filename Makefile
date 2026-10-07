THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Music

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MusicDrop
MusicDrop_FILES = Tweak.xm MusicDrop/MDImportCoordinator.m MusicDrop/MDTrackMetadata.m MusicDrop/MDImportViewController.m MusicDrop/MDHubViewController.m MusicDrop/MDMediaConverter.m
MusicDrop_CFLAGS = -fobjc-arc
MusicDrop_FRAMEWORKS = UIKit Foundation AVFoundation MediaPlayer UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk
