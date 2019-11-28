#
# Copyright (C) 2014 Bruno Randolf <br1@einfach.org>
# Copyright (C) 2019 Yousong Zhou <yszhou4tech@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=exfat-linux
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://github.com/arter97/exfat-linux.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2019-11-28
PKG_SOURCE_VERSION:=29fdcd25f82439e49d03ed2d5c7d0fd0906f3cb8

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define KernelPackage/exfat-linux
	SECTION:=Applications
	CATEGORY:=X
	SUBMENU:=Filesystems
	TITLE:=ExFAT Kernel driver
	FILES:=$(PKG_BUILD_DIR)/exfat.ko
	AUTOLOAD:=$(call AutoLoad,30,exfat,1)
	DEPENDS:=+kmod-nls-base
endef

define KernelPackage/exfat-linux/description
	Kernel module for ExFAT Filesytems
endef

MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	M="$(PKG_BUILD_DIR)"

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		CONFIG_EXFAT_FS=m \
		modules
endef

$(eval $(call KernelPackage,exfat-linux))
