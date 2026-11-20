#!/bin/bash
# 可选 DIY 调整按实际执行顺序排列。
# 默认启用的代码直接执行；暂未启用的代码整段注释，需要时在原位置取消注释。

PATCH_DIR="$GITHUB_WORKSPACE/Patch"
FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

echo -e "\nApply default and optional customizations"

# 补丁失效只记录警告，不中断固件编译。
apply_optional_patch() {
	local NAME=$1 DIR=$2 LEVEL=$3 FILE=$4
	if [ ! -f "$FILE" ]; then
		echo "WARNING: optional patch missing, skipped: $NAME ($FILE)"
		return 0
	fi

	if patch -d "$DIR" -p"$LEVEL" --dry-run --batch --forward < "$FILE" >/dev/null 2>&1; then
		patch -d "$DIR" -p"$LEVEL" --batch --forward < "$FILE"
		echo "Optional patch applied: $NAME"
	elif patch -d "$DIR" -p"$LEVEL" --dry-run --batch --reverse < "$FILE" >/dev/null 2>&1; then
		echo "Optional patch already present upstream: $NAME"
	else
		echo "WARNING: optional patch no longer applies, skipped: $NAME"
	fi
}

# =============================================================================
# 默认启用：上海时区与日志等级
# =============================================================================
SYSTEM_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/92-custom-system"
mkdir -p "$(dirname "$SYSTEM_DEFAULT")"
cat > "$SYSTEM_DEFAULT" <<'EOF'
#!/bin/sh
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].conloglevel='1'
uci set system.@system[0].cronloglevel='9'
uci commit system
exit 0
EOF
chmod 755 "$SYSTEM_DEFAULT"

# =============================================================================
# 默认启用：ZRAM 为物理内存的 25%，压缩算法 LZ4
# =============================================================================
ZRAM_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/93-custom-zram"
mkdir -p "$(dirname "$ZRAM_DEFAULT")"
cat > "$ZRAM_DEFAULT" <<'EOF'
#!/bin/sh
mem_total=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
zram_size=$(awk "BEGIN { print int($mem_total * 0.25 / 1024) }")
uci set system.@system[0].zram_size_mb="$zram_size"
uci set system.@system[0].zram_comp_algo='lz4'
uci commit system
exit 0
EOF
chmod 755 "$ZRAM_DEFAULT"

# =============================================================================
# 默认启用：将 LuCI 网络诊断地址换成国内可达地址
# =============================================================================
DIAG_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/98-custom-diagnostics"
mkdir -p "$(dirname "$DIAG_DEFAULT")"
cat > "$DIAG_DEFAULT" <<'EOF'
#!/bin/sh
if [ "$(uci -q get luci.diag.ping)" = 'openwrt.org' ]; then
	uci set luci.diag.dns='www.qq.com'
	uci set luci.diag.ping='www.qq.com'
	uci set luci.diag.route='www.qq.com'
	uci commit luci
fi
exit 0
EOF
chmod 755 "$DIAG_DEFAULT"

# =============================================================================
# 默认启用：删除 CoreMark 自动测试的定时任务；coremark 软件包本身仍保留
# =============================================================================
COREMARK_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/99-custom-coremark"
mkdir -p "$(dirname "$COREMARK_DEFAULT")"
cat > "$COREMARK_DEFAULT" <<'EOF'
#!/bin/sh
sed -i '/coremark/d' /etc/crontabs/root
crontab /etc/crontabs/root
exit 0
EOF
chmod 755 "$COREMARK_DEFAULT"

# =============================================================================
# 暂未启用：qca-nss-pbuf 启动顺序改为 86
# =============================================================================
# NSS_PBUF=$(find . -type f -path '*/kernel/mac80211/files/qca-nss-pbuf.init' -print -quit 2>/dev/null)
# [ -n "$NSS_PBUF" ] && sed -i 's/^START=.*/START=86/' "$NSS_PBUF"

# =============================================================================
# 暂未启用：旧 Rust 工具链 ci-llvm 编译修复
# =============================================================================
# RUST_MAKEFILE=$(find "$FEEDS_PATH/packages" -maxdepth 4 -type f -path '*/rust/Makefile' -print -quit 2>/dev/null)
# [ -n "$RUST_MAKEFILE" ] && sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_MAKEFILE"

# =============================================================================
# 暂未启用：DiskMan 从 ntfs-3g 改用内核 ntfs3
# =============================================================================
# DISKMAN_MAKEFILE=$(find "$PACKAGE_PATH" -type f -path '*/luci-app-diskman/Makefile' -print -quit 2>/dev/null)
# if [ -n "$DISKMAN_MAKEFILE" ]; then
# 	sed -i -e 's/fs-ntfs/fs-ntfs3/g' -e '/ntfs-3g-utils /d' "$DISKMAN_MAKEFILE"
# fi

# =============================================================================
# 暂未启用：删除 sing-box 上游补丁（仅在补丁导致编译失败时使用）
# =============================================================================
# SING_BOX_PATCHES="$FEEDS_PATH/packages/net/sing-box/patches"
# [ -d "$SING_BOX_PATCHES" ] && rm -rf -- "$SING_BOX_PATCHES"

# =============================================================================
# 暂未启用：Natmap 静默日志并增加默认 STUN 服务器
# =============================================================================
# NATMAP_INIT="$FEEDS_PATH/packages/net/natmap/files/natmap.init"
# if [ -f "$NATMAP_INIT" ]; then
# 	sed -i 's/log_stdout:bool:1/log_stdout:bool:0/g; s/log_stderr:bool:1/log_stderr:bool:0/g' "$NATMAP_INIT"
# fi
# apply_optional_patch "natmap STUN servers" "$FEEDS_PATH/luci" 1 \
# 	"$PATCH_DIR/luci-app-natmap/0001-luci-app-natmap-add-default-STUN-server-lists.patch"

# =============================================================================
# 暂未启用：Samba4 多通道及默认权限
# =============================================================================
# SAMBA_TEMPLATE="$FEEDS_PATH/packages/net/samba4/files/smb.conf.template"
# SAMBA_CONFIG="$FEEDS_PATH/packages/net/samba4/files/samba.config"
# SAMBA_LUCI="$FEEDS_PATH/luci/applications/luci-app-samba4/htdocs/luci-static/resources/view/samba4.js"
# if [ -f "$SAMBA_TEMPLATE" ]; then
# 	grep -q 'server multi channel support' "$SAMBA_TEMPLATE" || sed -i \
# 		'/workgroup/a\\n\t## enable multi-channel\n\tserver multi channel support = yes' "$SAMBA_TEMPLATE"
# 	sed -i \
# 		-e 's/#aio read size = 0/aio read size = 0/g' \
# 		-e 's/#aio write size = 0/aio write size = 0/g' \
# 		-e 's/invalid users = root/#invalid users = root/g' \
# 		-e 's/bind interfaces only = yes/bind interfaces only = no/g' \
# 		-e 's/#create mask/create mask/g' \
# 		-e 's/#directory mask/directory mask/g' \
# 		-e 's/0666/0644/g; s/0777/0755/g' "$SAMBA_TEMPLATE"
# 	[ -f "$SAMBA_CONFIG" ] && sed -i 's/0666/0644/g; s/0777/0755/g' "$SAMBA_CONFIG"
# 	[ -f "$SAMBA_LUCI" ] && sed -i 's/0666/0644/g; s/0744/0755/g; s/0777/0755/g' "$SAMBA_LUCI"
# fi

# =============================================================================
# 暂未启用：清空 Watchcat 默认配置
# =============================================================================
# WATCHCAT_CONFIG="$FEEDS_PATH/packages/utils/watchcat/files/watchcat.config"
# [ -f "$WATCHCAT_CONFIG" ] && : > "$WATCHCAT_CONFIG"

# =============================================================================
# 暂未启用：WOLPlus 中文翻译
# =============================================================================
# apply_optional_patch "wolplus translation" . 1 \
# 	"$PATCH_DIR/wolplus/001-luci-app-wolplus-edit-po.patch"

# =============================================================================
# 暂未启用：Firewall3 固件加入 nlbwmon
# =============================================================================
# if grep -q '^CONFIG_PACKAGE_firewall4=n$' ./.config; then
# 	echo 'CONFIG_PACKAGE_luci-app-nlbwmon=y' >> ./.config
# fi

# =============================================================================
# 暂未启用：删除 DDNS init 中的 boot() 函数
# =============================================================================
# DDNS_INIT="$FEEDS_PATH/packages/net/ddns-scripts/files/etc/init.d/ddns"
# [ -f "$DDNS_INIT" ] && sed -i '/boot()/,+2d' "$DDNS_INIT"

# =============================================================================
# 暂未启用：状态页实际内存计算
# =============================================================================
# apply_optional_patch "actual memory usage" "$FEEDS_PATH/luci" 1 \
# 	"$PATCH_DIR/luci-system_status/0002-luci-mod-status-displays-actual-process-memory-usage.patch"

# =============================================================================
# 暂未启用：状态页只显示有效存储设备
# =============================================================================
# apply_optional_patch "storage device filter" "$FEEDS_PATH/luci" 1 \
# 	"$PATCH_DIR/luci-system_status/0003-luci-mod-status-storage-index-applicable-only-to-val.patch"

# =============================================================================
# 暂未启用：隐藏 legacy iptables 警告并重组防火墙状态菜单
# =============================================================================
# apply_optional_patch "firewall status layout" "$FEEDS_PATH/luci" 1 \
# 	"$PATCH_DIR/luci-system_status/0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch"

# =============================================================================
# 暂未启用：强制 Argon 默认主题并设置 3 秒轮询
# =============================================================================
# THEME_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/91-custom-theme"
# mkdir -p "$(dirname "$THEME_DEFAULT")"
# cat > "$THEME_DEFAULT" <<'EOF'
# #!/bin/sh
# if [ -d /www/luci-static/argon ] && [ -z "$(uci -q get luci.main.pollinterval)" ]; then
# 	uci set luci.main.mediaurlbase='/luci-static/argon'
# 	uci set luci.main.pollinterval='3'
# 	uci commit luci
# fi
# exit 0
# EOF
# chmod 755 "$THEME_DEFAULT"

# =============================================================================
# 暂未启用：opkg 国内镜像（APK 固件不要启用）
# =============================================================================
# OPKG_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/94-custom-opkg-mirror"
# mkdir -p "$(dirname "$OPKG_DEFAULT")"
# cat > "$OPKG_DEFAULT" <<'EOF'
# #!/bin/sh
# [ -f /etc/opkg/distfeeds.conf ] || exit 0
# if grep -q SNAPSHOT /etc/opkg/distfeeds.conf; then
# 	sed -i 's,downloads.openwrt.org,mirror.sjtu.edu.cn/openwrt,g' /etc/opkg/distfeeds.conf
# else
# 	sed -i 's,downloads.openwrt.org,mirrors.aliyun.com/openwrt,g' /etc/opkg/distfeeds.conf
# fi
# exit 0
# EOF
# chmod 755 "$OPKG_DEFAULT"

# =============================================================================
# 暂未启用：软件 Flow Offloading
# =============================================================================
# OFFLOAD_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/95-custom-offloading"
# mkdir -p "$(dirname "$OFFLOAD_DEFAULT")"
# cat > "$OFFLOAD_DEFAULT" <<'EOF'
# #!/bin/sh
# uci -q get firewall.@defaults[0].flow_offloading >/dev/null || \
# 	uci set firewall.@defaults[0].flow_offloading='1'
# uci commit firewall
# exit 0
# EOF
# chmod 755 "$OFFLOAD_DEFAULT"

# =============================================================================
# 暂未启用：Packet Steering
# =============================================================================
# STEERING_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/96-custom-steering"
# mkdir -p "$(dirname "$STEERING_DEFAULT")"
# cat > "$STEERING_DEFAULT" <<'EOF'
# #!/bin/sh
# uci -q get network.globals.packet_steering >/dev/null || {
# 	uci set network.globals='globals'
# 	uci set network.globals.packet_steering='2'
# 	uci set network.globals.steering_flows='128'
# 	uci commit network
# }
# exit 0
# EOF
# chmod 755 "$STEERING_DEFAULT"

# =============================================================================
# 暂未启用：放宽防火墙入站策略（安全风险，启用前必须确认）
# =============================================================================
# FIREWALL_DEFAULT="$PACKAGE_PATH/base-files/files/etc/uci-defaults/97-custom-firewall-input"
# mkdir -p "$(dirname "$FIREWALL_DEFAULT")"
# cat > "$FIREWALL_DEFAULT" <<'EOF'
# #!/bin/sh
# . /etc/os-release
# uci set firewall.@defaults[0].input='ACCEPT'
# if [ "$(ifconfig -a | grep -c '^eth')" -le 1 ] || [ "$OPENWRT_BOARD" = 'armsr/armv8' ]; then
# 	uci set firewall.@zone[1].input='ACCEPT'
# fi
# uci commit firewall
# exit 0
# EOF
# chmod 755 "$FIREWALL_DEFAULT"

echo "Default and optional customizations processed"
