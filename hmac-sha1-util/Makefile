#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=hmac-sha1-util
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/hmac-sha1-util
  CATEGORY:=X
  SUBMENU:=hmac-sha1-util tools
  TITLE:=hmac-sha1-util util support
endef

define Package/hmac-sha1-util/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hmac-sha1-util $(1)/usr/bin/hmac-sha1-util
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

$(eval $(call BuildPackage,hmac-sha1-util))
