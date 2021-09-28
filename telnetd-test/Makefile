#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=telnetd-test
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/telnetd-test
  CATEGORY:=X
  DEPENDS:=+busybox +@BUSYBOX_CUSTOM \
	   +@BUSYBOX_CONFIG_TELNETD \
	   +@BUSYBOX_CONFIG_FEATURE_TELNETD_STANDALONE
  TITLE:=telnetd-test for factory test only
endef

define Package/telnetd-test/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/telnetd-test.init $(1)/etc/init.d/telnetd-test
endef

define Build/Prepare
	true
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,telnetd-test))
