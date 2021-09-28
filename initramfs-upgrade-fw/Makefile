#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=initramfs-upgrade-fw
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/initramfs-upgrade-fw
  CATEGORY:=X
  DEPENDS:=+busybox
  TITLE:=initramfs-upgrade-fw for factory test only
endef

define Package/initramfs-upgrade-fw/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/initramfs-upgrade-fw.sh $(1)/usr/sbin/initramfs-upgrade-fw
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/initramfs-upgrade-fw.init $(1)/etc/init.d/initramfs-upgrade-fw
endef

define Build/Prepare
	true
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,initramfs-upgrade-fw))
