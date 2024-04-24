#
# Copyright (C) 2020-2025 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-autoreboot
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-autoreboot
	CATEGORY:=X
	SUBMENU:=Auto reboot bot app.
	TITLE:=LuCI Support for autoreboot
	PKGARCH:=all
	DEPENDS:=+busybox +@BUSYBOX_CONFIG_CROND
endef

define Package/luci-app-autoreboot/description
	LuCI Support for autoreboot.
endef

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/files/luci/i18n/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-autoreboot/conffiles
/etc/config/autoreboot
endef

define Package/luci-app-autoreboot/postinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/40_luci-app-autoreboot )
  rm -f /etc/uci-defaults/40_luci-app-autoreboot

  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
fi

exit 0
endef

define Package/luci-app-autoreboot/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/autoreboot.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./root/etc/config/autoreboot $(1)/etc/config/autoreboot
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/autoreboot $(1)/etc/init.d/autoreboot
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./root/etc/uci-defaults/40_luci-app-autoreboot $(1)/etc/uci-defaults/40_luci-app-autoreboot
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/*.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/system
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/system/autoreboot.js $(1)/www/luci-static/resources/view/system/autoreboot.js
	$(INSTALL_DIR) $(1)/usr/share/ucitrack
	$(INSTALL_DATA) ./root/usr/share/ucitrack/*.json $(1)/usr/share/ucitrack/
endef

$(eval $(call BuildPackage,luci-app-autoreboot))
