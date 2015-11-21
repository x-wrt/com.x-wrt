#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=natcap
PKG_VERSION:=2.0.1
PKG_RELEASE:=$(PKG_SOURCE_VERSION)

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://dl.dropboxusercontent.com/u/2146530/git/natcap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=88c1a530d5dc21731b1076a5d579ce481264df95
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/natcap
  CATEGORY:=Ptpt52
  SUBMENU:=Natcap Support
  TITLE:=Natcap kernel driver
  FILES:=$(PKG_BUILD_DIR)/natcap.ko
  AUTOLOAD:=$(call AutoProbe,natcap)
  KCONFIG:=
  DEPENDS:=+kmod-nf-conntrack +kmod-nf-nat
endef

define KernelPackage/natcap/description
  Driver for natcap packet proxy to avoid inspection
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

#define Build/Prepare
#	$(call Build/Prepare/Default)
#	$(CP) ./* $(PKG_BUILD_DIR)/
#endef

MAKE_KMOD := $(MAKE) -C "$(LINUX_DIR)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		PATH="$(TARGET_PATH)" \
		SUBDIRS="$(PKG_BUILD_DIR)" \

define Build/Compile
	# Compile the kernel part
	$(MAKE_KMOD) \
		MODFLAGS="-DMODULE" \
		modules
	pwd
endef

$(eval $(call KernelPackage,natcap))
