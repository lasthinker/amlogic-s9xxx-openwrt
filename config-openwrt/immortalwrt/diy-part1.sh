#!/bin/bash
#========================================================================================================================
# https://github.com/lasthinker/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt for Amlogic
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: openwrt-21.02
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default

# other
# rm -rf package/emortal/{autosamba,ipv6-helper}

