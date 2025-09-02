#
# Copyright (C) 2025 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=shell-functions
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/shell-functions
  CATEGORY:=X
  SUBMENU:=Libs
  PKGARCH:=all
  TITLE:=shell functions lib
  DEPENDS:=+busybox
endef

define Package/shell-functions/install
	$(INSTALL_DIR) $(1)/lib/functions
	$(INSTALL_DATA) ./files/shell-functions.sh $(1)/lib/functions/shell-functions.sh
endef

define Build/Prepare
	true
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,shell-functions))
