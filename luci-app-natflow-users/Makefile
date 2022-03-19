#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-natflow-users
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-natflow-users
	CATEGORY:=X
	SUBMENU:=Natflow users module support
	TITLE:=LuCI Support for natflow users
	PKGARCH:=all
	DEPENDS:= +natflow-auth
endef

define Package/luci-app-natflow-users/description
	LuCI Support for natflow users.
endef

define Build/Prepare
	$(foreach po,$(wildcard ${CURDIR}/files/luci/i18n/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-natflow-users/postinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ]; then
  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
  ( . /etc/uci-defaults/95-natflow )
  rm -f /etc/uci-defaults/95-natflow
fi

exit 0
endef

define Package/luci-app-natflow-users/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/uci.defaults $(1)/etc/uci-defaults/95-natflow
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/natflow-users.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/*.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.natflow $(1)/usr/libexec/rpcd/luci.natflow
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/system
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/system/natflow-users.js $(1)/www/luci-static/resources/view/system/natflow-users.js
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/status/include
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/status/include/35_natflow-users.js $(1)/www/luci-static/resources/view/status/include/35_natflow-users.js
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/status/natflow-users.js $(1)/www/luci-static/resources/view/status/natflow-users.js
endef

$(eval $(call BuildPackage,luci-app-natflow-users))
