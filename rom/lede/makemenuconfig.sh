#!/bin/sh

CFGS="config.apm821xx_nand config.kirkwood-generic config.ipq806x-generic config.bcm53xx-generic config.ar71xx-generic config.ar71xx-nand config.mvebu-generic config.ramips-mt7620 config.ramips-mt7621"

VERN=`date +%Y%m%d%H%M`

find target/linux/ feeds/luci/ feeds/packages/ package/ -name Makefile -exec touch {} \;

for cfg in $CFGS; do
	cp feeds/ptpt52/rom/lede/$cfg .config
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"3.0.0_build$VERN\"/" ./.config
	make menuconfig && cp .config feeds/ptpt52/rom/lede/$cfg
done
