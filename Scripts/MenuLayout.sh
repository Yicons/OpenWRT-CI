#!/bin/bash
# SPDX-License-Identifier: MIT

# 集中管理 LuCI 菜单归类、一级菜单和显示顺序。
FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"
PATCH_DIR="$GITHUB_WORKSPACE/Patch"

# FIX <名称> <守卫路径> <命令...>
# 文件或目录不存在时跳过；修改失败时记录错误但不打断其他菜单调整。
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

# MOVE_MENU <名称> <JSON菜单文件> <原父路径> <目标父路径>
# 只替换 JSON 菜单键中的 admin 路径，避免误改标题或其他配置。
MOVE_MENU() {
	local NAME=$1
	local FILE=$2
	local FROM=$3
	local TO=$4

	FIX "menu-$NAME" "$FILE" sed -i \
		"s|\"$FROM/|\"$TO/|g" "$FILE"
}

# REPLACE_APP_PATHS <名称> <查找目录> <包目录名> <原内容> <目标内容> <相对文件...>
# 用于仍采用 Lua controller/model/view 的旧版 LuCI 应用。
REPLACE_APP_PATHS() {
	local NAME=$1
	local FIND_DIR=$2
	local APP_NAME=$3
	local FROM=$4
	local TO=$5
	shift 5

	local RELATIVE_PATH FULL_PATH
	for RELATIVE_PATH in "$@"; do
		FULL_PATH=$(find "$FIND_DIR" -type f -path "*/$APP_NAME/$RELATIVE_PATH" -print -quit 2>/dev/null)
		FIX "menu-$NAME" "$FULL_PATH" sed -i "s|$FROM|$TO|g" "$FULL_PATH"
	done
}

echo -e "\nMenu layout start!"

# 现代 JSON 菜单
MOVE_MENU "mini-diskmanager" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json" \
	"admin/services" "admin/system"

MOVE_MENU "natmapt" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json" \
	"admin/network" "admin/services"

TTYD_MENU="$FEEDS_PATH/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json"
MOVE_MENU "ttyd" "$TTYD_MENU" "admin/services" "admin/system"
FIX "menu-order-ttyd" "$TTYD_MENU" sed -i \
	'/"admin\/system\/ttyd": {/,/^[[:blank:]]},$/ { /"order":/d; /"title":/a\
		"order": 50,
	}' "$TTYD_MENU"

MOVE_MENU "tailscale" \
	"$PACKAGE_PATH/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json" \
	"admin/services" "admin/vpn"

# 部分源码才需要独立的 NAS 分类。
if [[ $WRT_REPO == *"lede"* || $WRT_REPO == *"openwrt/openwrt"* ]]; then
	MOVE_MENU "samba4" \
		"$FEEDS_PATH/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json" \
		"admin/services" "admin/nas"
fi

# wolultra 自带一个“管控”一级菜单；移动页面后同时删除空的一级菜单定义。
WOLULTRA_MENU="$PACKAGE_PATH/luci-app-wolultra/root/usr/share/luci/menu.d/luci-app-wolultra.json"
FIX "menu-wolultra" "$WOLULTRA_MENU" sed -i \
	-e '/^[[:blank:]]"admin\/control": {$/,/^[[:blank:]]},$/d' \
	-e 's|"admin/control/wolultra"|"admin/services/wolultra"|' \
	"$WOLULTRA_MENU"

# 旧版 Lua 菜单
REPLACE_APP_PATHS "openappfilter" "package" "luci-app-oaf" "services" "network" \
	"luasrc/controller/appfilter.lua" \
	"luasrc/model/cbi/appfilter/dev_status.lua" \
	"luasrc/view/admin_network/app_filter.htm"

REPLACE_APP_PATHS "socat" "package" "luci-app-socat" "network" "services" \
	"luasrc/controller/socat.lua" \
	"luasrc/model/cbi/socat/index.lua" \
	"luasrc/model/cbi/socat/config.lua" \
	"luasrc/view/socat/list_status.htm"

# OpenWrt 官方源码：新增 NAS 一级菜单并统一 Services/NAS/VPN/Network 顺序。
if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	BASE_MENU_PATCH="$PATCH_DIR/luci-base/001-luci-base-change-order-add-nas.patch"
	FIX "base-menu-layout" "$BASE_MENU_PATCH" sh -c \
		'patch -p1 --batch --forward < "$1"' sh "$BASE_MENU_PATCH"
fi

echo "Menu layout done!"
