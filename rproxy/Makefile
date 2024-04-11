#
# Copyright (C) 2017-2019 Chen Minqiang <ptpt52@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=rproxy
PKG_VERSION:=20240411

PKG_SOURCE_URL:=https://codeload.github.com/ptpt52/rproxy/tar.gz/$(PKG_VERSION)?
PKG_HASH:=b23395ae80a8c608f85fac7ae44d1e01855146a8b9a45f686ea5eac50b3e033a
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

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
