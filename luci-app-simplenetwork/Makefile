#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-simplenetwork
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-simplenetwork
	CATEGORY:=X
	SUBMENU:=Configuration SimpleNetwork Support
	TITLE:=LuCI Support for simplenetwork
	PKGARCH:=all
	DEPENDS:=
endef

define Package/luci-app-simplenetwork/description
	LuCI Support for simplenetwork.
endef

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/files/luci/i18n/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-simplenetwork/conffiles
/etc/config/simplenetwork
endef

define Package/luci-app-simplenetwork/postinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/40_luci-app-simplenetwork )
  rm -f /etc/uci-defaults/40_luci-app-simplenetwork

  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
fi

exit 0
endef

define Package/luci-app-simplenetwork/install-overlay
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-p910nd.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-base.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-mod-status.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-mod-system.json $(1)/usr/share/luci/menu.d/
endef


define Package/luci-app-simplenetwork/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/simplenetwork.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./root/etc/config/simplenetwork $(1)/etc/config/simplenetwork
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/simplenetwork $(1)/etc/init.d/simplenetwork
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./root/etc/uci-defaults/40_luci-app-simplenetwork $(1)/etc/uci-defaults/40_luci-app-simplenetwork
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-simplenetwork.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/simplenetwork
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/simplenetwork/*.js $(1)/www/luci-static/resources/view/simplenetwork/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/system
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/system/*.js $(1)/www/luci-static/resources/view/system/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/p910nd
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/p910nd/*.js $(1)/www/luci-static/resources/view/p910nd/
endef

$(eval $(call BuildPackage,luci-app-simplenetwork))
