#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
# UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"

# UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
# UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
# UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"
UPDATE_PACKAGE "homeproxy" "immortalwrt/homeproxy" "master"
UPDATE_PACKAGE "passwall_packages" "xiaorouji/openwrt-passwall-packages" "main"
# UPDATE_PACKAGE "v2ray-geodata" "sbwml/v2ray-geodata" "master"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "luci-app-socat" "chenmozhijin/luci-app-socat" "main"
UPDATE_PACKAGE "luci-app-filemanager" "sbwml/luci-app-filemanager" "main"

UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

if [[ $WRT_REPO != *"immortalwrt"* ]]; then
	UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
fi

if [[ $WRT_REPO == *"openwrt/openwrt"* ]]; then
	UPDATE_PACKAGE "autocore-arm" "sbwml/autocore-arm" "openwrt-24.10"
fi

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
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
git_sparse_clone() {
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

REPO_PATCH="$GITHUB_WORKSPACE/wrt/"

# git_sparse_clone "分支名" "仓库地址" "转移地址(编译根目录下)" "单/多个需要文件夹的目录"
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
