#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认WIFI名
# sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

if [[ $WRT_REPO == *"lede"* ]]; then
	CFG_FILE="./package/base-files/luci2/bin/config_generate"
else
	CFG_FILE="./package/base-files/files/bin/config_generate"
fi
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
# sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
#修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" $CFG_FILE
sed -i "/timezone='.*'/a\\\t\t\set system.@system[-1].zonename='Asia/Shanghai'" $CFG_FILE

# if [[ $WRT_REPO == *"lede"* ]]; then
# 	LEDE_FILE=$(find ./package/lean/autocore/ -type f -name "index.htm")
# 	#修改默认时间格式
# 	sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $LEDE_FILE
# 	#添加编译日期标识
# 	#sed -i "s/(\(<%=pcdata(ver.luciversion)%>\))/\1 \/ $WRT_CI-$WRT_DATE/g" $LEDE_FILE
# 	sed -i "s/(\(<%=pcdata(ver.luciversion)%>\))/\1 \@ YICloud Build \~ $author \/ $WRT_DATE/g" $LEDE_FILE
# else
# 	#修改immortalwrt.lan关联IP
# 	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
# 	#添加编译日期标识-
# 	#sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
# 	echo $author
# 	echo $WRT_DATE
# 	sed -i "s/(\(luciversion || ''\))/(\1) + (' \@ YICloud Build \~ $author \/ $WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
# fi

#修改lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识-
#sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
sed -i "s/(\(luciversion || ''\))/(\1) + (' \@ YICloud Build \~ $author \/ $WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

#配置文件修改
# echo "CONFIG_PACKAGE_luci=y" >> ./.config
# echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
# echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
# if [[ $WRT_TARGET == *"IPQ"* ]]; then
if [[ $WRT_TARGET == *"jdc"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
fi
