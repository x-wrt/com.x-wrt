#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=rproxy
PKG_VERSION:=0.0.1
PKG_RELEASE:=e036f26633adc80b864f874a5df52bd3001f0b2c

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/ptpt52/rproxy.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/rproxy
  CATEGORY:=Ptpt52
  SUBMENU:=Mentohust
  TITLE:=rproxy kernel driver
  FILES:=$(PKG_BUILD_DIR)/rproxy.ko
  KCONFIG:=
  DEPENDS:= +kmod-ipt-conntrack
endef

define KernelPackage/rproxy/description
  a kmod to replace user-agent for HTTP flow
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Compile/rproxy
	$(MAKE) $(KERNEL_MAKEOPTS) SUBDIRS="$(PKG_BUILD_DIR)" modules
endef

define Build/Compile
	$(call Build/Compile/rproxy)
endef

$(eval $(call KernelPackage,rproxy))
