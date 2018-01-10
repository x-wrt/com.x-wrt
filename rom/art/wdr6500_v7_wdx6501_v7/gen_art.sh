#!/bin/bash

gen_art_func()
{
	echo -ne "\x48\x7d\x2e\xcb\x32\x51"
	dd if=art.orig.img bs=1 skip=6 count=$((4096-6+2)) 2>/dev/null
	echo -ne "\x48\x7d\x2e\xcb\x32\x52"
	dd if=art.orig.img bs=1 skip=$((4096+2+6)) count=$((20480-4096-2-6+6)) 2>/dev/null
	echo -ne "\x48\x7d\x2e\xcb\x32\x53"
	dd if=art.orig.img bs=1 skip=$((20480+6+6)) 2>/dev/null
}

rm -f out.img
touch out.img
gen_art_func >out.img
set -x
mv out.img tl-wdx6501-art.img
echo creating tl-wdx6501-art.img
set +x
