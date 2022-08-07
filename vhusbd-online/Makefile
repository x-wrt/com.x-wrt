#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
# Copyright (C) 2019 X-WRT <dev@x-wrt.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=vhusbd-online
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/vhusbd-online/Default
  SECTION:=Applications
  PKGARCH:=all
  CATEGORY:=X
endef

define Package/vhusbd-online
  $(call Package/vhusbd-online/Default)
  TITLE:=VirtualHere online version
endef

define Package/vhusbd-online/description
  VirtualHere allows USB devices to be used remotely over a network just as if they were locally connected.
endef

define Package/vhusbd-online/conffiles
/etc/vhusbd.conf
/etc/config/vhusbd
endef

define Package/vhusbd-online/install
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) ./files/vhusbd.conf $(1)/etc/vhusbd.conf
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/vhusbd.config $(1)/etc/config/vhusbd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/vhusbd.init $(1)/etc/init.d/vhusbd
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/vhusbd-online.sh $(1)/usr/bin/vhusbd-online
endef

define Build/Configure
endef

define Build/Prepare
endef

define Build/Compile
endef

$(eval $(call BuildPackage,vhusbd-online))
