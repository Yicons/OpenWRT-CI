#!/bin/bash
# 个人源码修补层。上游脚本执行完后由 WRT-CORE 调用。

PATCH_DIR="$GITHUB_WORKSPACE/Patch"
FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

echo -e "\nApply custom source overlay"

# Fullcone 按源码分开维护：
# - VIKINGYFY 移除其内置维护副本，直接应用 SONiC 原仓库；
# - ImmortalWrt 使用源码自带的 nft-fullcone；
# - LiBwrt 与官方 OpenWrt 不额外移植 Fullcone。
if [[ $WRT_REPO == *"VIKINGYFY/immortalwrt"* ]]; then
	echo "Replace VIKINGYFY Fullcone integration with upstream SONiC"
	rm -rf \
		package/emortal/luci-app-fullconenat-sonic \
		package/network/utils/fullconenat-sonic
	rm -f \
		package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch \
		package/network/config/firewall/patches/001-sonic-fullcone.patch \
		package/network/config/firewall4/patches/001-sonic-fullcone.patch \
		package/network/config/firewall4/patches/002-default-enable-fullcone.patch \
		package/network/utils/iptables/patches/901-sonic-fullcone.patch \
		package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch \
		package/network/utils/nftables/patches/003-nftables-handle-fullcone-in-json-parser-and-optimizer.patch
	find target/linux/generic -maxdepth 2 -type f \
		\( -name '984-add-sonic-fullcone-support.patch' \
		-o -name '985-add-sonic-fullcone-to-ipt.patch' \
		-o -name '986-add-sonic-fullcone-to-nft.patch' \
		-o -name '987-sonic-fullcone-fix-races-and-drops.patch' \) \
		-delete 2>/dev/null

	SONIC_INSTALLER=$(mktemp)
	if [ -n "$SONIC_INSTALLER" ] && curl -fsSL \
		"https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh" \
		-o "$SONIC_INSTALLER" && bash "$SONIC_INSTALLER"
	then
		echo "Upstream SONiC Fullcone applied"
	else
		echo "WARNING: upstream SONiC Fullcone could not be applied; continuing without Fullcone"
	fi
	rm -f "$SONIC_INSTALLER"
elif [[ $WRT_REPO == *"immortalwrt/immortalwrt"* ]]; then
	echo "CONFIG_PACKAGE_kmod-nft-fullcone=y" >> .config
	echo "ImmortalWrt native nft-fullcone selected"
else
	echo "No custom Fullcone overlay for $WRT_REPO"
fi

apply_patch_checked() {
	local NAME=$1
	local DIR=$2
	local LEVEL=$3
	local FILE=$4

	[ -f "$FILE" ] || {
		echo "WARNING: patch missing, skipped: $NAME ($FILE)"
		return 0
	}

	if patch -d "$DIR" -p"$LEVEL" --dry-run --batch --forward < "$FILE" >/dev/null 2>&1; then
		patch -d "$DIR" -p"$LEVEL" --batch --forward < "$FILE"
		echo "Patch applied: $NAME"
	elif patch -d "$DIR" -p"$LEVEL" --dry-run --batch --reverse < "$FILE" >/dev/null 2>&1; then
		echo "Patch already present upstream: $NAME"
	else
		echo "WARNING: patch no longer applies, skipped: $NAME"
		return 0
	fi
}

# 恢复原来的 Argon 本地背景图；先下载临时文件，成功后再覆盖，避免失败时留下空文件。
ARGON_IMG="$PACKAGE_PATH/luci-theme-argon/luci-theme-argon/htdocs/luci-static/argon/img"
if [ -d "$ARGON_IMG" ]; then
	if ! wget -q -O "$ARGON_IMG/bg.webp.tmp" \
		"https://raw.githubusercontent.com/jerrykuku/luci-theme-argon/master/htdocs/luci-static/argon/img/bg1.webp"
	then
		rm -f "$ARGON_IMG/bg.webp.tmp"
		echo "WARNING: unable to download Argon background, keeping upstream image"
	else
		mv "$ARGON_IMG/bg.webp.tmp" "$ARGON_IMG/bg.webp"
		echo "Argon background replaced"
	fi
fi

# FRPC：隐藏 Token，并保留启用开关相关定制。
FRPC_INIT="$FEEDS_PATH/packages/net/frp/files/frpc.init"
if [ -f "$FRPC_INIT" ]; then
	sed -i \
		-e 's/procd_set_param stdout $stdout/procd_set_param stdout 0/g' \
		-e 's/procd_set_param stderr $stderr/procd_set_param stderr 0/g' \
		-e 's/stdout stderr //g' \
		-e '/stdout:bool/d' \
		-e '/stderr:bool/d' \
		-e '/stdout/d' \
		-e '/stderr/d' \
		"$FRPC_INIT"

	if ! grep -q "'enable:bool:0'" "$FRPC_INIT"; then
		sed -i \
			-e 's/env conf_inc/env conf_inc enable/g' \
			-e "s/'conf_inc:list(string)'/& \\\\/" \
			-e "/conf_inc:list/a\\\t\t'enable:bool:0'" \
			-e '/procd_open_instance/i\t[ "$enable" -ne 1 ] \&\& return 1\n' \
			"$FRPC_INIT"
	fi
fi

apply_patch_checked "frpc token" . 1 \
	"$PATCH_DIR/frpc/001-luci-app-frpc-hide-token.patch"
apply_patch_checked "frpc enable" . 1 \
	"$PATCH_DIR/frpc/002-luci-app-frpc-add-enable-flag.patch"

FRPC_PO="$FEEDS_PATH/luci/applications/luci-app-frpc/po/zh_Hans/frpc.po"
if [ -f "$FRPC_PO" ]; then
	sed -i 's,frp 客户端,FRP 客户端,g' "$FRPC_PO"
fi

FRPS_PO="$FEEDS_PATH/luci/applications/luci-app-frps/po/zh_Hans/frps.po"
[ -f "$FRPS_PO" ] && sed -i 's,frp 服务器,FRP 服务器,g' "$FRPS_PO"

# wolultra：菜单名和页面标题共用这条翻译，统一改为简洁的“网络唤醒”。
WOLULTRA_PO=$(find "$PACKAGE_PATH" -type f \
	-path '*/luci-app-wolultra/po/zh_Hans/wolultra.po' -print -quit)
if [ -n "$WOLULTRA_PO" ]; then
	sed -i 's/msgstr "超级网络唤醒"/msgstr "网络唤醒"/' "$WOLULTRA_PO"
else
	echo "WARNING: wolultra Chinese translation not found, skipped rename"
fi

# LuCI 系统功能。补丁若失效则直接报错，避免静默生成缺少功能的固件。
apply_patch_checked "reboot confirmation" "$FEEDS_PATH/luci" 1 \
	"$PATCH_DIR/luci-system_status/0001-luci-mod-system-add-modal-overlay-dialog-to-reboot.patch"
apply_patch_checked "refresh interval" "$FEEDS_PATH/luci" 1 \
	"$PATCH_DIR/luci-system_status/0005-luci-mod-system-add-refresh-interval-setting.patch"
apply_patch_checked "docker /opt mount point" "$FEEDS_PATH/luci" 1 \
	"$PATCH_DIR/luci-system_status/0006-luci-mod-system-mounts-add-docker-directory-mount-po.patch"
apply_patch_checked "zram ucitrack" "$FEEDS_PATH/luci" 1 \
	"$PATCH_DIR/luci-system_status/0007-luci-mod-system-add-ucitrack-luci-mod-system-zram.js.patch"
apply_patch_checked "dmesg colors" "$FEEDS_PATH/luci" 1 \
	"$PATCH_DIR/luci-system_status/0008-luci-mod-status-dmesg-add-ANSI-terminal-color-and-re.patch"

# 重启确认和刷新间隔由本仓库补丁新增，直接追加对应中文翻译。
BASE_PO="$FEEDS_PATH/luci/modules/luci-base/po/zh_Hans/base.po"
if [ -f "$BASE_PO" ]; then
	cat <<'EOF' >> "$BASE_PO"

msgid "Confirm Reboot"
msgstr "重启确认"

msgid "Are you sure you want to reboot the system?"
msgstr "确定要重启系统吗？将会丢失所有未保存的设置！"

msgid "Confirm"
msgstr "确定"

msgid "Refresh interval"
msgstr "页面刷新"

msgid "Refresh interval in seconds"
msgstr "刷新间隔（秒）"
EOF
else
	echo "WARNING: LuCI base translation file not found, skipped custom translations"
fi

# 服务日志保持安静。
TTYD_INIT="$FEEDS_PATH/packages/utils/ttyd/files/ttyd.init"
if [ -f "$TTYD_INIT" ]; then
	sed -i \
		-e 's/procd_set_param stdout 1/procd_set_param stdout 0/g' \
		-e 's/procd_set_param stderr 1/procd_set_param stderr 0/g' \
		"$TTYD_INIT"
fi

IPERF3_MAKEFILE="$FEEDS_PATH/packages/net/iperf3/Makefile"
if [ -f "$IPERF3_MAKEFILE" ] && ! grep -q -- '-funroll-loops' "$IPERF3_MAKEFILE"; then
	sed -i 's/D_GNU_SOURCE/D_GNU_SOURCE -funroll-loops/g' "$IPERF3_MAKEFILE"
fi

# 官方 OpenWrt 使用国内可达的默认 NTP。
if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	GENERATE_CONFIG="$PACKAGE_PATH/base-files/files/bin/config_generate"
	if [ -f "$GENERATE_CONFIG" ]; then
		sed -i \
			-e 's/0.openwrt.pool.ntp.org/ntp1.aliyun.com/g' \
			-e 's/1.openwrt.pool.ntp.org/time1.apple.com/g' \
			-e 's/2.openwrt.pool.ntp.org/time1.cloud.tencent.com/g' \
			-e 's/3.openwrt.pool.ntp.org/time.cloudflare.com/g' \
			"$GENERATE_CONFIG"
	fi
fi

echo "Custom source overlay done"
