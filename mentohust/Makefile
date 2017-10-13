#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mentohust
PKG_VERSION:=4.0.0
PKG_RELEASE:=857f5a112213393cf6fb19607fe9da61284c5a50

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/hyrathb/mentohust.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/mentohust/Default
  CATEGORY:=Ptpt52
  SUBMENU:=Mentohust
  DEPENDS:= +libpcap
endef

define Package/mentohust
  $(call Package/mentohust/Default)
  TITLE:=Mentohust v4 support
endef

define Package/mentohust/description
 Mentohust v4 support
endef

define Build/Configure
endef

define Package/mentohust/conffiles
/etc/config/mentohust
endef

define Package/mentohust/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/mentohust.init $(1)/etc/init.d/mentohust
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/mentohust.config $(1)/etc/config/mentohust
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/mentohust $(1)/usr/sbin/mentohust
endef

define Build/Configure
	( cd $(PKG_BUILD_DIR); ./autogen.sh )
	$(call Build/Configure/Default)
endef

$(eval $(call BuildPackage,mentohust))
