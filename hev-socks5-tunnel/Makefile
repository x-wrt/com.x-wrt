include $(TOPDIR)/rules.mk

PKG_NAME:=hev-socks5-tunnel
PKG_VERSION:=2.5.3
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://github.com/heiher/hev-socks5-tunnel/releases/download/$(PKG_VERSION)
PKG_HASH:=c93ecda229caae2479b814a3d49417e7a8658d0ad8567a9b10146af9c23034ff
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(PKG_SOURCE_SUBDIR)

#PKG_INSTALL:=1
PKG_BUILD_FLAGS:=no-mips16 lto
PKG_BUILD_PARALLEL:=1

PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Chen Minqiang <ptpt52@x-wrt.com>

include $(INCLUDE_DIR)/package.mk

define Package/hev-socks5-tunnel
	CATEGORY:=X
	TITLE:=A tunnel over Socks5 proxy (tun2socks) for Unix.
	URL:=https://github.com/heiher/hev-socks5-tunnel
endef

define Package/hev-socks5-tunnel/description
A tunnel over Socks5 proxy (tun2socks) for Unix.
endef

define Package/hev-socks5-tunnel/conffiles
endef

TARGET_CFLAGS += -O3
TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed

MAKE_FLAGS += ENABLE_STATIC=1

define Package/hev-socks5-tunnel/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/hev-socks5-tunnel $(1)/usr/bin
endef

$(eval $(call BuildPackage,hev-socks5-tunnel))
