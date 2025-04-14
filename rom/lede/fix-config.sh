cat .config | grep "CONFIG_DEFAULT.*=y" | sed 's/CONFIG_DEFAULT_//;s/=y//' | while read w; do
	case "$w" in
		"dnsmasq")
		sed -i "s/CONFIG_PACKAGE_${w}=m/# CONFIG_PACKAGE_${w} is not set/" .config
		continue
		;;
	esac
	sed -i "s/${w}=m/${w}=y/" .config
done


#fixup missing apk
if grep -q 'CONFIG_PACKAGE_opkg=y' .config; then
	:
else
	sed -i "s/CONFIG_PACKAGE_apk-mbedtls=m/CONFIG_PACKAGE_apk-mbedtls=y/" .config
fi
