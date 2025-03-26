#
# Copyright (C) 2011-2022 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=upx
PKG_VERSION:=4.2.4
PKG_RELEASE:=1

PKG_MAINTAINER:=Xingwang Liao <kuoruan@gmail.com>
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING LICENSE

PKG_SOURCE_URL:=https://github.com/upx/upx/releases/download/v$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-src.tar.xz
PKG_HASH:=5ed6561607d27fb4ef346fc19f08a93696fa8fa127081e7a7114068306b8e1c4
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-src

PKG_BUILD_PARALLEL:=1

HOST_BUILD_DIR:=$(BUILD_DIR_HOST)/$(PKG_NAME)-$(PKG_VERSION)-src

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk

define Host/Compile
	$(call Host/Compile/Default,build/release)
endef

define Host/Install
	$(CP) $(HOST_BUILD_DIR)/build/release/upx $(STAGING_DIR_HOST)/bin/upx
endef

define Host/Clean
	rm -f $(STAGING_DIR_HOST)/bin/upx
endef

define Package/upx
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+libstdcpp +zlib
  TITLE:=The Ultimate Packer for eXecutables
  URL:=https://upx.github.io/
endef

define Package/upx/description
UPX is a free, portable, extendable, high-performance executable packer for
several different executable formats. It achieves an excellent compression ratio
and offers very fast decompression. Your executables suffer no memory overhead
or other drawbacks for most of the formats supported, because of in-place
decompression.
endef

define Build/Compile
	$(call Build/Compile/Default,build/release)
endef

define Package/upx/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/release/upx $(1)/usr/bin/upx
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,upx))
