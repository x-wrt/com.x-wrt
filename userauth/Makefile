#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=userauth
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Ptpt52
  DEPENDS:= +nginx +ebtables +iptables-mod-extra
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=User authentication
endef

define Package/$(PKG_NAME)/description
  Web access user authentication app
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/userauth
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/95-userauth )
  rm -f /etc/uci-defaults/95-userauth
fi

exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/userauth.defaults $(1)/etc/uci-defaults/95-userauth
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/userauthd.init $(1)/etc/init.d/userauthd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/userauth.config $(1)/etc/config/userauth
	$(INSTALL_DIR) $(1)/usr/share/userauth
	$(INSTALL_DATA) ./files/firewall.include $(1)/usr/share/userauth/firewall.include
	$(INSTALL_DATA) ./files/nginx.conf $(1)/usr/share/userauth/nginx.conf
	$(INSTALL_BIN) ./files/nginx.init $(1)/usr/share/userauth/nginx
	$(INSTALL_DIR) $(1)/usr/share/userauth/www
	cp -r ./files/www/* $(1)/usr/share/userauth/www/ || true
	$(INSTALL_DIR) $(1)/usr/share/userauth/lua
	cp -r ./files/lua/* $(1)/usr/share/userauth/lua || true
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/userauthd.sh $(1)/usr/sbin/userauthd
endef

define Build/Configure
  true
endef

define Build/Prepare
  true
endef

define Build/Compile
  true
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

