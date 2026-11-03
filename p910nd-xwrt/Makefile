#
# Copyright (C) 2009-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=p910nd-xwrt
PKG_VERSION:=0.97
PKG_RELEASE:=16

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/p910nd-xwrt
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Printing
  TITLE:=A small non-spooling printer server (X-Wrt)
  PROVIDES:=p910nd
  CONFLICTS:=p910nd
  URL:=https://github.com/kenyapcomau/p910nd
  USERID:=p910nd=393:lp=7
endef

define Package/p910nd-xwrt/conffiles
/etc/config/p910nd
endef

define Package/p910nd-xwrt/description
 X-Wrt variant of the p910nd printer server.
 p910nd is a small daemon that copies any data received on
 the port it is listening on to the corresponding printer
 port. It is primarily intended for diskless Linux hosts
 running as printer drivers but there is no reason why it
 could not be used on diskful hosts. Port 9100 is copied
 to /dev/lp0, 9101 to /dev/lp1 and 9102 to /dev/lp2. The
 default is port 9100 to /dev/lp0.
endef

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS) -DLOCKFILE_DIR=\"\\\"/tmp\"\\\""

define Package/p910nd-xwrt/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(CP) $(PKG_INSTALL_DIR)/usr/sbin/p910nd $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/p910nd.config $(1)/etc/config/p910nd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/p910nd.init $(1)/etc/init.d/p910nd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/usbmisc
	$(INSTALL_BIN) ./files/p910nd.hotplug $(1)/etc/hotplug.d/usbmisc/20-p910nd
endef

$(eval $(call BuildPackage,p910nd-xwrt))
