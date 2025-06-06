#!/bin/bash

# diff -u original new > 1.patch

PATCH_DIR="$GITHUB_WORKSPACE/Patch"

# samba4 - bump version
rm -rf feeds/packages/net/samba4
git clone https://github.com/sbwml/feeds_packages_net_samba4 feeds/packages/net/samba4
# liburing - 2.7 (samba-4.21.0)
# rm -rf feeds/packages/libs/liburing
# git clone https://github.com/sbwml/feeds_packages_libs_liburing feeds/packages/libs/liburing
# enable multi-channel
sed -i '/workgroup/a \\n\t## enable multi-channel' feeds/packages/net/samba4/files/smb.conf.template
sed -i '/enable multi-channel/a \\tserver multi channel support = yes' feeds/packages/net/samba4/files/smb.conf.template
# default config
sed -i 's/#aio read size = 0/aio read size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#aio write size = 0/aio write size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/bind interfaces only = yes/bind interfaces only = no/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#create mask/create mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#directory mask/directory mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/0666/0644/g;s/0744/0755/g;s/0777/0755/g' feeds/luci/applications/luci-app-samba4/htdocs/luci-static/resources/view/samba4.js
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/samba.config
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/smb.conf.template

# TTYD
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i '3 a\\t\t"order": 50,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init

# frpc修改
FRPC_FILE="./feeds/packages/net/frp/files/frpc.init"
#   不输出日志, 并且删除了日志输出的相关配置参数
sed -i 's/procd_set_param stdout $stdout/procd_set_param stdout 0/g' $FRPC_FILE
sed -i 's/procd_set_param stderr $stderr/procd_set_param stderr 0/g' $FRPC_FILE
sed -i 's/stdout stderr //g' $FRPC_FILE
sed -i '/stdout:bool/d;/stderr:bool/d' $FRPC_FILE
sed -i '/stdout/d;/stderr/d' $FRPC_FILE
#   添加 enable 选项，作为控制 frpc 服务启用与否的标志。新增的逻辑会在实例打开之前检查 enable 的值，如果值不为 1，则终止执行
sed -i 's/env conf_inc/env conf_inc enable/g' $FRPC_FILE
sed -i "s/'conf_inc:list(string)'/& \\\\/" $FRPC_FILE
sed -i "/conf_inc:list/a\\\t\t\'enable:bool:0\'" $FRPC_FILE
sed -i '/procd_open_instance/i\\t\[ "$enable" -ne 1 \] \&\& return 1\n' $FRPC_FILE
#   将 token 字段改为密码输入框。这样，用户输入的 Token 将以星号或点的形式显示，保护 Token 信息的隐私
patch -p1 < $PATCH_DIR/frpc/001-luci-app-frpc-hide-token-openwrt-24.10.patch
#   移除了 stdout 和 stderr 日志选项 
#   可以通过 Web 界面启用或禁用 frpc 服务
#   强制 respawn 默认开启，确保服务在崩溃时能够自动重启
patch -p1 < $PATCH_DIR/frpc/002-luci-app-frpc-add-enable-flag-openwrt-24.10.patch
#   frpc translation
sed -i 's,frp 服务器,FRP 服务器,g' feeds/luci/applications/luci-app-frps/po/zh_Hans/frps.po
sed -i 's,frp 客户端,FRP 客户端,g' feeds/luci/applications/luci-app-frpc/po/zh_Hans/frpc.po

# WOLPLUS
patch -p1 < $PATCH_DIR/wolplus/001-luci-app-wolplus-edit-po.patch

if [[ $WRT_REPO != *"lede"* ]]; then
    # DDNS - fix boot
    sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
fi

# luci-mod extra
patch -p1 < $PATCH_DIR/luci-system_status/0001-luci-mod-system-add-modal-overlay-dialog-to-reboot.patch
# patch -p1 < $PATCH_DIR/luci-system_status/0002-luci-mod-status-displays-actual-process-memory-usage.patch
# patch -p1 < $PATCH_DIR/luci-system_status/0003-luci-mod-status-storage-index-applicable-only-to-val.patch
# patch -p1 < $PATCH_DIR/luci-system_status/0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch
patch -p1 < $PATCH_DIR/luci-system_status/0005-luci-mod-system-add-refresh-interval-setting.patch

# translation
cat <<EOF >> feeds/luci/modules/luci-base/po/zh_Hans/base.po

#: modules/luci-mod-system/htdocs/luci-static/resources/view/system/reboot.js:34
msgid "Confirm Reboot"
msgstr "重启确认"

#: modules/luci-mod-system/htdocs/luci-static/resources/view/system/reboot.js:35
msgid "Are you sure you want to reboot the system?"
msgstr "确定要重启系统吗？将会丢失所有未保存的设置！"

#: modules/luci-mod-system/htdocs/luci-static/resources/view/system/reboot.js:43
msgid "Confirm"
msgstr "确定"

#: modules/luci-mod-system/htdocs/luci-static/resources/view/system/system.js:247
msgid "Refresh interval"
msgstr "页面刷新"

#: modules/luci-mod-system/htdocs/luci-static/resources/view/system/system.js:247
msgid "Refresh interval in seconds"
msgstr "刷新间隔（秒）"
EOF

# tailscale
sed -i 's/services/vpn/g' package/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json

# watchcat - clean config
true > feeds/packages/utils/watchcat/files/watchcat.config

# # nlbwmon
# if grep -q "CONFIG_PACKAGE_firewall4=n" ./.config; then
#     echo "fw3 can use nlbwmon"
#     echo "CONFIG_PACKAGE_luci-app-nlbwmon=y" >> ./.config
#     sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
#     sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js
# fi

# 调整VPN菜单顺序
patch -p1 < $PATCH_DIR/luci-base/001-luci-base-change-order-add-nas.patch

# samba4
if [[ $WRT_REPO == *"lede"* || $WRT_REPO == *"openwrt/openwrt"* ]]; then
    find ./ -name "luci-app-samba4.json" -exec sed -i 's|services|nas|g' {} +
fi

if [[ $WRT_REPO = *"openwrt/openwrt"* ]]; then
	# # 调整 OpenVPN 到 VPN 菜单
	# sed -i 's/vpn/services/g; s/VPN/Services/g' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua
    # sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-openvpn/luasrc/controller/openvpn.lua
	# sed -i 's/services/vpn/g' feeds/luci/applications/luci-app-openvpn/luasrc/view/openvpn/pageswitch.htm

    # NTP
    sed -i 's/0.openwrt.pool.ntp.org/ntp1.aliyun.com/g' package/base-files/files/bin/config_generate
    sed -i 's/1.openwrt.pool.ntp.org/time1.apple.com/g' package/base-files/files/bin/config_generate
    sed -i 's/2.openwrt.pool.ntp.org/time1.cloud.tencent.com/g' package/base-files/files/bin/config_generate
    sed -i 's/3.openwrt.pool.ntp.org/time.cloudflare.com/g' package/base-files/files/bin/config_generate
fi

# if [[ $WRT_REPO == *"lede"* ]]; then
# # 防火墙 - 自定义规则_learn fw3用于富强不可用时可尝试添加
# iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53
# iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53
# [ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53
# [ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53
# fi
