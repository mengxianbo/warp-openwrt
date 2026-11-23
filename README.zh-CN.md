# OpenWrt WARP MASQUE

基于 [usque](https://github.com/Diniboy1123/usque) 的 OpenWrt LuCI 插件，用于连接 Cloudflare WARP **MASQUE / Connect-IP**。本项目仅使用 MASQUE 协议，不包含 WireGuard。

[English](README.md) | **简体中文**

## 适用平台与功能

- OpenWrt 23.05.5
- x86_64
- Cloudflare WARP **仅 MASQUE 协议**（usque / Connect-IP）
- SOCKS5 代理默认监听：`0.0.0.0:32500`
- HTTP CONNECT 代理默认监听：`0.0.0.0:32511`
- 中文 LuCI 管理界面
- 可在 LuCI 页面自定义监听地址、SOCKS5 端口和 HTTP 端口
- GitHub Actions 自动编译 IPK，并发布到 GitHub Releases

软件包内置静态编译的 Go `usque` 程序。SOCKS5 和 HTTP 代理分别由 procd 服务管理，并共用同一份 MASQUE 设备注册配置。

## 安装或升级

# 1. 更新软件包索引
opkg update

# 2. 安装 LuCI 运行依赖
opkg install \
    luci-base \
    luci-compat \
    ca-bundle \
    curl \
    wget \
    tar \
    gzip

# 3. 下载最新版 WARP MASQUE IPK
cd /tmp

wget -O warp-masque_1.0.0-1_x86_64.ipk \
"https://github.com/mengxianbo/warp-openwrt/releases/download/build-20/warp-masque_1.0.0-1_x86_64.ipk"

# 4. 检查安装包
ls -lh /tmp/warp-masque_1.0.0-1_x86_64.ipk
file /tmp/warp-masque_1.0.0-1_x86_64.ipk

# 5. 安装或覆盖旧版本
opkg install --force-reinstall \
/tmp/warp-masque_1.0.0-1_x86_64.ipk

# 6. 清理 LuCI 缓存
rm -f /tmp/luci-indexcache
rm -f /tmp/luci-modulecache/* 2>/dev/null

# 7. 重启 Web 服务
/etc/init.d/uhttpd restart

# 8. 检查安装结果
echo "===== WARP MASQUE 安装检查 ====="
opkg list-installed | grep -i warp
echo
ls -lh /usr/bin/warpctl /usr/bin/usque 2>/dev/null
echo
uci show warp 2>/dev/null



> 本安装包仅适用于 x86_64 架构，请勿安装到其他 CPU 架构的设备。

### 从旧版本升级的重要说明

- 上面的命令会重新安装软件包文件，不要求升级时重新注册 WARP 设备。
- 请保留已有的 `/etc/usque/config.json` 注册配置。**升级时不要删除 `/etc/usque`，也不要为了升级而重新注册设备。**
- 如果之前自定义过设置，升级后使用 `uci show warp` 检查配置。
- 建议妥善备份 `/etc/usque/config.json`。该文件包含设备/账户凭据，请勿公开或发送到公开渠道。

## 打开 LuCI 管理页面

安装完成后，登录 OpenWrt LuCI：

**服务 → WARP MASQUE**

也可以直接访问：

```text
http://<路由器LAN地址>/cgi-bin/luci/admin/services/warp
```

请将 `<路由器LAN地址>` 替换为你的 OpenWrt 路由器实际 LAN IP。

页面提供启用开关、监听地址、SOCKS5 和 HTTP 端口、设备注册及服务控制等设置。默认端口如下：

| 服务 | 默认监听地址 | 默认端口 |
|---|---|---:|
| SOCKS5 | `0.0.0.0` | `32500` |
| HTTP CONNECT | `0.0.0.0` | `32511` |

监听地址和端口均可在 LuCI 页面修改。修改后请保存并应用配置。

## 首次注册 WARP 设备

仅当这是**全新安装，且不存在** `/etc/usque/config.json` 时，才需要执行首次注册。

1. 确保路由器可以正常访问互联网。
2. 打开 **服务 → WARP MASQUE**。
3. 点击 **注册 WARP 设备**，等待注册命令执行完成。
4. 启动服务并检查运行状态。

也可以通过 SSH 执行：

```sh
warpctl register
warpctl start
warpctl status
```

Cloudflare 可能对注册请求进行频率限制。如果已经存在有效的 `/etc/usque/config.json`，请勿反复注册。

## 配置局域网客户端

在电脑、手机或其他局域网设备的代理设置中，填写 OpenWrt 路由器的 LAN IP：

- SOCKS5：`<路由器LAN地址>:32500`
- HTTP 代理：`<路由器LAN地址>:32511`

如果希望 DNS 查询也通过 SOCKS5 代理转发，请在客户端选择远程 DNS 解析模式（部分客户端称为 SOCKS5 hostname resolution），使用 `socks5h` 方式。

默认监听地址为 `0.0.0.0`，允许局域网设备连接。代理端口不应暴露到公网。请保持 OpenWrt 默认 WAN 入站防火墙策略，并限制访问来源为可信局域网设备；如有需要，可启用代理身份验证。

## SSH 命令：启动、停止和查看状态

```sh
# 启动代理
warpctl start

# 查看运行状态
warpctl status

# 停止代理
warpctl stop
```

查看相关系统日志：

```sh
logread -e usque
logread -e warp
```

检查本地代理端口是否正在监听：

```sh
netstat -lntp 2>/dev/null | grep -E ':32500|:32511' || ss -lntp | grep -E ':32500|:32511'
```

在路由器本机测试代理：

```sh
curl -x socks5h://127.0.0.1:32500 https://www.cloudflare.com/cdn-cgi/trace
curl -x http://127.0.0.1:32511 https://www.cloudflare.com/cdn-cgi/trace
```

Cloudflare Trace 测试成功时，结果中应包含：

```text
warp=on
```

### 故障诊断信息收集

如果 LuCI 页面或代理无法正常工作，请先收集以下信息，不要急着删除注册配置或重新注册：

```sh
echo "===== 软件包 ====="
opkg status warp-masque 2>/dev/null || opkg list-installed | grep -i warp

echo "===== UCI 配置 ====="
uci show warp

echo "===== 进程 ====="
ps w | grep -E '[u]sque|[w]arp'

echo "===== 监听端口 ====="
(netstat -lntp 2>/dev/null || ss -lntp) | grep -E ':32500|:32511' || true

echo "===== 日志 ====="
logread | grep -iE 'warp|usque' | tail -n 100
```

## GitHub Actions 自动编译

推送代码到 `main` 分支，或在 GitHub 仓库中手动进入 **Actions → Build WARP MASQUE IPK**，即可触发编译。

工作流使用上游 usque v3.0.1，针对 Linux amd64 编译，将 LuCI 文件和程序打包为 IPK，检查软件包结构，上传构建产物并发布版本 Release。

- 编译工作流：[Build WARP MASQUE IPK](https://github.com/mengxianbo/warp-openwrt/actions/workflows/build.yml)
- 发布版本：[GitHub Releases](https://github.com/mengxianbo/warp-openwrt/releases)

## 功能范围与安全说明

- 本项目提供 SOCKS5 和 HTTP CONNECT 代理服务，**不是**全路由透明代理、TUN 虚拟网卡，也不会自动接管路由器默认出口。
- SOCKS5 和 HTTP 代理协议本身不会加密局域网客户端到路由器之间的连接。请在可信局域网内使用，并根据需要配置防火墙限制和代理身份验证。
- 不要将未启用身份验证的代理端口暴露到 WAN 或公网。
- WARP 设备注册、服务可用性、吞吐量和使用策略由 Cloudflare 控制。

上游项目及许可证：[Diniboy1123/usque](https://github.com/Diniboy1123/usque)，MIT。

## IPK 打包格式说明

Release 中的软件包采用 OpenWrt 原生 gzip 压缩 tar 容器格式，内部包含 `debian-binary`、`control.tar.gz` 和 `data.tar.gz`，并非 Debian 的 `ar` 格式。CI 工作流会在发布前验证外层软件包结构。
