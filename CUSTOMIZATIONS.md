# 自定义改动清单

这份清单用于区分上游代码、原仓库中的个人需求，以及本次整理新增的维护逻辑。

## 当前编译范围

- X86：`openwrt/openwrt`、`immortalwrt/immortalwrt` 的当前默认分支
- IPQ60XX-WIFI-NO、IPQ60XX-WIFI-YES：`LiBwrt-op/openwrt-6.x` 的当前默认分支、`VIKINGYFY/immortalwrt:main`
- 只有 `VIKINGYFY/immortalwrt` 固定使用高通专用、带满血 NSS 的 `main`；其他源码在每次检查时自动解析其默认分支。
- 定时任务比较源码提交和构建指纹；任一变化才编译，失败不会覆盖上一份成功固件。
- 构建指纹包含当前设备配置、`GENERAL/PRIVATE` 配置、脚本、补丁、核心工作流及编译参数；README 等无关文件不触发编译。
- X86 和 IPQ 工作流的默认主题均为 Vantage；Argon 继续编入固件作为可选主题。

## 从原仓库保留的个人需求

- 四份设备配置和 `GENERAL.txt` 中实际启用的软件包。
- Passwall、HomeProxy、FileManager、Tailscale、VNT 等软件包覆盖源。
- Go 1.27、Tailscale 文件冲突修复和 sing-box/xray/tailscale 版本更新。
- FRPC 隐藏 Token、启用开关和静默日志。
- FRPC 中文名称、iperf3 `-funroll-loops`、TTyD 静默日志。
- 重启确认、刷新间隔、Docker `/opt` 挂载点、Zram ucitrack、内核日志颜色。
- mini-diskmanager、natmapt、ttyd、tailscale、socat、wolultra 菜单调整；wolultra 中文名称改为“网络唤醒”；官方 OpenWrt 增加 NAS 菜单和顺序。
- 官方 OpenWrt 的默认 NTP 地址。
- 状态概览中的固件版本精简为“源码版本（提交）/ LuCI 分支、版本（提交）/ 构建者与日期”；原来的追加逻辑在 `Settings.sh` 中注释保留。
- Argon 使用原来的 `bg1.webp` 本地背景图；其他 Argon/Aurora/Vantage 样式覆盖保持关闭。
- 升级后若状态页样式异常，先强制刷新浏览器缓存。
- Vantage 作为默认主题，不修改其 CSS，也不增加缓存版本号；Argon 作为可选主题保留。

## 本次整理新增

- `Build-Check.yml`：轻量定时触发入口，本身不执行源码比较。
- `WRT-CORE.yml`：把源码提交和构建指纹与上次成功 Release 比较后决定跳过或编译；手动可强制运行。
- `Scripts/PRIVATE.sh`：只放软件包来源和包冲突处理。
- `Scripts/Custom.sh`：只放源码补丁、背景、服务和 NTP 等非菜单调整；DIY 补丁失效时警告并继续编译。
- `Scripts/MenuLayout.sh`：集中管理所有 LuCI 菜单位置、一级菜单和显示顺序；某项失效时警告并继续。
- `Scripts/Optional.sh`：保留默认初始化和暂未启用的个人改动；可选项在文件末尾取消一行注释即可启用。
- 上游 `Scripts/Handles.sh` 继续执行，以便以后接收新增修复；当前主题覆盖保持注释，菜单改动统一交给 `MenuLayout.sh`。
- 测试模式不再创建 Release，避免被误判成成功固件。
- `Auto-Clean` 不全局删除 Release/Tag；每个组合发布成功后由 `WRT-CORE.yml` 删除该“配置 + 源码 + 分支”的旧版本，只保留最新版，失败时保留上一份成功固件。

## 暂未启用的原改动

这些代码已经保留在当前分支，不需要再到归档分支查找：

- 菜单改动统一放在 `Scripts/MenuLayout.sh`，其他暂未启用的脚本改动放在 `Scripts/Optional.sh`。
- `Optional.sh` 按执行顺序放置独立代码块，不再采用“上方函数、底部开关”的结构。
- 需要某项功能时，直接在对应标题下面取消整段代码的注释。
- 原补丁文件已恢复到 `Patch/`；可选补丁失效时只输出警告并继续编译。

归档分支 `archive/pre-refactor-2026-11-19`（提交 `e958345`）只作为整理前的完整备份，
不再作为日常恢复功能的入口。

### 原本就处于注释状态

- Argon 字体与透明度、Aurora 菜单样式、Vantage 字体覆盖。
- qca-nss-pbuf 启动顺序、Rust/DiskMan/sing-box 临时修复。
- wolplus 翻译、nlbwmon 条件配置、默认主机名。

这些内容都以有标题的完整代码块保留在 `Optional.sh` 原位置，
不需要再到文件底部寻找开关。保留注释状态不表示需求无效。

### 当前软件未启用，因此暂不执行

- natmap：关闭 stdout/stderr，并加入默认 STUN 服务器。
- Samba4：启用多通道、修改权限掩码；NAS 菜单位置已经恢复为启用。
- Watchcat：清空默认配置。
- OpenAppFilter、DDNS：菜单迁移和启动函数修改。

OpenAppFilter 的调用保留在 `MenuLayout.sh`，其他项目保留在 `Optional.sh`；
对应软件以后重新启用时，取消相应调用的注释即可。

### 原仓库存在但当时也没有执行的补丁

- `0002`：把内存“已使用”改为 `总量 - 空闲 - 缓存`，并交换状态页显示顺序。
- `0003`：存储页只显示 `/dev/` 设备，同时隐藏 `/boot`、`/root` 等挂载点。
- `0004`：隐藏 legacy iptables 警告，并重组防火墙状态菜单。

补丁文件已放回 `Patch/luci-system_status/`，对应调用紧跟在 `Optional.sh`
的功能标题下面，当前继续保持整段注释。

### `999-custom-init.patch.patch` 的具体影响

该补丁会在首次启动时同时执行以下设置，所以不能在未确认的情况下整体恢复：

- 强制选择 Argon，并把 LuCI 轮询间隔设为 3 秒。
- 设置上海时区、控制台/cron 日志等级、ZRAM 为内存的 25% 且使用 LZ4。
- 把 opkg 软件源替换为阿里云或上海交大；APK 固件上这段已经不适用。
- 开启 flow offloading 和 packet steering。
- 把防火墙默认 input 改为 `ACCEPT`；单网口设备还会把 WAN zone input 改为 `ACCEPT`，会扩大入站访问范围。
- 修改诊断地址，并删除 coremark 定时任务。

原始 `999-custom-init.patch.patch` 仍保留用于对照，但不会整包调用。上述功能已拆成独立代码块。

默认启用：

- 上海时区与日志等级
- ZRAM 25% + LZ4
- 国内诊断地址
- 删除 CoreMark 自动测试定时任务

保留为可选：

- Argon 默认主题及 3 秒轮询
- opkg 国内镜像
- Flow Offloading
- Packet Steering
- 放宽防火墙入站策略

其中软件源入口仅适用于 opkg；防火墙入口会放宽入站策略，启用前要单独确认。

## 已确认剔除的旧代码

- 没有补丁文件的 OpenAppFilter 重构补丁调用。
- 重复的 Passwall/Passwall2 下载，以及未使用的另一套手动克隆命令。
- 旧的临时构建环境命令、备用文件命名写法和仅供调试的克隆注释。

Momo、Nikki 不是无效代码，只是当前不使用，因此仍在 `Scripts/Packages.sh` 中以注释形式保留。
Samba4、Socat 备用源和 LEDE 的 Cloudflared/msd_lite 覆盖也以注释形式保留在
`Scripts/PRIVATE.sh`，以后需要时可以直接取消注释。

### 暂未纳入当前编译范围的平台

AIROHA、MTK、OWRT、QCA、QCB 工作流保持本次整理后的现状，不恢复旧的自动触发注释，
也不纳入这份可选改动脚本。

查看整理前的原文件（仅用于历史对照）：

```bash
git show archive/pre-refactor-2026-11-19:Scripts/Modify.sh
git diff archive/pre-refactor-2026-11-19..codex/maintainable-v2
```

以后增加、停用或恢复个人需求时，同步修改本文件，避免再次出现“代码还在但不知道是否生效”。
