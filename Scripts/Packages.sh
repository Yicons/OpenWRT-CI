#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)

	rm -rf $(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune)

	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	if [[ $PKG_SPECIAL == "pkg" ]]; then
		cp -rf $(find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune) ./
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

#UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
# UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "$([[ $WRT_REPO == *"lede"* ]] && echo "18.06" || echo "master")"
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
#UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "homeproxy" "immortalwrt/homeproxy" "master"
#UPDATE_PACKAGE "mihomo" "morytyann/OpenWrt-mihomo" "main"
#UPDATE_PACKAGE "nekoclash" "Thaolga/luci-app-nekoclash" "main"
#UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"
# UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"

# UPDATE_PACKAGE "vnt" "lazyoop/networking-artifact" "main" "pkg"
# UPDATE_PACKAGE "easytier" "lazyoop/networking-artifact" "main" "pkg"
UPDATE_PACKAGE "luci-app-gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# UPDATE_PACKAGE "v2ray-geodata" "sbwml/v2ray-geodata" "master"
UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5"
UPDATE_PACKAGE "luci-app-socat" "chenmozhijin/luci-app-socat" "main"
UPDATE_PACKAGE "luci-app-filemanager" "sbwml/luci-app-filemanager" "main"

if [[ $WRT_REPO != *"immortalwrt"* ]]; then
	UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
fi

UPDATE_PACKAGE "passwall_packages" "xiaorouji/openwrt-passwall-packages" "main"
# if [[ $WRT_REPO == *"lede"* || $WRT_REPO == *"openwrt/openwrt"* ]]; then
	
if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	UPDATE_PACKAGE "autocore-arm" "sbwml/autocore-arm" "openwrt-24.10"
fi
# fi

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-not}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	echo " "

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo "$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Pho 'PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)' $PKG_FILE | head -n 1)
		local PKG_VER=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease|$PKG_MARK)) | first | .tag_name")
		local NEW_VER=$(echo $PKG_VER | sed "s/.*v//g; s/_/./g")
		local NEW_HASH=$(curl -sL "https://codeload.github.com/$PKG_REPO/tar.gz/$PKG_VER" | sha256sum | cut -b -64)
		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")

		echo "$OLD_VER $PKG_VER $NEW_VER $NEW_HASH"

		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"
UPDATE_VERSION "xray-core"
UPDATE_VERSION "tailscale"

# Git稀疏克隆，只克隆指定目录到指定目录
REPO_PATCH="$GITHUB_WORKSPACE/wrt/"

function git_sparse_clone() {
	branch="$1"   # 分支名
	repourl="$2"  # 仓库地址
	mvpath="$3"    # 转移地址
	shift 3       # 移动参数，使后续参数是需要稀疏检出的文件夹

	# 克隆指定分支的仓库，使用稀疏检出
	git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
	repodir=$(basename "$repourl" .git)  # 提取仓库目录名

	# 进入克隆的仓库目录
	cd $repodir

	# 检出指定的文件夹
	git sparse-checkout set $@

	if [ -d "$REPO_PATCH/$mvpath" ]; then
		# 循环移动所有需要检出的文件夹
		for folder in "$@"; do
			# 提取文件夹名，忽略父目录
			foldername=$(basename "$folder")
			rm -rf $(find $REPO_PATCH/feeds/luci/ $REPO_PATCH/feeds/packages/ -maxdepth 3 -type d -iname "*$foldername*" -prune)
			cp -rf $(find ./ -maxdepth 3 -type d -iname "*$foldername*" -prune) $REPO_PATCH/$mvpath
			if [[ $mvpath == "package/" ]]; then
				find $REPO_PATCH/package/$foldername/ -name "Makefile" -exec sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|g' {} +
				find $REPO_PATCH/package/$foldername/ -name "Makefile" -exec sed -i 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} +
			fi
			echo "Sparse Update $foldername down!"
		done
		# ls -l "$REPO_PATCH/$mvpath"
	else
		echo $mvpath"不存在"
	fi

	# 返回上一级目录并删除克隆的仓库目录
	cd .. 
	rm -rf $repodir
}

#git_sparse_clone "分支名" "仓库地址" "转移地址(编译根目录下)" "单/多个需要文件夹的目录"
git_sparse_clone main https://github.com/VIKINGYFY/packages package/ luci-app-wolplus

if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	git_sparse_clone master https://github.com/immortalwrt/packages package/ net/zerotier net/ddns-go
	git_sparse_clone master https://github.com/immortalwrt/luci package/ applications/luci-app-zerotier applications/luci-app-ddns-go applications/luci-app-autoreboot
fi

# if [[ $WRT_REPO == *"lede"* ]]; then
# 	# rm -rf $(find $REPO_PATCH/package/ -maxdepth 3 -type d -iname "*ddns-scripts*" -prune)
# 	# net/frp applications/luci-app-frpc net/ddns-scripts applications/luci-app-ddns net/samba4 applications/luci-app-samba4
# 	git_sparse_clone master https://github.com/openwrt/packages feeds/packages/net/ net/cloudflared 
# 	git_sparse_clone master https://github.com/openwrt/luci package/ applications/luci-app-cloudflared 

# 	git_sparse_clone master https://github.com/immortalwrt/packages package/ net/msd_lite
# 	git_sparse_clone master https://github.com/immortalwrt/luci package/ applications/luci-app-msd_lite
# fi

# # iStore
# git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
# git_sparse_clone main https://github.com/linkease/istore luci

# # 晶晨宝盒
# git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
# sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/haiibo/OpenWrt'|g" package/luci-app-amlogic/root/etc/config/amlogic
# # sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" package/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|ARMv8|ARMv8_PLUS|g" package/luci-app-amlogic/root/etc/config/amlogic

# # 添加额外插件
# git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-filebrowser luci-app-ssr-mudb-server
# git_sparse_clone openwrt-18.06 https://github.com/immortalwrt/luci applications/luci-app-eqos
# # git_sparse_clone master https://github.com/syb999/openwrt-19.07.1 package/network/services/msd_lite