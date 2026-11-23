# OpenWrt WARP MASQUE 插件

本项目是适用于 OpenWrt 的 Cloudflare WARP **MASQUE / Connect-IP** 插件，基于 [usque](https://github.com/Diniboy1123/usque) 实现，不包含 WireGuard。

## 适用平台与功能

- 适用于 OpenWrt 23.05.5
- 处理器架构：x86_64
- 仅使用 Cloudflare WARP **MASQUE** 协议（usque / Connect-IP）
- SOCKS5 代理默认监听：`0.0.0.0:32500`
- HTTP CONNECT 代理默认监听：`0.0.0.0:32511`
- 提供中文 LuCI 管理界面
- 可在 LuCI 界面自定义监听地址、SOCKS5 端口和 HTTP 端口
- WARP MASQUE 进程使用专用系统 UID，与 PassWall / OpenClash 等代理隔离\n- 通过 IPv4/IPv6 策略路由优先走 main 路由表，绕过常见代理策略标记\n- main 路由表无可用路由时使用 prohibit 规则阻断，防止回落到其他代理形成回环\n- 通过 GitHub Actions 自动编译 IPK 安装包并发布版本

安装包内置静态编译的 Go 语言 usque 程序。SOCKS5 和 HTTP 代理分别由 procd 服务管理，共用同一份 MASQUE 注册配置。

## 全新安装 / 降级安装（OpenWrt x86_64）

当前提供的回退安装包为 **build-40 / warp-masque 1.0.0-1**，源码基线对应历史构建 #20。适用于 OpenWrt 23.05.5 x86_64。

> **版本说明：** build-40 是回退到 #20 的 1.0.0-1 版本，提供本机 SOCKS5 和 HTTP CONNECT 代理。它不包含后续 1.1.x 版本的独立 `warp` 用户和 IPv4/IPv6 策略路由隔离功能。请勿将本安装包误认为包含回环隔离功能的新版。

### 适用条件

- OpenWrt 23.05.5，设备架构为 x86_64。
- 使用 root 账户通过 SSH 登录路由器。
- 路由器可以访问 GitHub。

### 一键下载并安装

将下面整段命令复制到 OpenWrt SSH 终端执行：

```sh
# 1. 检查设备架构
[ "$(uname -m)" = "x86_64" ] || {
    echo "错误：此安装包仅适用于 x86_64"
    exit 1
}

# 2. 进入临时目录并下载 build-40（对应 #20 的 1.0.0-1）
cd /tmp
wget -O warp-masque_1.0.0-1_x86_64.ipk \
  https://github.com/mengxianbo/warp-openwrt/releases/download/build-40/warp-masque_1.0.0-1_x86_64.ipk

# 3. 安装（允许从较新版本降级）
opkg install --force-downgrade /tmp/warp-masque_1.0.0-1_x86_64.ipk

# 4. 设置开机启动
/etc/init.d/warp enable

# 5. 查看安装版本
opkg status warp-masque
```

也可以直接打开 [build-40 发布页面](https://github.com/mengxianbo/warp-openwrt/releases/tag/build-40) 下载 IPK 后，通过 SCP / WinSCP 上传到路由器，再执行：

```sh
opkg install --force-downgrade /tmp/warp-masque_1.0.0-1_x86_64.ipk
/etc/init.d/warp enable
```

### 首次注册并启动

全新安装后，先注册 WARP 设备，再启动服务：

```sh
warpctl register
warpctl start
warpctl status
```

如果设备之前已经注册，并且 `/etc/usque/config.json` 文件仍然存在，则不要重复注册，直接执行：

```sh
/etc/init.d/warp enable
warpctl start
warpctl status
```

### 默认代理端口

| 服务类型 | 默认监听地址 | 默认端口 |
|---|---|---:|
| SOCKS5 | `0.0.0.0` | `32500` |
| HTTP CONNECT | `0.0.0.0` | `32511` |

安装后可在 LuCI 的 **服务 → WARP MASQUE** 页面管理服务，并按需修改监听地址和端口。

### 安装注意事项

- 本安装包是 x86_64 专用，不适用于 ARM、ARM64、MIPS 等架构。
- `--force-downgrade` 允许从较新版本降级到 1.0.0-1。降级前建议备份 `/etc/config/warp` 和 `/etc/usque/config.json`。
- WARP 注册文件包含设备凭据，请勿公开分享。
- 1.0.0-1 不包含后续版本的独立 UID / 策略路由隔离机制；与 PassWall、OpenClash 等代理共存时，请自行确认路由策略，避免代理回环。
- 不要将未设置认证的代理端口暴露到公网。

**build-40 安装包：** [warp-masque_1.0.0-1_x86_64.ipk](https://github.com/mengxianbo/warp-openwrt/releases/download/build-40/warp-masque_1.0.0-1_x86_64.ipk)

## 打开 LuCI 管理页面

安装完成后，登录 OpenWrt 管理后台，进入：

**服务 → WARP MASQUE**

也可以直接访问：

```text
http://<路由器局域网地址>/cgi-bin/luci/admin/services/warp
```

请将上述地址中的 `<路由器局域网地址>` 替换为 OpenWrt 路由器的实际局域网 IP 地址。

管理页面提供启用开关、监听地址、SOCKS5 和 HTTP 端口设置、设备注册及服务控制功能。

默认端口如下：

| 服务类型 | 默认监听地址 | 默认端口 |
|---|---|---:|
| SOCKS5 | `0.0.0.0` | `32500` |
| HTTP CONNECT | `0.0.0.0` | `32511` |

可以在 LuCI 页面修改监听地址和端口。修改后请保存并应用配置。

## 首次注册 WARP 设备

**仅当设备是首次安装，并且不存在** `/etc/usque/config.json` **时，才需要执行注册。**

1. 确保路由器可以正常访问互联网。
2. 打开 **服务 → WARP MASQUE**。
3. 点击“注册 WARP 设备”，等待注册完成。
4. 启动服务并检查运行状态。

也可以通过 SSH 执行：

```sh
warpctl register
warpctl start
warpctl status
```

Cloudflare 可能对设备注册进行频率限制。如果已经存在有效的 `/etc/usque/config.json`，请勿反复注册。

## 与 PassWall / OpenClash 等其他代理共存

从 1.1.0 开始，WARP 的两个 usque 代理进程以独立的系统用户 `warp` 运行，不再与其他 root 代理进程共用 UID。服务启动时会为该 UID 安装 IPv4 和 IPv6 策略规则：

- 优先级 90：WARP 用户流量查询 `main` 路由表，避开常见基于 fwmark 的 PassWall / OpenClash / PBR 规则。
- 优先级 91：如果 `main` 表没有匹配路由，则执行 `prohibit`，不允许继续落入后续代理规则，避免回环。
- 停止 WARP 服务时，只清理本插件为 UID `warp` 创建的规则，不清理其他代理的路由或防火墙规则。
- 如果优先级 90 或 91 已被其他规则占用，插件会拒绝启动，不覆盖已有规则。

**重要限制：** 该插件提供的是本机 SOCKS5 / HTTP CONNECT 代理，不创建 WARP TUN，也不接管全局默认路由。WARP MASQUE 的外层连接会使用 `main` 表。因此，OpenWrt 的 `main` 表默认路由必须指向物理 WAN；如果你把 `main` 默认路由本身改成了另一个 VPN/TUN，WARP 外层连接也会跟随该路由。此隔离方案不修改其他代理的配置，也不能替代对 WAN 默认路由的检查。

查看隔离状态：

```sh
warpctl status
/usr/bin/warp-route status
ip rule show
ip -6 rule show
```

如果路由器缺少支持 `uidrange` 选择器的 iproute2，或策略规则安装失败，WARP 服务会拒绝启动，而不是在没有隔离保护的情况下运行。

## 局域网设备使用代理

在需要使用代理的局域网设备上，将代理服务器地址设置为 OpenWrt 路由器的局域网 IP 地址：

- SOCKS5：`<路由器局域网地址>:32500`
- HTTP 代理：`<路由器局域网地址>:32511`

如果希望 DNS 查询也通过 SOCKS5 代理转发，请在客户端启用远程 DNS 解析模式，部分软件将其标记为 SOCKS5 主机名解析或 `socks5h`。

默认监听地址为 `0.0.0.0`，因此局域网设备可以连接代理端口。这些代理端口不应直接暴露到公网。请保持 OpenWrt WAN 入站防火墙策略，并限制为可信任的局域网设备访问；如有需要，请使用代理认证。

## 通过 SSH 管理服务

启动、查看状态和停止服务（启动时自动安装隔离规则，停止时清理本插件规则）：

```sh
warpctl start
warpctl status
warpctl stop
```

查看相关系统日志：

```sh
logread -e usque
logread -e warp
```

检查代理端口是否正在监听：

```sh
netstat -lntp 2>/dev/null | grep -E ':32500|:32511' || ss -lntp | grep -E ':32500|:32511'
```

在路由器本机测试代理：

```sh
curl -x socks5h://127.0.0.1:32500 https://www.cloudflare.com/cdn-cgi/trace
curl -x http://127.0.0.1:32511 https://www.cloudflare.com/cdn-cgi/trace
```

如果代理连接成功，Cloudflare 检测结果中通常应包含：

```text
warp=on
```

## 故障诊断

如果管理页面或代理无法正常工作，请先收集以下诊断信息，不要急于删除注册配置或重新注册：

```sh
echo "===== 插件安装信息 ====="
opkg status warp-masque 2>/dev/null || opkg list-installed | grep -i warp

echo "===== 插件配置 ====="
uci show warp

echo "===== 相关进程 ====="
ps w | grep -E '[u]sque|[w]arp'

echo "===== 代理监听端口 ====="
(netstat -lntp 2>/dev/null || ss -lntp) | grep -E ':32500|:32511' || true

echo "===== 相关系统日志 ====="
logread | grep -iE 'warp|usque' | tail -n 100
```

## 编译与发布

向 `main` 分支推送提交，或在 GitHub 仓库的“操作”页面手动运行“编译 WARP MASQUE 安装包”工作流。

工作流会执行以下操作：

1. 获取上游 usque v3.0.1 源码。
2. 为 Linux amd64 架构编译程序。
3. 将 LuCI 文件和程序打包为 IPK 安装包。
4. 检查安装包内部结构。
5. 上传编译产物并创建 GitHub Release。

- 编译工作流：[WARP MASQUE 自动编译](https://github.com/mengxianbo/warp-openwrt/actions/workflows/build.yml)
- 安装包发布页：[GitHub 版本发布](https://github.com/mengxianbo/warp-openwrt/releases)

## 功能范围与安全说明

- 本插件提供 SOCKS5 和 HTTP CONNECT 代理服务，**不是**全局透明代理，不创建 TUN 网卡，也不会自动接管路由器默认出口。
- 局域网设备与路由器之间的 SOCKS5、HTTP 代理连接本身不提供加密。请在可信任的局域网内使用，并根据需要配置防火墙限制和代理认证。
- 不要将未设置认证的代理端口暴露到 WAN 或公网。
- WARP 注册、服务可用性、连接速度和使用政策由 Cloudflare 决定。
- 上游项目及许可证：[Diniboy1123/usque](https://github.com/Diniboy1123/usque)，MIT 许可证。

## IPK 安装包格式

发布的安装包采用 OpenWrt 使用的 gzip 压缩 tar 容器，内部包含 `debian-binary`、`control.tar.gz` 和 `data.tar.gz`，并非 Debian 的 `ar` 格式归档。自动编译流程会在发布前检查安装包结构。
