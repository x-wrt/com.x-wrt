#!/bin/sh

usbprint="kmod-usb-printer \
		  p910nd \
		  luci-app-p910nd \
		  luci-i18n-p910nd-en \
		  luci-i18n-p910nd-zh-cn"

usb2="kmod-usb2 \
	  kmod-usb-core \
	  kmod-usb-ohci \
	  kmod-usb-storage \
	  kmod-usb-storage-uas \
	  kmod-scsi-core \
	  kmod-crypto-crc32c \
	  kmod-nls-cp437 \
	  kmod-lib-crc16 \
	  kmod-fs-autofs4 \
	  kmod-fs-exfat \
	  kmod-fs-ext4 \
	  kmod-fs-msdos \
	  kmod-fuse \
	  kmod-fs-vfat \
	  block-mount \
	  blockd \
	  ntfs-3g"

usb3="kmod-usb3 \
	  kmod-usb-core \
	  kmod-usb-ohci \
	  kmod-usb-storage \
	  kmod-usb-storage-uas \
	  kmod-scsi-core \
	  kmod-crypto-crc32c \
	  kmod-nls-cp437 \
	  kmod-lib-crc16 \
	  kmod-fs-autofs4 \
	  kmod-fs-exfat \
	  kmod-fs-ext4 \
	  kmod-fs-msdos \
	  kmod-fuse \
	  kmod-fs-vfat \
	  block-mount \
	  blockd \
	  ntfs-3g"
moreapps="libstdcpp \
		  libsqlite3 \
		  libssh2 \
		  libxml2 \
		  luci-app-aria2 \
		  luci-app-samba \
		  luci-i18n-aria2-zh-cn \
		  luci-i18n-samba-en \
		  luci-i18n-samba-zh-cn \
		  webui-aria2 \
		  aria2 \
		  openssl-util \
		  samba36-server"
excludes=""

get_modules()
{
	local m
	m=`for i in $@; do echo $i; done | sort | uniq`
	m=`echo $m`
	echo $m
}

get_modules_only()
{
	local m
	m=`for i in $@; do grep -q "CONFIG_PACKAGE_$i=m" .config && echo $i; done`
	m=`echo $m`
	echo $m
}

exclude_modules()
{
	local m
	m=`for i in $@ $excludes $excludes; do echo $i; done | sort | uniq -c | grep ' 1' | awk '{print $2}' | sort`
	m=`echo $m`
	echo $m
}

rm -rf /tmp/config_lede
mkdir /tmp/config_lede
cat .config | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | while read target; do
	cat tmp/.config-target.in | grep "menuconfig $target" -A200 | while read line; do
		test -n "$line" || break
		echo $line | grep -q 'select MODULE_DEFAULT' && {
			echo $line | awk '{print $2}' | sed 's/MODULE_DEFAULT_//'
		}
	done | sort >/tmp/config_lede/$target
done

targets=`cd /tmp/config_lede && ls`
alls=`cat /tmp/config_lede/* 2>/dev/null | sort | uniq`
#echo $alls

is_in_set()
{
	_i=$1
	_s=$2
	for l in `cat $_s`; do
		[ x$l = x$_i ] && return 0
	done
	return 1
}

uniqs=$(for p in $alls; do
	for t in $targets; do
		is_in_set $p /tmp/config_lede/$t || {
			echo $p
			break
		}
	done
done | sort | uniq)

echo uniqs=$uniqs

ms="`cat .config | grep =m$ | sed 's/CONFIG_PACKAGE_//;s/=m//g'`"
ms=$(for i in $ms; do
	[ xdnsmasq = x$i ] && continue
	[ xodhcpd = x$i ] && continue
	echo $i
done)
modules=$(for i in $ms; do
	echo "$uniqs" | grep -q $i$ || echo $i
done)
echo modules=$modules

get_target_mods()
{
	local addms_tmp
	local addms
	addms_tmp=$(cat tmp/.config-feeds.in tmp/.config-target.in tmp/.config-package.in | grep "config $1$" -A80 | while read line; do
		test -n "$line" || break
		echo $line | grep "select MODULE_DEFAULT_" | awk '{print $2}' | grep MODULE_DEFAULT_ | sed 's/MODULE_DEFAULT_//'
	done)
	addms=""
	for m in $addms_tmp; do
		for i in $modules; do
			[ x$m = x$i ] && addms="$addms $m"
		done
	done
	echo $addms
}

get_deps()
{
	local addms_tmp
	local addms
	local addm
	addms_tmp=$(cat tmp/.config-feeds.in tmp/.config-target.in tmp/.config-package.in | grep "config PACKAGE_$1$" -A40 | while read line; do
		test -n "$line" || break
		echo $line | grep "select PACKAGE_" | awk '{print $2}' | grep PACKAGE_ | sed 's/PACKAGE_//'
		echo $line | grep "depends on PACKAGE_" | awk '{print $3}' | grep PACKAGE_ | sed 's/PACKAGE_//'
	done)
	addms=""
	for m in $addms_tmp; do
		for i in $modules; do
			[ x$m = x$i ] && addms="$addms $m"
		done
	done
	for m in $addms; do
		addm=`get_deps $m`
		test -n "$addm" && addms="$addms $addm"
	done
	addms_tmp="$addms"
	addms=""
	for m in $addms_tmp; do
		for i in $modules; do
			[ x$m = x$i ] && addms="$addms $m"
		done
	done
	echo $addms
}

for t in $targets; do
	us=$(for u in $uniqs; do
		is_in_set $u /tmp/config_lede/$t && echo $u
	done)
	echo $t=`get_modules $us`
	mods="$us"
	case $t in
		#>8M flash
		TARGET_DEVICE_ramips_mt7620_DEVICE_oy-0001|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c5-v1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_puppies|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-we3526|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AC9531_010|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AC9531_020|\
		TARGET_DEVICE_ramips_mt7620nand_DEVICE_miwifi-r3|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_miwifi-r3|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we826-32M|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we826-16M|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_we1026-5g-16m|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c59-v1|\
		TARGET_DEVICE_ipq806x_DEVICE_NBG6817|\
		TARGET_DEVICE_ipq806x_DEVICE_FRITZ4040|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_miwifi-mini|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r6250|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_mir3g|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v4|\
		TARGET_DEVICE_kirkwood_DEVICE_on100|\
		TARGET_DEVICE_kirkwood_DEVICE_linksys-audi|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_hc5661a|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_F9K1115V2|\
		TARGET_DEVICE_ipq806x_DEVICE_AP-DK04.1-C1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_DGL5500A1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_gl-inet-6416A-v1|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_asus-rt-n16|\
		TARGET_DEVICE_oxnas_DEVICE_pogoplug-pro|\
		TARGET_DEVICE_oxnas_DEVICE_pogoplug-v3|\
		TARGET_DEVICE_kirkwood_DEVICE_pogo_e02|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_linksys-e3200-v1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-we1326|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg2626|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg3526-16M|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg3526-32M|\
		TARGET_DEVICE_ipq806x_DEVICE_EA8500|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_wsr-1166|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_domywifi-dw33d|\
		TARGET_DEVICE_ipq806x_DEVICE_R7800|\
		TARGET_DEVICE_ipq806x_DEVICE_R7500v2|\
		TARGET_DEVICE_ipq806x_DEVICE_R7500|\
		TARGET_DEVICE_ipq806x_DEVICE_D7800|\
		TARGET_DEVICE_kirkwood_DEVICE_linksys-viper|\
		TARGET_DEVICE_apm821xx_nand_DEVICE_WNDR4700|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_hiwifi-hc6361|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3700v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3800|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3800ch|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_qihoo-c301|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_R6100|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_WNDR3700V4|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_WNDR4300V1|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac56u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac68u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac87u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-n18u|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r6300-v2|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r7000|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r7900|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r8000|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1200ac|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900ac|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900acs|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900acv2|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt3200acm|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5661|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5761|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5861|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_y1|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_y1s|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_youku-yk1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_hc5962|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220b|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220a|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_wndr3700v5|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_newifi-d1)
			mods="$mods $moreapps $usbprint"
		;;
		#<=8M flash
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr6500-v7|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c25-v1|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_wcr-1166ds|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_whr-1166d|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr902ac-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c58-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c60-v1|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we2026|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_tl-wr841n-v13|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_tl-wr840n-v4|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v3|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v1|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_mac1200r-v2|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_k2p|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr7500-v3|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v4|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP152_16M|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP147_010|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP143_8M|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP143_16M|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_miwifi-nano|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-wrt610n-v2|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-wrt610n-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_gl-inet-6408A-v1|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-e3000-v1|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_netgear-wndr3700-v3|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_mw4530r-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_mc-mac1200r|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_re6500|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr6500-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4900-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4310-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4300-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr3600-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr3500-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3700|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_WNR2200|\
		TARGET_DEVICE_bcm53xx_DEVICE_tenda-ac9|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-wr8305rt|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1208|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1218a|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1218b)
			mods="$mods"
		;;
		*)
			echo not handle moreapps $t
		;;
	esac
	#check usb
	case $t in
		#with usb3
		TARGET_DEVICE_ipq806x_DEVICE_NBG6817|\
		TARGET_DEVICE_ipq806x_DEVICE_FRITZ4040|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r6250|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_mir3g|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_F9K1115V2|\
		TARGET_DEVICE_ipq806x_DEVICE_AP-DK04.1-C1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-we1326|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg2626|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg3526-16M|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-wg3526-32M|\
		TARGET_DEVICE_ipq806x_DEVICE_EA8500|\
		TARGET_DEVICE_ipq806x_DEVICE_R7800|\
		TARGET_DEVICE_ipq806x_DEVICE_R7500v2|\
		TARGET_DEVICE_ipq806x_DEVICE_R7500|\
		TARGET_DEVICE_ipq806x_DEVICE_D7800|\
		TARGET_DEVICE_kirkwood_DEVICE_linksys-viper|\
		TARGET_DEVICE_apm821xx_nand_DEVICE_WNDR4700|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac56u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac68u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-ac87u|\
		TARGET_DEVICE_bcm53xx_DEVICE_asus-rt-n18u|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r6300-v2|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r7000|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r7900|\
		TARGET_DEVICE_bcm53xx_DEVICE_netgear-r8000|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1200ac|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900ac|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900acs|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt1900acv2|\
		TARGET_DEVICE_mvebu_DEVICE_linksys-wrt3200acm|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_y1s|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_youku-yk1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_hc5962|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_wndr3700v5|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_newifi-d1)
			mods="$mods $usb2 $usb3"
		;;
		#with usb2
		TARGET_DEVICE_ramips_mt7620_DEVICE_oy-0001|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c5-v1|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_puppies|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_zbt-we3526|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AC9531_010|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AC9531_020|\
		TARGET_DEVICE_ramips_mt7620nand_DEVICE_miwifi-r3|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_miwifi-r3|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we826-32M|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we826-16M|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_we1026-5g-16m|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr902ac-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c59-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v4|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v3|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v2|\
		TARGET_DEVICE_kirkwood_DEVICE_on100|\
		TARGET_DEVICE_kirkwood_DEVICE_linksys-audi|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr7500-v3|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c7-v4|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_hc5661a|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-wrt610n-v2|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-wrt610n-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_DGL5500A1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_gl-inet-6416A-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_gl-inet-6408A-v1|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_asus-rt-n16|\
		TARGET_DEVICE_oxnas_DEVICE_pogoplug-pro|\
		TARGET_DEVICE_oxnas_DEVICE_pogoplug-v3|\
		TARGET_DEVICE_kirkwood_DEVICE_pogo_e02|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_netgear-wndr3700-v3|\
		TARGET_DEVICE_brcm47xx_mips74k_DEVICE_linksys-e3200-v1|\
		TARGET_DEVICE_brcm47xx_generic_DEVICE_linksys-e3000-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP152_16M|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP147_010|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP143_8M|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_AP143_16M|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220b|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220a|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_r6220|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_wsr-1166|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_domywifi-dw33d|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_mw4530r-v1|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_WNDR4300V1|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_WNDR3700V4|\
		TARGET_DEVICE_ar71xx_nand_DEVICE_R6100|\
		TARGET_DEVICE_bcm53xx_DEVICE_tenda-ac9|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_WNR2200|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3800ch|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3800|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3700v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_wndr3700|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr6500-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4900-v2|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4310-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr4300-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr3600-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr3500-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_qihoo-c301|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_hiwifi-hc6361|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5661|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5761|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_hc5861|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_y1|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_miwifi-mini|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-wr8305rt)
			mods="$mods $usb2"
		;;
		#no usb
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wdr6500-v7|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c25-v1|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_wcr-1166ds|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_whr-1166d|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c58-v1|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_archer-c60-v1|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_zbt-we2026|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_tl-wr841n-v13|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_tl-wr840n-v4|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_tl-wr1043nd-v1|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_mac1200r-v2|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_k2p|\
		TARGET_DEVICE_ramips_mt76x8_DEVICE_miwifi-nano|\
		TARGET_DEVICE_ar71xx_generic_DEVICE_mc-mac1200r|\
		TARGET_DEVICE_ramips_mt7621_DEVICE_re6500|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1208|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1218a|\
		TARGET_DEVICE_ramips_mt7620_DEVICE_psg1218b)
			mods="$mods"
		;;
		*)
			echo no handle usb $t
		;;
	esac
	tname=`echo $t | sed 's/TARGET_DEVICE_/CONFIG_TARGET_DEVICE_PACKAGES_/'`
	mods="$mods `get_target_mods $t`"
	mods=`get_modules $mods`
	dep_mods=$(for x in $mods; do
			get_deps $x
			done)
	dep_mods=`get_modules $dep_mods`
	mods=`get_modules $mods $dep_mods`
	mods=`exclude_modules $mods`
	mods=`get_modules_only $mods`
	#echo $tname=$mods
	sed -i "s/$tname=\".*\"/$tname=\"$mods\"/" ./.config
done

rm -rf /tmp/config_lede

#======================
