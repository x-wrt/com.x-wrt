# This repository is no longer maintained original repo https://github.com/Gr4ffy/lede-cups.git

# How to install Cups on OpenWrt/LEDE
https://github.com/TheMMcOfficial/cups-for-openwrt

# How to compile the Packages
git clone https://github.com/lede-project/source

cd source

echo "src-git cups https://github.com/TheMMcOfficial/lede-cups.git" >> feeds.conf.default

./scripts/feeds update -a

./scripts/feeds install -a

make menuconfig (set Network->Printing->cups as "M")

make

copy /source/bin/packages/[PLATFORM]/cups/*.ipk to machine & opkg install 

# Version of cups
2.3.0
