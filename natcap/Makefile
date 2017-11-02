#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=natcap
PKG_VERSION:=5.0.1
PKG_RELEASE:=715637e9740e4ef907966ee61a675a2a4ccebd0a

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/ptpt52/natcap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/natcapd-client
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  DEPENDS:= +libev +libc
  TITLE:=Natcapd_client agent for natcap
endef

define Package/natcapd-server
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  DEPENDS:= +libev +libc
  TITLE:=Natcapd_server agent for natcap
endef

define Package/natcapd-client/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/natcapd/natcapd-client $(1)/usr/sbin/natcapd-client
endef

define Package/natcapd-server/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/natcapd/natcapd-server $(1)/usr/sbin/natcapd-server
endef

define Package/natcapd/Default
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  DEPENDS:= +kmod-natcap +mosquitto-client-ssl +mosquitto-client
endef

define Package/natcapd
  $(call Package/natcapd/Default)
  TITLE:=Natcapd agent for natcap
endef

define Package/natcapd/description
 Natcapd agent for natcap
endef

define Build/Configure
endef

define Package/natcapd/conffiles
/etc/config/natcapd
endef

define Package/natcapd/postinst
#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/95-natcapd )
  rm -f /etc/uci-defaults/95-natcapd
fi

exit 0
endef

define Package/natcapd/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/natcapd.init $(1)/etc/init.d/natcapd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/natcapd.config $(1)/etc/config/natcapd
	$(INSTALL_DIR) $(1)/usr/share/natcapd
	$(INSTALL_DATA) ./files/firewall.include $(1)/usr/share/natcapd/firewall.include
	$(INSTALL_DATA) ./files/accelerated-domains.gfwlist.dnsmasq.conf $(1)/usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf
	$(INSTALL_DATA) ./files/gfwlist_update.sh $(1)/usr/share/natcapd/gfwlist_update.sh
	$(INSTALL_DATA) ./files/natcapd.pptpd.sh $(1)/usr/share/natcapd/natcapd.pptpd.sh
	$(INSTALL_DATA) ./files/board_mac.lua $(1)/usr/share/natcapd/board_mac.lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/cniplist.set $(1)/usr/share/natcapd/cniplist.set
	$(INSTALL_DATA) ./files/cacert.pem $(1)/usr/share/natcapd/cacert.pem
	$(INSTALL_DATA) ./files/hosts $(1)/usr/share/natcapd/hosts
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/natcapd.sh $(1)/usr/sbin/natcapd
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/natcapd.defaults $(1)/etc/uci-defaults/95-natcapd
endef

define KernelPackage/natcap
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  TITLE:=Natcap kernel driver
  FILES:=$(PKG_BUILD_DIR)/natcap.ko
  KCONFIG:=
  AUTOLOAD:=$(call AutoLoad,96,natcap)
  DEPENDS:= +kmod-ipt-conntrack +kmod-ipt-nat +kmod-ipt-ipset
endef

define KernelPackage/natcap/description
  Driver for natcap packet proxy to avoid inspection
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Compile/natcap
	$(MAKE) $(KERNEL_MAKEOPTS) SUBDIRS="$(PKG_BUILD_DIR)" modules
endef

define Build/Compile/natcapd-client
	+$(MAKE_VARS) $(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/natcapd natcapd-client $(MAKE_FLAGS)
endef

define Build/Compile/natcapd-server
	+$(MAKE_VARS) $(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/natcapd natcapd-server $(MAKE_FLAGS)
endef

define Build/Compile
	$(call Build/Compile/natcap)
ifneq ($(CONFIG_PACKAGE_natcapd-client),)
	$(call Build/Compile/natcapd-client)
endif
ifneq ($(CONFIG_PACKAGE_natcapd-server),)
	$(call Build/Compile/natcapd-server)
endif
endef

$(eval $(call KernelPackage,natcap))
$(eval $(call BuildPackage,natcapd))
$(eval $(call BuildPackage,natcapd-client))
$(eval $(call BuildPackage,natcapd-server))
