#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=base-config
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Ptpt52
  SUBMENU:=Base config setup for this board
  DEPENDS:=
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=$(PKG_NAME)
endef

define Package/$(PKG_NAME)/description
  Base config for this board
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/base_config
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/95-base-config )
  rm -f /etc/uci-defaults/95-base-config
fi

exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/base_config.config $(1)/etc/config/base_config
ifeq ($(CONFIG_TARGET_ar71xx_generic_AP9341),y)
	$(INSTALL_DATA) ./files/ap9341.defaults $(1)/etc/uci-defaults/95-base-config
endif
ifeq ($(CONFIG_TARGET_ramips_mt7621_PUPPIES),y)
	$(INSTALL_DATA) ./files/mt7621.defaults $(1)/etc/uci-defaults/95-base-config
endif
ifeq ($(CONFIG_TARGET_x86_64_Generic),y)
	$(INSTALL_DATA) ./files/x86_64.defaults $(1)/etc/uci-defaults/95-base-config
	$(INSTALL_DATA) ./files/fstab.config $(1)/etc/config/fstab
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_DATA) ./files/disk_ready.preinit $(1)/lib/preinit/79_disk_ready
endif
ifeq ($(CONFIG_TARGET_ar71xx_nand_R6100),y)
	$(INSTALL_DATA) ./files/r6100.defaults $(1)/etc/uci-defaults/95-base-config
endif
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

