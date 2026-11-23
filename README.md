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

## 完整安装或升级（OpenWrt x86_64）

当前已验证的正式安装包为 **build-25 / warp-masque 1.0.0-1**，适用于 OpenWrt 23.05.5 x86_64。此版本固定下载地址和 SHA256，避免 `latest` 指向其他版本时出现文件名或校验值不匹配。

> **重要版本说明：** build-25 安装包是 `1.0.0-1`。它提供本机 SOCKS5 和 HTTP CONNECT 代理，但**不包含 1.1.0 的独立 warp UID 与 IPv4/IPv6 策略路由隔离功能**。如果需要后者，请先确认仓库已发布并验证对应的 1.1.0 IPK，不要把 build-25 当作 1.1.0 安装。

### 适用条件

- OpenWrt 23.05.5，设备架构为 x86_64。
- 通过 SSH 登录路由器，并使用 root 账户执行。
- 路由器能够访问 GitHub 下载地址。
- 不适用于 ARM、ARM64、MIPS 等其他架构。

### 一键安装 / 覆盖安装命令

下面脚本会检查设备架构、备份已有配置、停止旧服务、安装依赖、下载并校验 IPK，然后安装插件。已有的 WARP 注册文件会被备份并恢复，不会主动重新注册设备。

将整段复制到 OpenWrt SSH 终端执行：

```sh
cat > /tmp/install-warp-masque.sh <<'EOF'
#!/bin/sh
set -eu

PKG="warp-masque_1.0.0-1_x86_64.ipk"
URL="https://github.com/mengxianbo/warp-openwrt/releases/download/build-25/warp-masque_1.0.0-1_x86_64.ipk"
SHA256="6c3c805eab776870f7ebd8279c6c831dd76cd98e84300660369acb2500d5460a"
BACKUP="/root/warp-backup"

echo "===== 1. 检查系统架构 ====="
ARCH="$(uname -m)"
echo "当前架构：$ARCH"
[ "$ARCH" = "x86_64" ] || {
    echo "错误：此 IPK 仅适用于 x86_64，已停止。"
    exit 1
}

echo "===== 2. 备份已有配置 ====="
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"

if [ -f /etc/usque/config.json ]; then
    cp -p /etc/usque/config.json "$BACKUP/config.json"
    chmod 600 "$BACKUP/config.json"
    echo "已备份 WARP 注册文件。"
fi

if [ -f /etc/config/warp ]; then
    cp -p /etc/config/warp "$BACKUP/warp"
    echo "已备份 UCI 配置。"
fi

echo "===== 3. 停止旧版服务（如正在运行） ====="
if command -v warpctl >/dev/null 2>&1; then
    warpctl stop || true
fi
/etc/init.d/warp stop 2>/dev/null || true

echo "===== 4. 更新软件包索引并安装依赖 ====="
opkg update
opkg install \
    luci-base \
    luci-compat \
    ca-bundle \
    curl \
    wget \
    tar \
    gzip \
    ip-full

echo "===== 5. 下载 build-25 安装包 ====="
cd /tmp
rm -f "$PKG"
wget -O "$PKG" "$URL"
[ -s "$PKG" ] || {
    echo "错误：安装包下载失败或文件为空。"
    exit 1
}

echo "===== 6. 校验 SHA256 ====="
echo "$SHA256  /tmp/$PKG" | sha256sum -c -

echo "===== 7. 安装插件 ====="
opkg install --force-downgrade "/tmp/$PKG"

echo "===== 8. 恢复原有配置 ====="
if [ -f "$BACKUP/config.json" ]; then
    mkdir -p /etc/usque
    cp -p "$BACKUP/config.json" /etc/usque/config.json
    chmod 600 /etc/usque/config.json
fi

if [ -f "$BACKUP/warp" ]; then
    cp -p "$BACKUP/warp" /etc/config/warp
fi

echo "===== 9. 清理 LuCI 缓存并重启 Web 服务 ====="
rm -f /tmp/luci-indexcache
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/uhttpd restart

echo "===== 10. 检查安装结果 ====="
opkg status warp-masque
echo
ls -l /usr/bin/warpctl /usr/bin/usque 2>/dev/null || true
echo
echo "安装完成。首次安装请按 README 的“首次注册 WARP 设备”章节注册；已有注册文件不要重复注册。"
EOF

chmod +x /tmp/install-warp-masque.sh
/tmp/install-warp-masque.sh
```

### 安装命令说明

| 步骤 | 作用 |
|---|---|
| 架构检查 | 防止把 x86_64 安装包装到其他平台 |
| 配置备份 | 备份 `/etc/usque/config.json` 和 `/etc/config/warp` |
| 停止服务 | 避免升级时旧进程占用资源 |
| 安装依赖 | 安装 LuCI、证书、下载工具和 IP 路由工具 |
| 下载与校验 | 固定下载 build-25，并用 SHA256 验证文件完整性 |
| 安装 IPK | 使用 `--force-downgrade` 允许覆盖较新版本 |
| 恢复配置 | 保留原有设备注册信息和 UCI 设置 |
| 重启 Web | 清理 LuCI 缓存并重启管理页面服务 |

SHA256：`6c3c805eab776870f7ebd8279c6c831dd76cd98e84300660369acb2500d5460a`

### 首次安装与已有设备的区别

- **首次安装：** 如果没有 `/etc/usque/config.json`，安装完成后需要注册一次 WARP 设备。
- **已经注册过：** 保留 `/etc/usque/config.json` 即可，升级时不要删除该文件，也不要为了升级反复执行注册。
- **从 1.1.0 降级到 build-25：** 上述命令会使用 `--force-downgrade`。降级后 1.1.0 的独立 UID / 策略路由隔离功能不再适用；建议检查并清理仅由旧版插件创建的规则，避免遗留规则影响网络。不要手动删除其他代理创建的规则。

注册文件包含设备和账户凭据。备份目录为 root 私有目录，请勿公开分享 `/root/warp-backup/config.json`。

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
