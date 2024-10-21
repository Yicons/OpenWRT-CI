#!/bin/bash

echo "开始自定义页面"

PATCH_DIR="$GITHUB_WORKSPACE/Patch"

# ----------------frpc修改--------------------
FRPC_FILE="./feeds/packages/net/frp/files/frpc.init"
# 不输出日志, 并且删除了日志输出的相关配置参数
sed -i 's/procd_set_param stdout $stdout/procd_set_param stdout 0/g' $FRPC_FILE
sed -i 's/procd_set_param stderr $stderr/procd_set_param stderr 0/g' $FRPC_FILE
sed -i 's/stdout stderr //g' $FRPC_FILE
sed -i '/stdout:bool/d;/stderr:bool/d' $FRPC_FILE
sed -i '/stdout/d;/stderr/d' $FRPC_FILE
# 添加 enable 选项，作为控制 frpc 服务启用与否的标志。新增的逻辑会在实例打开之前检查 enable 的值，如果值不为 1，则终止执行
sed -i 's/env conf_inc/env conf_inc enable/g' $FRPC_FILE
sed -i "s/'conf_inc:list(string)'/& \\\\/" $FRPC_FILE
sed -i "/conf_inc:list/a\\\t\t\'enable:bool:0\'" $FRPC_FILE
sed -i '/procd_open_instance/i\\t\[ "$enable" -ne 1 \] \&\& return 1\n' $FRPC_FILE
# 将 token 字段改为密码输入框。这样，用户输入的 Token 将以星号或点的形式显示，保护 Token 信息的隐私
patch -p1 < $PATCH_DIR/frpc/001-luci-app-frpc-hide-token-openwrt-24.10.patch
# 移除了 stdout 和 stderr 日志选项 
# 可以通过 Web 界面启用或禁用 frpc 服务
# 强制 respawn 默认开启，确保服务在崩溃时能够自动重启
patch -p1 < $PATCH_DIR/frpc/002-luci-app-frpc-add-enable-flag-openwrt-24.10.patch

# frpc translation
sed -i 's,frp 服务器,FRP 服务器,g' ./feeds/luci/applications/luci-app-frps/po/zh_Hans/frps.po
sed -i 's,frp 客户端,FRP 客户端,g' ./feeds/luci/applications/luci-app-frpc/po/zh_Hans/frpc.po

echo "FRPC Modify down!"
# ----------------frpc修改--------------------

# ddns - fix boot
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns

echo "ddns Modify down!"

if [[ $WRT_REPO = *"lede"* ]]; then
	# 调整 OpenVPN 到 VPN 菜单
	#sed -i 's/vpn/services/g; s/VPN/Services/g' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua
    sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-openvpn/luasrc/controller/openvpn.lua
	sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-openvpn/luasrc/view/openvpn/pageswitch.htm
    echo "OpenVPN Modify down!"
fi

