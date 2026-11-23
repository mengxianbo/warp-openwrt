# WARP MASQUE for OpenWrt

OpenWrt LuCI package for Cloudflare WARP **MASQUE / Connect-IP** using [usque](https://github.com/Diniboy1123/usque). This project does not include WireGuard.

## Target

- OpenWrt 23.05.5
- x86_64
- SOCKS5: `0.0.0.0:32500` by default
- HTTP CONNECT proxy: `0.0.0.0:32511` by default
- Chinese LuCI configuration page
- GitHub Actions builds an installable IPK and attaches it to a GitHub Release

The package embeds a statically linked Go `usque` binary. It starts SOCKS5 and HTTP proxy modes as separate supervised procd services, sharing one MASQUE registration/configuration.

## Install

Download the IPK from the latest GitHub Release, copy it to the router, then run:

```sh
opkg update
opkg install /tmp/warp-masque_*_x86_64.ipk
```

Open **LuCI → Services → WARP MASQUE**.

## First-time registration

On the LuCI page, click **注册 WARP 设备**. Registration requires Internet access from the router and may be rate-limited by Cloudflare. Wait for the command to finish, then start/restart the service.

CLI alternative:

```sh
warpctl register
warpctl start
warpctl status
```

The registration file is stored at `/etc/usque/config.json` with restrictive permissions. Back it up securely if you need to migrate the registered device. Do not publish it.

## Configure clients

- SOCKS5: router-LAN-IP, port 32500
- HTTP proxy: router-LAN-IP, port 32511

Ports and bind address can be changed on the LuCI page. The default bind address is `0.0.0.0` so LAN clients can connect. OpenWrt's default WAN input firewall policy should remain enabled; do not expose these unauthenticated proxy ports to the Internet. Set a username and password in LuCI if authentication is needed.

## Diagnostics

```sh
warpctl status
logread -e usque
curl -x socks5h://127.0.0.1:32500 https://www.cloudflare.com/cdn-cgi/trace
curl -x http://127.0.0.1:32511 https://www.cloudflare.com/cdn-cgi/trace
```

A successful trace should report `warp=on`. The SOCKS5 `socks5h` scheme delegates DNS resolution through the proxy.

## Build

Push to `main` or manually run **Actions → Build WARP MASQUE IPK**. The workflow builds upstream usque v3.0.1 for Linux amd64, packages the LuCI files and binary into an IPK, checks the archive structure, uploads the artifact, and publishes a versioned release.

## Notes

- This is a proxy service, not a router-wide transparent gateway or TUN route takeover.
- SOCKS5 and HTTP proxy traffic between LAN clients and the router is not encrypted by these proxy protocols. Use only on trusted LANs or enable proxy authentication.
- Cloudflare account registration, availability, throughput and policy are controlled by Cloudflare.
- Upstream project/license: [Diniboy1123/usque](https://github.com/Diniboy1123/usque), MIT.

### IPK packaging

Release packages use the native OpenWrt gzip-compressed tar container (`debian-binary`, `control.tar.gz`, and `data.tar.gz`), not a Debian `ar` archive. The CI workflow verifies the outer package structure before publishing.
