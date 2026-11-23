#!/bin/bash
# 个人软件包覆盖层。
# 本文件由上游 Scripts/Packages.sh 自动 source，避免直接修改上游包脚本。

echo -e "\nApply private package overlay"

# 代理和 DDNS-Go 都在设备配置中选择；切换软件时只需修改对应 Config/<设备>.txt。
package_enabled() {
	grep -q "^$1=y$" "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt"
}

# 删除上游阶段引入的重复包；Packages.sh 保持原样，便于以后同步上游。
rm -rf \
	package/packages/gecoosac \
	package/packages/luci-app-gecoosac \
	package/packages/luci-app-homeproxy \
	package/packages/sing-box \
	package/gecoosac \
	package/luci-app-gecoosac

# HomeProxy 使用 ImmortalWrt 官方仓库；核心在后面的条件区块中选择。
if package_enabled CONFIG_PACKAGE_luci-app-homeproxy; then
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

	local TMP SOURCE_PATH NAME FOUND
	TMP=$(mktemp -d "$PWD/.custom-sparse.XXXXXX") || {
		echo "ERROR: unable to create temporary directory for $REPO"
		return 1
	}
	SPARSE_DIRS+=("$TMP")

	if ! git clone --depth=1 --single-branch --branch "$BRANCH" \
		--filter=blob:none --sparse "$REPO" "$TMP"
	then
		echo "ERROR: unable to clone sparse package source: $REPO ($BRANCH)"
		return 1
	fi
	if ! git -C "$TMP" sparse-checkout set "$@"; then
		echo "ERROR: unable to select sparse package paths from $REPO: $*"
		return 1
	fi

	# 先确认所有来源目录有效，再删除现有包，防止上游改路径时留下缺包源码树。
	for SOURCE_PATH in "$@"; do
		if [ ! -d "$TMP/$SOURCE_PATH" ]; then
			echo "ERROR: sparse package path missing: $REPO/$SOURCE_PATH"
			return 1
		fi
	done

	mkdir -p "$DEST" || return 1
	for SOURCE_PATH in "$@"; do
		NAME=${SOURCE_PATH##*/}

		for FOUND in feeds/luci feeds/packages; do
			[ -d "$FOUND" ] || continue
			find "$FOUND" -maxdepth 3 -type d -name "$NAME" -prune -exec rm -rf {} +
		done

		# 直接放在 package 下的旧版本也必须清理，避免复制后残留旧文件。
		rm -rf "$DEST/$NAME"
		if ! cp -rf "$TMP/$SOURCE_PATH" "$DEST/"; then
			echo "ERROR: unable to copy sparse package: $SOURCE_PATH"
			return 1
		fi

		find "$DEST/$NAME" -name Makefile -type f -exec sed -i \
			-e 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|g' \
			-e 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} +
		if ! find "$DEST/$NAME" -name Makefile -type f -print -quit | grep -q .; then
			echo "ERROR: copied package has no Makefile: $DEST/$NAME"
			return 1
		fi
	done
}

# VIK main 的旧核心未接收 libffi 迁移；缺包时补入官方实现，已有则保留上游。
if [[ $WRT_REPO == *"VIKINGYFY/immortalwrt"* && $WRT_BRANCH == "main" ]]; then
	if find package feeds -type f -path '*/libffi/Makefile' -print -quit | grep -q .; then
		echo "VIK libffi: already provided by source or feeds; skipping compatibility fix"
	else
		echo "VIK libffi: missing; importing from ImmortalWrt core"
		sparse_packages master https://github.com/immortalwrt/immortalwrt package \
			package/libs/libffi || return 1
	fi
fi

sparse_packages main https://github.com/sbwml/openwrt_pkgs package \
	luci-app-socat luci-app-eqos luci-app-vlmcsd vlmcsd || return 1

# DDNS-Go 统一使用 ImmortalWrt 版本，覆盖上游脚本拉取的 sirpdboy 版本。
rm -rf package/ddns-go package/luci-app-ddns-go
if package_enabled CONFIG_PACKAGE_luci-app-ddns-go || \
	package_enabled CONFIG_PACKAGE_ddns-go
then
	sparse_packages master https://github.com/immortalwrt/packages package \
		net/ddns-go || return 1
	sparse_packages master https://github.com/immortalwrt/luci package \
		applications/luci-app-ddns-go || return 1
fi

# HomeProxy 与 Passwall 分开选择核心来源。同一固件同时启用时优先使用
# Passwall 配套核心，HomeProxy 继续共用其中的 sing-box。
PASSWALL_CORE_PACKAGES=(
	xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria
	ipt2socks microsocks naiveproxy shadowsocks-libev shadowsocks-rust
	shadowsocksr-libev simple-obfs tcping trojan-plus tuic-client
	v2ray-plugin xray-plugin geoview shadow-tls
)

if package_enabled CONFIG_PACKAGE_luci-app-passwall || \
	package_enabled CONFIG_PACKAGE_luci-app-passwall2
then
	for PACKAGE_NAME in "${PASSWALL_CORE_PACKAGES[@]}"; do
		find feeds/luci feeds/packages package -mindepth 1 -maxdepth 4 \
			-type d -name "$PACKAGE_NAME" -prune -exec rm -rf {} + 2>/dev/null
	done
	UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main"
elif package_enabled CONFIG_PACKAGE_luci-app-homeproxy; then
	find feeds/luci feeds/packages package -mindepth 1 -maxdepth 4 \
		-type d -name "sing-box" -prune -exec rm -rf {} + 2>/dev/null
	# master 的 sing-box 默认启用 Naive outbound，需要同源 libcronet。
	sparse_packages master https://github.com/immortalwrt/packages package \
		libs/libcronet net/sing-box || return 1
fi

if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	sparse_packages master https://github.com/immortalwrt/packages package \
		net/zerotier lang/python/python-setuptools || return 1
	sparse_packages master https://github.com/immortalwrt/luci package \
		applications/luci-app-zerotier applications/luci-app-autoreboot || return 1
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
