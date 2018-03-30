#
# Copyright (C) 2009-2018 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gptfdisk
PKG_VERSION:=1.0.3
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=@SF/gptfdisk
PKG_MD5SUM:=07b625a583b66c8c5840be5923f3e3fe

include $(INCLUDE_DIR)/package.mk

define Package/gptfdisk
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Disc
  TITLE:=Partition table manipulation utility with GPT support
  URL:=http://www.rodsbooks.com/gdisk
  DEPENDS:=+libstdcpp +libpopt +libuuid
endef

define Package/gptfdisk/description
 Partition table manipulation utility with GPT support
endef

define Package/gptfdisk/install
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/gdisk $(1)/sbin/
endef

$(eval $(call BuildPackage,gptfdisk))
