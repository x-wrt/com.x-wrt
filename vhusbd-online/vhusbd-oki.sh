#!/bin/sh

url=https://raw.githubusercontent.com/x-wrt/com.x-wrt/refs/heads/master/vhusbd-online/files

echo download vhusbd.conf and install to /etc/vhusbd.conf
wget --no-check-certificate $url/vhusbd.conf -O /etc/vhusbd.conf

echo download vhusbd.config and install to /etc/config/vhusbd
wget --no-check-certificate $url/vhusbd.config -O /etc/config/vhusbd
echo enable vhusbd
uci set vhusbd.config.enabled='1' && uci commit vhusbd

echo download vhusbd.init and install to /etc/init.d/vhusbd
wget --no-check-certificate $url/vhusbd.init -O /etc/init.d/vhusbd
chmod +x /etc/init.d/vhusbd

echo download vhusbd-online.sh and install to /usr/bin/vhusbd-online
wget --no-check-certificate $url/vhusbd-online.sh -O /usr/bin/vhusbd-online
chmod +x /usr/bin/vhusbd-online

echo exec /usr/bin/vhusbd-online
sh -x /usr/bin/vhusbd-online



