GO_EASY_ON_ME = 1
ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

TWEAK_NAME = BurstMode
BurstMode_FILES = BurstMode.xm
BurstMode_FRAMEWORKS = UIKit
BurstMode_PRIVATE_FRAMEWORKS = GraphicsServices PhotoLibrary PhotosUI

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = BurstModeSettings
BurstModeSettings_FILES = BurstModePreferenceController.m
BurstModeSettings_INSTALL_PATH = /Library/PreferenceBundles
BurstModeSettings_PRIVATE_FRAMEWORKS = Preferences
BurstModeSettings_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BurstMode.plist$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)
