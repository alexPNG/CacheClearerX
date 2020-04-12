
ARCHS= arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CacheClearerX

CacheClearerX_FILES = Tweak.xm
CacheClearerX_FRAMEWORKS = CydiaSubstrate UIKit MobileCoreServices CoreGraphics CoreFoundation Foundation
CacheClearerX_PRIVATE_FRAMEWORKS = SpringBoardServices Preferences
CacheClearerX_LDFLAGS = -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk