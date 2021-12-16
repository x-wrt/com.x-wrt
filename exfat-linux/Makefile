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
PKG_VERSION:=20211216
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://codeload.github.com/ptpt52/linux-exfat-oot/tar.gz/$(PKG_VERSION)?
PKG_HASH:=8e3bbd26f09768b4d6e6f82c45717098973e0b0cf5961e3b71885688da15a9a4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

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
