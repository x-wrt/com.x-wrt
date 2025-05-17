#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=urllogger
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/urllogger
  CATEGORY:=X
  DEPENDS:=+kmod-natflow
  TITLE:=urllogger
endef

define Package/urllogger/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/urllogger.sh $(1)/usr/sbin/urllogger
	$(INSTALL_BIN) ./files/urllogger-ctl.sh $(1)/usr/sbin/urllogger-ctl
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/urllogger.init $(1)/etc/init.d/urllogger
endef

define Build/Prepare
	true
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,urllogger))
