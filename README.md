# WARP MASQUE for OpenWrt

[简体中文文档](README.zh-CN.md)

OpenWrt LuCI package for Cloudflare WARP **MASQUE / Connect-IP** using [usque](https://github.com/Diniboy1123/usque). This project does not include WireGuard.

## Target and features

- OpenWrt 23.05.5
- x86_64
- Cloudflare WARP **MASQUE only** (usque / Connect-IP)
- SOCKS5 proxy: `0.0.0.0:32500` by default
- HTTP CONNECT proxy: `0.0.0.0:32511` by default
- Chinese LuCI configuration page
- SOCKS5 and HTTP ports and bind address can be customized in LuCI
- GitHub Actions builds the IPK and publishes it as a GitHub Release asset

The package embeds a statically linked Go `usque` binary. SOCKS5 and HTTP proxy modes run as separate supervised procd services and share one MASQUE registration/configuration.

## Install or upgrade

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
> This package is built for x86_64. Do not install it on a different CPU architecture.

### Important when upgrading an existing installation

- The upgrade command above reinstalls the package files; it does not require you to register a new WARP device.
- Keep the existing `/etc/usque/config.json` registration file. **Do not delete `/etc/usque` and do not run registration again just to upgrade the package.**
- If you have customized settings, check them after upgrading with `uci show warp`.
- Back up `/etc/usque/config.json` securely. It contains device/account credentials; do not post it publicly.

## Open the LuCI page

After installation, sign in to LuCI and open:

**Services → WARP MASQUE**

Direct URL:

```text
http://<router-LAN-IP>/cgi-bin/luci/admin/services/warp
```

For example, replace `<router-LAN-IP>` with your OpenWrt router's LAN address.

The page provides the enable switch, bind address, SOCKS5 and HTTP port settings, registration controls, and service controls. Default ports:

| Service | Default listen address | Default port |
|---|---|---:|
| SOCKS5 | `0.0.0.0` | `32500` |
| HTTP CONNECT | `0.0.0.0` | `32511` |

The bind address and ports can be changed in LuCI. Save and apply the settings after editing.

## First-time WARP registration

Only perform registration on a **new installation that has no existing** `/etc/usque/config.json`.

1. Make sure the router can access the Internet.
2. Open **Services → WARP MASQUE**.
3. Click **注册 WARP 设备** and wait for registration to finish.
4. Start the service and check its status.

CLI alternative:

```sh
warpctl register
warpctl start
warpctl status
```

Registration may be rate-limited by Cloudflare. Do not repeatedly register if a valid `/etc/usque/config.json` already exists.

## Configure LAN clients

Set the proxy address on each LAN client to the OpenWrt router's LAN IP:

- SOCKS5: `<router-LAN-IP>:32500`
- HTTP proxy: `<router-LAN-IP>:32511`

For SOCKS5 clients, use remote DNS mode (often shown as SOCKS5 hostname resolution or `socks5h`) if you want DNS requests to be resolved through the proxy.

The default bind address is `0.0.0.0` so LAN clients can connect. These proxy listeners are not intended to be exposed to the public Internet. Keep the OpenWrt WAN input firewall policy enabled and restrict access to trusted LAN devices. Use proxy authentication if needed.

## Start, stop and inspect from SSH

```sh
warpctl start
warpctl status
warpctl stop
```

View related system logs:

```sh
logread -e usque
logread -e warp
```

Check whether the local proxy ports are listening:

```sh
netstat -lntp 2>/dev/null | grep -E ':32500|:32511' || ss -lntp | grep -E ':32500|:32511'
```

Test the proxies locally on the router:

```sh
curl -x socks5h://127.0.0.1:32500 https://www.cloudflare.com/cdn-cgi/trace
curl -x http://127.0.0.1:32511 https://www.cloudflare.com/cdn-cgi/trace
```

A successful Cloudflare trace should contain:

```text
warp=on
```

If the page or proxy does not work, collect diagnostics before changing the registration:

```sh
echo "===== package ====="
opkg status warp-masque 2>/dev/null || opkg list-installed | grep -i warp

echo "===== UCI ====="
uci show warp

echo "===== processes ====="
ps w | grep -E '[u]sque|[w]arp'

echo "===== listeners ====="
(netstat -lntp 2>/dev/null || ss -lntp) | grep -E ':32500|:32511' || true

echo "===== logs ====="
logread | grep -iE 'warp|usque' | tail -n 100
```

## Build

Push to `main` or manually run **Actions → Build WARP MASQUE IPK**. The workflow builds upstream usque v3.0.1 for Linux amd64, packages the LuCI files and binary into an IPK, checks the archive structure, uploads the artifact, and publishes a versioned release.

- Workflow: [Build WARP MASQUE IPK](https://github.com/mengxianbo/warp-openwrt/actions/workflows/build.yml)
- Releases: [GitHub Releases](https://github.com/mengxianbo/warp-openwrt/releases)

## Scope and security notes

- This is a SOCKS5 and HTTP CONNECT proxy service. It is **not** a router-wide transparent proxy, TUN interface, or automatic default-route takeover.
- SOCKS5 and HTTP proxy traffic between LAN clients and the router is not encrypted by these proxy protocols. Use trusted LANs, firewall restrictions, and proxy authentication as appropriate.
- Do not expose unauthenticated proxy ports to the WAN/public Internet.
- Cloudflare registration, service availability, throughput, and usage policies are controlled by Cloudflare.
- Upstream project/license: [Diniboy1123/usque](https://github.com/Diniboy1123/usque), MIT.

### IPK packaging

Release packages use the native OpenWrt gzip-compressed tar container (`debian-binary`, `control.tar.gz`, and `data.tar.gz`), not a Debian `ar` archive. The CI workflow verifies the outer package structure before publishing.
