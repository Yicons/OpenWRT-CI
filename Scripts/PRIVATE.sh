#!/bin/bash
# 个人软件包覆盖层。
# 本文件由上游 Scripts/Packages.sh 自动 source，避免直接修改上游包脚本。

echo -e "\nApply private package overlay"

# 按最终合并顺序读取设备配置和通用配置，避免依赖配置文件名称。
config_enabled() {
	local SYMBOL=$1 VALUE
	VALUE=$(sed -n "s/^${SYMBOL}=\(.*\)$/\1/p" \
		"$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt" \
		"$GITHUB_WORKSPACE/Config/GENERAL.txt" 2>/dev/null | tail -n 1)
	[ "$VALUE" = "y" ]
}

HOME_PROXY_ENABLED=false
PASSWALL1_ENABLED=false
PASSWALL2_ENABLED=false
PASSWALL_ENABLED=false
DDNS_GO_ENABLED=false
config_enabled CONFIG_PACKAGE_luci-app-homeproxy && HOME_PROXY_ENABLED=true
config_enabled CONFIG_PACKAGE_luci-app-passwall && PASSWALL1_ENABLED=true
config_enabled CONFIG_PACKAGE_luci-app-passwall2 && PASSWALL2_ENABLED=true
if $PASSWALL1_ENABLED || $PASSWALL2_ENABLED; then PASSWALL_ENABLED=true; fi
if config_enabled CONFIG_PACKAGE_luci-app-ddns-go || config_enabled CONFIG_PACKAGE_ddns-go; then
	DDNS_GO_ENABLED=true
fi
echo "Package selection: HomeProxy=$HOME_PROXY_ENABLED Passwall=$PASSWALL_ENABLED DDNS-Go=$DDNS_GO_ENABLED"

# 删除上游阶段引入的重复包；Packages.sh 保持原样，便于以后同步上游。
rm -rf \
	package/packages/gecoosac \
	package/packages/luci-app-gecoosac \
	package/packages/luci-app-homeproxy \
	package/packages/sing-box \
	package/gecoosac \
	package/luci-app-gecoosac

# 上游会同时准备 Passwall 和 Passwall2；只保留当前配置实际启用的应用。
if ! $PASSWALL1_ENABLED; then
	rm -rf package/luci-app-passwall feeds/luci/applications/luci-app-passwall
fi
if ! $PASSWALL2_ENABLED; then
	rm -rf package/luci-app-passwall2 feeds/luci/applications/luci-app-passwall2
fi

# HomeProxy 使用 ImmortalWrt 官方仓库；核心在后面的条件区块中选择。
if $HOME_PROXY_ENABLED; then
	UPDATE_PACKAGE "homeproxy" "immortalwrt/homeproxy" "master"
fi

UPDATE_PACKAGE "luci-app-filemanager" "sbwml/luci-app-filemanager" "main"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 备用源：当前默认不使用，需要替换现有包时取消注释。
# UPDATE_PACKAGE "samba4" "sbwml/feeds_packages_net_samba4" "main"
# UPDATE_PACKAGE "luci-app-socat" "chenmozhijin/luci-app-socat" "main"

if [[ $WRT_REPO != *"immortalwrt"* ]]; then
	UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
fi

if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	UPDATE_PACKAGE "autocore-arm" "sbwml/autocore-arm" "openwrt-25.12"
fi

# 从大仓库中只取需要的包。
SPARSE_DIRS=()
CUSTOM_SPARSE_ROOT=""

cleanup_sparse_clone() {
	local DIR
	for DIR in "${SPARSE_DIRS[@]}"; do
		[ -n "$DIR" ] && [ -d "$DIR" ] && rm -rf "$DIR"
	done
}
trap cleanup_sparse_clone EXIT

sparse_packages() {
	local BRANCH=$1
	local REPO=$2
	local DEST=$3
	shift 3

	local TMP PATH NAME FOUND
	TMP=$(mktemp -d "$PWD/.custom-sparse.XXXXXX") || return 1
	SPARSE_DIRS+=("$TMP")

	git clone --depth=1 --single-branch --branch "$BRANCH" --filter=blob:none --sparse "$REPO" "$TMP"
	git -C "$TMP" sparse-checkout set "$@"
	mkdir -p "$DEST"

	for PATH in "$@"; do
		NAME=${PATH##*/}

		for FOUND in feeds/luci feeds/packages; do
			[ -d "$FOUND" ] || continue
			find "$FOUND" -maxdepth 3 -type d -name "$NAME" -prune -exec rm -rf {} +
		done

		if [ ! -d "$TMP/$PATH" ]; then
			echo "Sparse package missing: $PATH"
			return 1
		fi

		cp -rf "$TMP/$PATH" "$DEST/"
		find "$DEST/$NAME" -name Makefile -type f -exec sed -i \
			-e 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|g' \
			-e 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} +
	done
}

sparse_packages main https://github.com/sbwml/openwrt_pkgs package \
	luci-app-socat luci-app-eqos luci-app-vlmcsd vlmcsd

# DDNS-Go 统一使用 ImmortalWrt 版本，覆盖上游脚本拉取的 sirpdboy 版本。
rm -rf package/ddns-go package/luci-app-ddns-go
if $DDNS_GO_ENABLED; then
	sparse_packages master https://github.com/immortalwrt/packages package \
		net/ddns-go
	sparse_packages master https://github.com/immortalwrt/luci package \
		applications/luci-app-ddns-go
fi

# HomeProxy 与 Passwall 分开选择核心来源。同一固件同时启用时优先使用
# Passwall 配套核心，HomeProxy 继续共用其中的 sing-box。
PASSWALL_CORE_PACKAGES=(
	xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria
	ipt2socks microsocks naiveproxy shadowsocks-libev shadowsocks-rust
	shadowsocksr-libev simple-obfs tcping trojan-plus tuic-client
	v2ray-plugin xray-plugin geoview shadow-tls
)

if $PASSWALL_ENABLED; then
	for PACKAGE_NAME in "${PASSWALL_CORE_PACKAGES[@]}"; do
		find feeds/luci feeds/packages package -mindepth 1 -maxdepth 4 \
			-type d -name "$PACKAGE_NAME" -prune -exec rm -rf {} + 2>/dev/null
	done
	UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main"
elif $HOME_PROXY_ENABLED; then
	find feeds/luci feeds/packages package -mindepth 1 -maxdepth 4 \
		-type d -name "sing-box" -prune -exec rm -rf {} + 2>/dev/null
	sparse_packages master https://github.com/immortalwrt/packages package \
		net/sing-box
fi

if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	sparse_packages master https://github.com/immortalwrt/immortalwrt package \
		package/network/utils/fullconenat-nft
	sparse_packages master https://github.com/immortalwrt/packages package \
		net/zerotier lang/python/python-setuptools
	sparse_packages master https://github.com/immortalwrt/luci package \
		applications/luci-app-zerotier applications/luci-app-autoreboot
fi

# LEDE 备用包覆盖：以后重新加入 LEDE 源时，可取消整个区块的注释。
# if [[ $WRT_REPO == *"lede"* ]]; then
# 	sparse_packages master https://github.com/openwrt/packages feeds/packages/net \
# 		net/cloudflared
# 	sparse_packages master https://github.com/openwrt/luci package \
# 		applications/luci-app-cloudflared
# 	sparse_packages master https://github.com/immortalwrt/packages package \
# 		net/msd_lite
# 	sparse_packages master https://github.com/immortalwrt/luci package \
# 		applications/luci-app-msd_lite
# fi

# Tailscale 等新版本需要 Go 1.27。
rm -rf feeds/packages/lang/golang
git clone --depth=1 --single-branch --branch 27.x \
	https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
find feeds/packages -type f -name Makefile -exec \
	sed -i 's|golang1\.27/host|golang/host|g' {} +

# luci-app-tailscale 提供配置和启动脚本，移除核心包中的重复安装项。
TAILSCALE_MAKEFILE="feeds/packages/net/tailscale/Makefile"
if [ -f "$TAILSCALE_MAKEFILE" ]; then
	sed -i \
		-e '/tailscale\.init.*\/etc\/init\.d\/tailscale/d' \
		-e '/tailscale\.conf.*\/etc\/config\/tailscale/d' \
		"$TAILSCALE_MAKEFILE"
fi

UPDATE_VERSION "tailscale"

cleanup_sparse_clone
trap - EXIT
echo "Private package overlay done"
