include theos/makefiles/common.mk

TWEAK_NAME = AppTweeter
AppTweeter_FILES = Tweak.xm
AppTweeter_FRAMEWORKS = UIKit
THEOS_INSTALL_KILL = AppStore

include $(THEOS_MAKE_PATH)/tweak.mk
