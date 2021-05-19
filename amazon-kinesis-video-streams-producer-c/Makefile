include $(TOPDIR)/rules.mk

PKG_NAME:=amazon-kinesis-video-streams-producer-c
PKG_RELEASE:=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=https://github.com/awslabs/amazon-kinesis-video-streams-producer-c.git
PKG_SOURCE_DATE:=2021-05-19
PKG_SOURCE_VERSION:=a8091d1a140fbdcb260ba3c8302aa2e4712d2d91
PKG_MIRROR_HASH:=c2038ab51dd7c0ba7ea4cce7b8ffb476e1d823395c12e1776cbe8284b0ba87b0
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_PARALLEL:=1
#PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/amazon-kinesis-video-streams-producer-c
  CATEGORY:=X
  SUBMENU:=aws
  DEPENDS:=+libopenssl +libcurl
  TITLE:=Amazon Kinesis Video Streams C Producer
endef

define Package/amazon-kinesis-video-streams-producer-c/description
  Amazon Kinesis Video Streams Producer SDK for C/C++ makes it easy to build
  an on-device application that securely connects to a video stream, and reliably
  publishes video and other media data to Kinesis Video Streams. It takes care of
  all the underlying tasks required to package the frames and fragments generated
  by the device's media pipeline. The SDK also handles stream creation, token
  rotation for secure and uninterrupted streaming, processing acknowledgements
  returned by Kinesis Video Streams, and other tasks.
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include -ffunction-sections -fdata-sections

TARGET_LDFLAGS += -Wl,--gc-sections

define Package/amazon-kinesis-video-streams-producer-c/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvsAacAudioVideoStreamingSample $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvsVideoOnlyStreamingSample $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/libcproducer.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,amazon-kinesis-video-streams-producer-c))
