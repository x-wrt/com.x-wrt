#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=rtw8852cu
PKG_VERSION:=20231106

PKG_SOURCE_URL:=https://codeload.github.com/x-wrt/rtw8852cu/tar.gz/$(PKG_VERSION)?
PKG_HASH:=b4e045b384c03353e8531e1a1ece099d52a540080a169b26ed558bfffc6e94c1
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0-only
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

STAMP_CONFIGURED_DEPENDS := $(STAGING_DIR)/usr/include/mac80211-backport/backport/autoconf.h

define KernelPackage/rtw8852cu
  CATEGORY:=X
  TITLE:=Driver for Realtek 8852 CU devices
  FILES:=$(PKG_BUILD_DIR)/8852cu.ko
  AUTOLOAD:=$(call AutoProbe,8852cu)
  DEPENDS:=+kmod-cfg80211 +kmod-usb-core +@DRIVER_11AX_SUPPORT
endef

NOSTDINC_FLAGS := \
        $(KERNEL_NOSTDINC_FLAGS) \
        -I$(PKG_BUILD_DIR) \
        -I$(PKG_BUILD_DIR)/include \
        -I$(STAGING_DIR)/usr/include/mac80211-backport \
        -I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
        -I$(STAGING_DIR)/usr/include/mac80211 \
        -I$(STAGING_DIR)/usr/include/mac80211/uapi \
        -include backport/backport.h \
        -Wno-error=address \
        -Wno-error=stringop-overread

NOSTDINC_FLAGS+=-DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT -DCONFIG_RADIO_WORK -DBUILD_OPENWRT

define Build/Compile
        +$(KERNEL_MAKE) $(PKG_JOBS) \
                M="$(PKG_BUILD_DIR)" \
                NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
                modules
endef

$(eval $(call KernelPackage,rtw8852cu))
