#!/bin/sh

CFGS=${CFGS-"`cat feeds/x/rom/lede/cfg.list`"}

bins="`find bin/targets/ | grep -- '\(-ext4-sdcard\|-squashfs\|-factory\|-sysupgrade\)' | grep "natcap\|x-wrt" | grep -v vmlinux | grep -v '\.dtb$' | while read line; do basename $line; done`"

sha256sums="`find bin/targets/ -type f -name sha256sums`"
sha256sums=`cat $sha256sums`

targets=$(cd feeds/x/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | sort)

echo -n >sha256sums.txt
echo -n >map.list

echo sha256sums: sha256sums.txt >>map.list

x86bin="`find bin/targets/ | grep -- '\(-combined\|-uefi\|combined-efi\)' | sort | while read line; do basename $line; done`"
test -n "$x86bin" && {
	echo x86_64 or x86:
	echo "$x86bin"
	echo
	x86_64_combined=
	x86_64_uefi=
	x86_generic_combined=
	x86_generic_uefi=
	for bin in $x86bin; do
		echo "$sha256sums" | grep "$bin" >>sha256sums.txt
		case $bin in
			*x86-64-combined*|*x86-64-generic-ext4-combined\.*)
				x86_64_combined="${x86_64_combined} $bin"
			;;
			*x86-64-uefi*|*x86-64-generic-ext4-combined-efi\.*)
				x86_64_uefi="${x86_64_uefi} $bin"
			;;
			*x86-generic-combined*|*x86-generic-generic-ext4-combined\.*)
				x86_generic_combined="${x86_generic_combined} $bin"
			;;
			*x86-generic-uefi*|*x86-generic-generic-ext4-combined-efi\.*)
				x86_generic_uefi="${x86_generic_uefi} $bin"
			;;
			*)
				echo "x86_64 or x86:$bin" >>map.list
			;;
		esac
	done

	test -n "${x86_64_combined}" && echo "x86 64bits (MBR dos):`echo -n ${x86_64_combined}`" >>map.list
	test -n "${x86_64_uefi}" && echo "x86 64bits (UEFI gpt):`echo -n ${x86_64_uefi}`" >>map.list
	test -n "${x86_generic_combined}" && echo "x86 generic (MBR dos):`echo -n ${x86_generic_combined}`" >>map.list
	test -n "${x86_generic_uefi}" && echo "x86 generic (UEFI gpt):`echo -n ${x86_generic_uefi}`" >>map.list
}

for t in $targets; do
	tt=`echo $t | sed 's/_DEVICE_/:/g'`
	name=`echo $tt | cut -d: -f3`
	echo $tt | cut -d: -f2 | sed 's/_/ /' | while read arch subarch; do
		test -n "$arch" || continue
		dis=`cat tmp/.targetinfo | grep "Target-Profile: DEVICE_$name$" -A1 | grep "Target-Profile-Name: " | sed 's/Target-Profile-Name: //'`
		#dis=`cat tmp/.config-target.in | grep "^config.*_DEVICE_$name$" -A1 | grep "bool .*" | cut -d\" -f2`
		test -n "$dis" || {
##################################
		text=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$name$" -A50 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
		dis=`echo "$text" | grep "DEVICE_TITLE.*:=" | head -n1 | sed 's/DEVICE_TITLE.*:=//'`
		test -n "$dis" || {
			MODEL=`echo "$text" | grep -o '$(call Device/.*,.*)$' | head -n1 | cut -d, -f2 | sed 's/)$//g'`
			test -n "$MODEL" && {
				SUBDEF=`echo "$text" | grep -o '$(call Device/.*,.*)$' | head -n1 | cut -d, -f1 | sed 's,$(call Device/,,g'`
				text1=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$SUBDEF$" -A50 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
				VENDOR=`echo "$text1" | grep -o "DEVICE_TITLE.*:=.*" | head -n1 | sed 's/DEVICE_TITLE.*:=//' | awk '{print $1}'`
				test -n "$VENDOR" && dis="$VENDOR $MODEL"
			}
		}
		test -n "$dis" || {
			VENDOR=`echo "$text" | grep "DEVICE_VENDOR.*=" | head -n1 | sed 's/DEVICE_VENDOR.*=//'`
			MODEL=`echo "$text" | grep "DEVICE_MODEL.*=" | head -n1 | sed 's/DEVICE_MODEL.*=//'`
			VARIANT=`echo "$text" | grep "DEVICE_VARIANT.*=" | head -n1 | sed 's/DEVICE_VARIANT.*=//'`
			test -n "$MODEL" && dis="$MODEL"
			test -n "$VARIANT" && dis="$dis $VARIANT"
			if test -n "$VENDOR"; then
				dis="$VENDOR $dis"
			else
				#get VENDOR
				while :; do
				SUBDEF=`echo "$text" | grep '$(Device/' | head -n1 | sed 's,$(Device/,,;s/)$//'`
				text1=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$SUBDEF$" -A50 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
				VENDOR=`echo "$text1" | grep "DEVICE_VENDOR.*=" | head -n1 | sed 's/DEVICE_VENDOR.*=//'`
				if test -n "$VENDOR"; then
					dis="$VENDOR $dis"
				else
					#get VENDOR
					text="$text1"
				fi
				test -n "$VENDOR" && break
				test -n "$text" || {
					echo no VENDOR found
					exit 1
					break
				}
				done
			fi
		}
##################################
		}
		bin=`echo "$bins" | grep $arch | grep -i "\($name-ex\|$name-sq\|$name-fa\|$name-ub\|$name-ue\|$name-in\)"`
		test -n "$bin" || {
			name=`echo $name | tr _ -`
			bin=`echo "$bins" | grep -i "\($name-ex\|$name-sq\|$name-fa\|$name-ub\|$name-ue\|$name-in\)"`
			test -n "$bin" || {
				bin=$(echo "$bins" | grep -i "`echo $name | head -c5`" | grep $arch)
				test -n "$bin" || {
					bin=$(echo "$bins" | grep -i "`echo $name | head -c3`" | grep $arch)
				}
			}
		}

		test -n "$bin" || {
			echo no image found for "$dis"
			exit 255
		}

		echo "`echo $dis`:"
		for i in $bin; do
			echo $i;
			echo "$sha256sums" | grep "$i" >>sha256sums.txt
		done
		echo
		echo "`echo $dis`:"$bin >>map.list
	done
done | while read line; do echo $line; done

find bin/targets/ | grep -q -- -sdk- || {
	echo no sdk build.
	exit 0
}
find bin/targets/ | grep -- -sdk- | while read s; do basename $s; done | sort >sdk_map.list
find bin/targets/ | grep -- -sdk- >sdk_upload.list
echo -n >sdk_sha256sums.txt
cat sdk_map.list | while read bin; do
	echo "$sha256sums" | grep "$bin" >>sdk_sha256sums.txt
done
