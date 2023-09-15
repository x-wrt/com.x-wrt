#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qmi-wwan-q
PKG_VERSION:=20230915

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0-only
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qmi-wwan-q
  CATEGORY:=X
  TITLE:=QMI WWAN QMAP driver
  FILES:=$(PKG_BUILD_DIR)/qmi_wwan_q.ko
  #AUTOLOAD:=$(call AutoProbe,qmi_wwan_q)
  DEPENDS:=+kmod-usb-net-qmi-wwan
endef

define KernelPackage/qmi-wwan-q/description
  QMI WWAN QMAP driver for Qualcomm MSM based 3G and LTE modems.
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(PKG_EXTRA_KCONFIG) \
	modules
endef

$(eval $(call KernelPackage,qmi-wwan-q))
