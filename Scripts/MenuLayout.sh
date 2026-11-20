#!/bin/bash
# 集中管理 LuCI 菜单位置、一级菜单和显示顺序。

PATCH_DIR="$GITHUB_WORKSPACE/Patch"
FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

echo -e "\nApply LuCI menu layout"

move_menu() {
	local NAME=$1 FILE=$2 FROM=$3 TO=$4
	[ -f "$FILE" ] || return 0
	sed -i "s|\"$FROM/|\"$TO/|g" "$FILE"
	echo "Menu adjusted: $NAME ($FROM -> $TO)"
}

replace_app_paths() {
	local NAME=$1 FIND_DIR=$2 APP_NAME=$3 FROM=$4 TO=$5
	shift 5

	local RELATIVE FILE
	for RELATIVE in "$@"; do
		FILE=$(find "$FIND_DIR" -type f \
			-path "*/$APP_NAME/$RELATIVE" -print -quit 2>/dev/null)
		if [ -n "$FILE" ]; then
			sed -i "s|$FROM|$TO|g" "$FILE"
			echo "Menu adjusted: $NAME ($FILE)"
		fi
	done
}

apply_menu_patch() {
	local NAME=$1 FILE=$2
	[ -f "$FILE" ] || { echo "WARNING: menu patch missing, skipped: $NAME ($FILE)"; return 0; }

	if patch -p1 --dry-run --batch --forward < "$FILE" >/dev/null 2>&1; then
		patch -p1 --batch --forward < "$FILE"
		echo "Menu patch applied: $NAME"
	elif patch -p1 --dry-run --batch --reverse < "$FILE" >/dev/null 2>&1; then
		echo "Menu patch already present upstream: $NAME"
	else
		echo "WARNING: menu patch no longer applies, skipped: $NAME"
		return 0
	fi
}

# =============================================================================
# 现代 JSON 菜单：磁盘管理与 NATMapT
# =============================================================================
move_menu "mini-diskmanager" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json" \
	"admin/services" "admin/system"

move_menu "natmapt" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json" \
	"admin/network" "admin/services"

# =============================================================================
# 现代 JSON 菜单：TTyD 位置与显示顺序
# =============================================================================
TTYD_MENU="$FEEDS_PATH/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json"
move_menu "ttyd" "$TTYD_MENU" "admin/services" "admin/system"
if [ -f "$TTYD_MENU" ]; then
	sed -i '/"admin\/system\/ttyd": {/,/^[[:blank:]]},$/ { /"order":/d; /"title":/a\
		"order": 50,
	}' "$TTYD_MENU"
fi

# =============================================================================
# 现代 JSON 菜单：Tailscale 归入 VPN
# =============================================================================
move_menu "tailscale" \
	"$PACKAGE_PATH/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json" \
	"admin/services" "admin/vpn"

# =============================================================================
# NAS 菜单：Samba4 归类、官方 OpenWrt 一级菜单及顺序
# =============================================================================
# OpenWrt/LEDE 使用 NAS 分类；只有官方 OpenWrt 需要新增一级菜单和调整顺序。
if [[ $WRT_REPO == *"openwrt/openwrt"* || $WRT_REPO == *"lede"* ]]; then
	move_menu "samba4" \
		"$FEEDS_PATH/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json" \
		"admin/services" "admin/nas"

	if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
		apply_menu_patch "NAS menu and order" \
			"$PATCH_DIR/luci-base/001-luci-base-change-order-add-nas.patch"
	fi
fi

# =============================================================================
# wolultra：从“管控”移到“服务”，同时删除空的“管控”一级菜单
# =============================================================================
mapfile -t WOLULTRA_MENUS < <(find "$PACKAGE_PATH" -type f \
	-path '*/luci-app-wolultra/root/usr/share/luci/menu.d/luci-app-wolultra.json')
if [ "${#WOLULTRA_MENUS[@]}" -eq 0 ]; then
	echo "WARNING: wolultra menu file not found, skipped"
fi
for WOLULTRA_MENU in "${WOLULTRA_MENUS[@]}"; do
	if ! jq -e '
		if has("admin/control/wolultra") then
		.["admin/services/wolultra"] = .["admin/control/wolultra"]
		| del(.["admin/control/wolultra"], .["admin/control"])
		else error("admin/control/wolultra is missing") end
	' "$WOLULTRA_MENU" > "$WOLULTRA_MENU.tmp"
	then
		rm -f "$WOLULTRA_MENU.tmp"
		echo "WARNING: unable to adjust wolultra menu, skipped: $WOLULTRA_MENU"
		continue
	fi
	mv "$WOLULTRA_MENU.tmp" "$WOLULTRA_MENU"
	echo "Menu adjusted: wolultra (admin/control -> admin/services)"
done

# =============================================================================
# 旧版 Lua 菜单：Socat
# =============================================================================
replace_app_paths "socat" "$PACKAGE_PATH" "luci-app-socat" "network" "services" \
	"luasrc/controller/socat.lua" \
	"luasrc/model/cbi/socat/index.lua" \
	"luasrc/model/cbi/socat/config.lua" \
	"luasrc/view/socat/list_status.htm"

# =============================================================================
# 旧版 Lua 菜单：OpenAppFilter（当前软件未启用，保持注释）
# =============================================================================
# replace_app_paths "openappfilter" "$PACKAGE_PATH" "luci-app-oaf" "services" "network" \
# 	"luasrc/controller/appfilter.lua" \
# 	"luasrc/model/cbi/appfilter/dev_status.lua" \
# 	"luasrc/view/admin_network/app_filter.htm"

echo "LuCI menu layout done"
