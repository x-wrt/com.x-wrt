#
# Copyright (C) 2016 Nikil Mehta <nikil.mehta@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sendip
PKG_VERSION:=2.5-r1
PKG_TAG:=20220426

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_TAG).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/ptpt52/sendip/tar.gz/$(PKG_TAG)?
PKG_HASH:=1abf430f93741ff946fcd38152aea420b6745d5bc250dd507e4d15b40d04e524

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

TAR_OPTIONS+= --strip-components 1
TAR_CMD=$(HOST_TAR) -C $(1) $(TAR_OPTIONS)

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
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/bgp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/icmp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipv4.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipv6.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ntp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ripng.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/rip.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tcp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/udp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/ah.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/dest.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/esp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/frag.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/gre.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/hop.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/route.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/sctp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/wesp.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/xorauth.so $(1)/usr/lib/sendip/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mec/xorcrypto.so $(1)/usr/lib/sendip/
endef

$(eval $(call BuildPackage,sendip))
