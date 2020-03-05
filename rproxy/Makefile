#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=rproxy
PKG_VERSION:=0.0.1
PKG_RELEASE:=31154aa7f507d5a5e816748caeece602da80d348

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/ptpt52/rproxy.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/rproxy
  CATEGORY:=X
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
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		modules
endef

define Build/Compile
	$(call Build/Compile/rproxy)
endef

$(eval $(call KernelPackage,rproxy))
