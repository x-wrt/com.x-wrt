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

PKG_SOURCE_URL:=https://github.com/ptpt52/exfat-linux.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2020-04-05
PKG_SOURCE_VERSION:=8c63f89809c48c7fa102d52cb424f52b856d20a2

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
	DEPENDS:=+kmod-nls-base @!LINUX_5_4
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
