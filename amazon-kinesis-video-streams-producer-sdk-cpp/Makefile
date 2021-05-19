include $(TOPDIR)/rules.mk

PKG_NAME:=amazon-kinesis-video-streams-producer-sdk-cpp
PKG_RELEASE:=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp.git
PKG_SOURCE_DATE:=2021-05-19
PKG_SOURCE_VERSION:=ade7deadc5e6fb07e152ef23a3d10f3566a403f9
PKG_MIRROR_HASH:=c9410456128e52ddccd7010877ae7f2f8ec507399669cac2e6115e7525561abb
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_PARALLEL:=1
#PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/amazon-kinesis-video-streams-producer-sdk-cpp
  CATEGORY:=X
  SUBMENU:=aws
  DEPENDS:=+libstdcpp +libopenssl +libcurl +log4cplus \
	   +glib2 \
	   +libgst1app \
	   +gstreamer1-utils \
	   +gstreamer1-libs +@gstreamer1-all \
#	   +gstreamer1-plugins-base +@gst1-plugins-base-all \
#	   +gstreamer1-plugins-bad +@gst1-plugins-bad-all \
#	   +gstreamer1-plugins-good +@gst1-plugins-good-all \
#	   +gstreamer1-plugins-ugly +@gst1-plugins-ugly-all

  TITLE:=Amazon Kinesis Video Streams CPP Producer, GStreamer Plugin and JNI
endef

define Package/amazon-kinesis-video-streams-producer-sdk-cpp/description
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

define Package/amazon-kinesis-video-streams-producer-sdk-cpp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvs_gstreamer_audio_video_sample $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvs_gstreamer_file_uploader_sample $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvs_gstreamer_multistream_sample $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kvs_gstreamer_sample $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/dependency/libkvscproducer/kvscproducer-src/libcproducer.so $(1)/usr/lib/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/libKinesisVideoProducer.so $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/gstreamer-1.0
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/libgstkvssink.so $(1)/usr/lib/gstreamer-1.0/
endef

$(eval $(call BuildPackage,amazon-kinesis-video-streams-producer-sdk-cpp))
