#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"
# PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#修补命令统一入口：FIX <名称> <守卫路径> <命令...>
#守卫文件或目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -e "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

# #修改argon主题字体和颜色
# #修改 Argon 透明度
# FIX "theme-argon-config" \
# 	"$PACKAGE_PATH/luci-theme-argon" \
# 	sed -i "s/'0.2'/'0.3'/" \
# 	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

# #修改 Argon CSS 字重
# FIX "theme-argon-font" \
# 	"$PACKAGE_PATH/luci-theme-argon/luci-theme-argon" \
# 	find "$PACKAGE_PATH/luci-theme-argon/luci-theme-argon" \
# 	-type f -iname "*.css" \
# 	-exec sed -i \
# 	'/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }' \
# 	{} +

# #修改aurora菜单式样
# FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
# 	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
# 	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

# #修改vantage进度条标签字体（anothaDev/luci-theme-vantage#52）
# FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
# 	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
# 	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

# #修改qca-nss-pbuf启动顺序
# NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
# if [ -f "$NSS_PBUF" ]; then
# 	echo " "

# 	sed -i 's/START=.*/START=86/g' $NSS_PBUF

# 	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
# fi

# 保留 luci-app-tailscale 提供的配置和启动脚本，
# 移除 tailscale 核心包中的重复安装命令
TS_FILE="$FEEDS_PATH/packages/net/tailscale/Makefile"

if [ -f "$TS_FILE" ]; then
	sed -i \
		-e '/tailscale\.init.*\/etc\/init\.d\/tailscale/d' \
		-e '/tailscale\.conf.*\/etc\/config\/tailscale/d' \
		"$TS_FILE"

	echo "tailscale file conflict fixed!"
fi


# #修复Rust编译失败
# RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
# if [ -f "$RUST_FILE" ]; then
# 	echo " "

# 	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

# 	cd $PKG_PATH && echo "rust has been fixed!"
# fi

# #修复DiskMan编译失败
# DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
# if [ -f "$DM_FILE" ]; then
# 	echo " "

# 	sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
# 	sed -i '/ntfs-3g-utils /d' $DM_FILE

# 	cd $PKG_PATH && echo "diskman has been fixed!"
# fi

# #移除sb内核回溯移植补丁
# SB_PATCH="$GITHUB_WORKSPACE/wrt/feeds/packages/net/sing-box/patches"
# if [ -d "$SB_PATCH" ]; then
# 	echo " "

# 	rm -rf $SB_PATCH

# 	cd $PKG_PATH && echo "sing-box patches has been fixed!"
# fi

# 替换为 Go 1.27
cd "$GITHUB_WORKSPACE/wrt/"
rm -rf feeds/packages/lang/golang
git clone --depth=1 --branch 27.x \
	https://github.com/sbwml/packages_lang_golang \
	feeds/packages/lang/golang

# 修正依赖目标名称
find feeds/packages -type f -name Makefile -exec \
	sed -i 's|golang1\.27/host|golang/host|g' {} +

echo "golang update done!"
