# SPDX-License-Identifier: GPL-3.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudflare-tunnel
PKG_VERSION:=1.0.0
PKG_RELEASE:=7
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_BUILD_DEPENDS:=luci-base/host

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cloudflare-tunnel
	CATEGORY:=X
	SUBMENU:=Cloudflare Tunnel
	TITLE:=Automatically publish this router through Cloudflare Tunnel
	PKGARCH:=all
	DEPENDS:=+luci-base +cloudflared +curl +ca-bundle +lua +libuci-lua +libubus-lua +luci-lib-jsonc +luci-lib-nixio
endef

define Package/luci-app-cloudflare-tunnel/description
	Create and update a Cloudflare Tunnel using an API token and a complete
	access hostname. Account, zone, DNS and connector configuration are automatic.
endef

define Build/Compile
	po2lmo ./po/zh_Hans/cloudflare-tunnel.po $(PKG_BUILD_DIR)/cloudflare-tunnel.zh-cn.lmo
endef

define Package/luci-app-cloudflare-tunnel/conffiles
/etc/config/cloudflare-tunnel
/etc/cloudflare-tunnel/
endef

define Package/luci-app-cloudflare-tunnel/install
	$(CP) ./root/* $(1)/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/cloudflare-tunnel
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cloudflare-tunnel/* $(1)/www/luci-static/resources/view/cloudflare-tunnel/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/cloudflare-tunnel.zh-cn.lmo $(1)/usr/lib/lua/luci/i18n/
	chmod 600 $(1)/etc/config/cloudflare-tunnel
	chmod 755 $(1)/etc/init.d/cloudflare-tunnel $(1)/etc/uci-defaults/95-cloudflare-tunnel $(1)/usr/libexec/rpcd/luci.cloudflare_tunnel $(1)/usr/libexec/cloudflare-tunnel
endef

define Package/luci-app-cloudflare-tunnel/postinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ]; then
	if [ -x /etc/uci-defaults/95-cloudflare-tunnel ]; then
		/etc/uci-defaults/95-cloudflare-tunnel
		rm -f /etc/uci-defaults/95-cloudflare-tunnel
	fi
	/etc/init.d/rpcd reload >/dev/null 2>&1
fi
exit 0
endef

$(eval $(call BuildPackage,luci-app-cloudflare-tunnel))
