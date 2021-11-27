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
PKG_SOURCE_DATE:=2021-11-28
PKG_SOURCE_VERSION:=20211128

PKG_SOURCE_URL:=https://codeload.github.com/ptpt52/linux-exfat-oot/tar.gz/$(PKG_SOURCE_VERSION)?
PKG_HASH:=b2d2232e3ccebb9a580bb5b7ad6e1dc62f9b3ff1686fd0053c8008a065d6a7d6
PKG_SOURCE:=$(PKG_NAME)-$(PKG_SOURCE_DATE)-$(PKG_SOURCE_VERSION).tar.gz

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

TAR_OPTIONS+= --strip-components 1
TAR_CMD=$(HOST_TAR) -C $(1) $(TAR_OPTIONS)

define KernelPackage/exfat-linux
	SECTION:=Applications
	CATEGORY:=X
	SUBMENU:=Filesystems
	TITLE:=ExFAT Kernel driver
	FILES:=$(PKG_BUILD_DIR)/exfat.ko
	AUTOLOAD:=$(call AutoLoad,30,exfat,1)
	DEPENDS:=+kmod-nls-base
	PROVIDES:=kmod-fs-exfat
endef

define KernelPackage/exfat-linux/description
	Kernel module for ExFAT Filesytems
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		CONFIG_EXFAT_FS=m \
		modules
endef

$(eval $(call KernelPackage,exfat-linux))
