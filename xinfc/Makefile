#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=xinfc
PKG_VERSION:=20240616

PKG_SOURCE_URL:=https://codeload.github.com/ptpt52/xinfc/tar.gz/$(PKG_VERSION)?
PKG_HASH:=9a64f40936c816707929ee86e6761c1ad1186c0b1ea55944f9a3d263bacd9e95
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/xinfc/Default
  CATEGORY:=X
  SUBMENU:=NFC tools
endef

define Package/xinfc
  $(call Package/xinfc/Default)
  TITLE:=xinfc
  DEPENDS:=+libstdcpp
endef

define Package/xinfc/description
 Tools for interfacing with the NFC chip on Xiaomi routers
endef

define Build/Configure
endef

define Package/xinfc/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/xinfc-wsc $(1)/usr/sbin/xinfc-wsc
endef

$(eval $(call BuildPackage,xinfc))
