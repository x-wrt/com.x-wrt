#
# Copyright (C) 2016 Nikil Mehta <nikil.mehta@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sendip
PKG_VERSION:=2.5-mec-0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://www-x.antd.nist.gov/ipv6/sendip/
PKG_HASH:=4364aca5046e68747315d76543868d42fafd69452a251e86fa973266e7000da8

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

define Package/sendip
  CATEGORY:=X
  TITLE:=SendIP
  URL:=https://www-x.antd.nist.gov/ipv6/sendip.html
  DEPENDS:=
endef

define Package/sendip/description
	SendIP is a tool which allows creating (and, of course, sending) arbitrary IP (v4 and v6) packets.
endef

define Package/sendip/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sendip $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/lib/sendip
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bgp.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/icmp.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipv4.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipv6.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ntp.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ripng.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rip.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tcp.so $(1)/usr/lib/sendip/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/udp.so $(1)/usr/lib/sendip/
endef

$(eval $(call BuildPackage,sendip))
