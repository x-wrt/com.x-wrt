#
# Copyright (C) 2006-2020 OpenWrt.org
# Copyright (C) 2020, X-WRT.COM
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mwan3plus
PKG_VERSION:=3.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Minqiang Chen <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/mwan3plus
   SECTION:=net
   CATEGORY:=Network
   SUBMENU:=Routing and Redirection
   PROVIDES:=mwan3
   DEPENDS:= \
     +ip \
     +ipset \
     +iptables \
     +iptables-mod-conntrack-extra \
     +iptables-mod-ipopt \
     +jshn
   TITLE:=Multiwan hotplug script with connection tracking support
   MAINTAINER:=Minqiang Chen <ptpt52@gmail.com>
   PKGARCH:=all
endef

define Package/mwan3plus/description
Hotplug script which makes configuration of multiple WAN interfaces simple
and manageable. With loadbalancing/failover support for up to 250 wan
interfaces, connection tracking and an easy to manage traffic ruleset.
endef

define Package/mwan3plus/conffiles
/etc/config/mwan3
/etc/mwan3.user
endef

define Build/Compile
endef

define Package/mwan3plus/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/rpcd restart
fi
exit 0
endef

define Package/mwan3plus/postrm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/rpcd restart
fi
exit 0
endef

define Package/mwan3plus/install
$(CP) ./files/* $(1)
endef

$(eval $(call BuildPackage,mwan3plus))
