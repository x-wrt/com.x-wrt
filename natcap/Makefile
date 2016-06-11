#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=natcap
PKG_VERSION:=4.0.0
PKG_RELEASE:=cb845c97674d7b9a52d8ef12e1c8e4715debd9be

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/ptpt52/natcap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/natcapd/Default
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  AUTOLOAD:=$(call AutoProbe,natcapd)
  DEPENDS:= +kmod-natcap
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
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DATA) ./files/natcapd.hotplug $(1)/etc/hotplug.d/iface/95-natcapd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/natcapd.config $(1)/etc/config/natcapd
	$(INSTALL_DIR) $(1)/usr/share/natcapd
	$(INSTALL_DATA) ./files/firewall.include $(1)/usr/share/natcapd/firewall.include
	$(INSTALL_DATA) ./files/accelerated-domains.gfwlist.dnsmasq.conf $(1)/usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf
	$(INSTALL_DATA) ./files/gfwlist_update.sh $(1)/usr/share/natcapd/gfwlist_update.sh
	$(INSTALL_DATA) ./files/cniplist.set $(1)/usr/share/natcapd/cniplist.set
	$(INSTALL_DATA) ./files/cacert.pem $(1)/usr/share/natcapd/cacert.pem
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/natcapd.sh $(1)/usr/sbin/natcapd
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/natcapd.defaults $(1)/etc/uci-defaults/95-natcapd
	$(INSTALL_DATA) ./files/adv_luci_disabled $(1)/etc/adv_luci_disabled
endef

define KernelPackage/natcap
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  TITLE:=Natcap kernel driver
  FILES:=$(PKG_BUILD_DIR)/natcap.ko
  AUTOLOAD:=$(call AutoProbe,natcap)
  KCONFIG:=
  DEPENDS:=+kmod-nf-conntrack +kmod-nf-nat +kmod-ipt-ipset
endef

define KernelPackage/natcap/description
  Driver for natcap packet proxy to avoid inspection
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

MAKE_KMOD := $(MAKE) -C "$(LINUX_DIR)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		PATH="$(TARGET_PATH)" \
		SUBDIRS="$(PKG_BUILD_DIR)" \

define Build/Compile
	$(MAKE_KMOD) \
		MODFLAGS="-DMODULE" \
		modules
	pwd
endef

$(eval $(call KernelPackage,natcap))
$(eval $(call BuildPackage,natcapd))
