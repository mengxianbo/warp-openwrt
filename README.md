# OpenWrt Cloudflare WARP MASQUE 插件

本项目基于 **Build #20** 的源码进行修复，不混入后续 1.1.x 分支的其他功能改动。

- 基础提交：b15594c87cb0e0c77e17e13f4ee52bf88992a79e
- 当前修复版本：**warp-masque 1.0.1-1**
- 目标平台：**OpenWrt 23.05.5 / x86_64**

## 1. 功能说明

- 使用 Cloudflare WARP **MASQUE / Connect-IP** 协议，底层客户端为 usque，不使用 WireGuard。
- SOCKS5 默认端口：**32500**。
- HTTP CONNECT 默认端口：**32511**。
- 提供中文 LuCI 管理界面，可修改监听地址、端口和代理认证设置。
- GitHub Actions 自动编译 IPK 并发布 Release。

### 本次基于 Build #20 的注册修复

1. 用户主动点击 LuCI「注册 WARP 设备」后，后台自动向 usque 输入 y，确认 Cloudflare 服务条款。
2. 注册操作同步执行，LuCI 等待注册命令结束，不再把交互式命令丢到后台导致无人应答。
3. 注册结束后页面重新读取注册状态和日志。
4. 注册失败时，页面显示 usque 输出、错误原因及退出码；SSH 日志位于 /tmp/warp-register.log。
5. 如果 /etc/usque/config.json 已存在，注册命令会提示已注册并跳过，不会重复创建设备。
6. 增加注册锁，避免用户连续点击时并发发起注册。

自动确认条款只会在用户明确点击注册按钮或手动执行 warpctl register 时发生；安装、升级和启动服务都不会自动注册。

## 2. 全新安装（OpenWrt x86_64）

使用 SSH 以 root 登录 OpenWrt，复制执行以下完整命令：

~~~sh
set -e

echo "===== 1. 检查系统架构 ====="
[ "$(uname -m)" = "x86_64" ] || {
    echo "错误：此安装包仅支持 x86_64"
    exit 1
}

echo
echo "===== 2. 下载 Build #20 基础修复版 ====="
cd /tmp
wget -O warp-masque_1.0.1-1_x86_64.ipk \
  https://github.com/mengxianbo/warp-openwrt/releases/latest/download/warp-masque_1.0.1-1_x86_64.ipk

echo
echo "===== 3. 检查安装包 ====="
ls -lh /tmp/warp-masque_1.0.1-1_x86_64.ipk
[ -s /tmp/warp-masque_1.0.1-1_x86_64.ipk ]

echo
echo "===== 4. 安装插件 ====="
opkg install --force-reinstall /tmp/warp-masque_1.0.1-1_x86_64.ipk

echo
echo "===== 5. 清理 LuCI 页面缓存 ====="
rm -f /tmp/luci-indexcache
rm -f /tmp/luci-modulecache/* 2>/dev/null || true

echo
echo "===== 6. 重启 LuCI Web 服务 ====="
/etc/init.d/uhttpd restart

echo
echo "===== 7. 检查插件版本 ====="
opkg status warp-masque | grep -E 'Package|Version'

echo
echo "===== 8. 检查配置和程序 ====="
uci show warp
ls -lh /usr/bin/warpctl /usr/bin/usque

echo
echo "安装完成。下一步请进入 LuCI 注册 WARP 设备。"
~~~

> 注意：以上安装包为 Build #20 基础源码加本次注册修复，版本号为 1.0.1-1。请勿误装其他分支的 1.1.x 包。

## 3. LuCI 首次注册流程

1. 登录 OpenWrt 管理页面。
2. 打开 **服务 → WARP MASQUE**。
3. 点击 **注册 WARP 设备**。
4. 等待注册命令完成。插件会在这次主动操作中自动确认 Cloudflare 服务条款。
5. 页面刷新后查看「WARP 注册状态」和「注册结果 / 错误详情」。
6. 确认显示注册成功后，点击「启动代理」。

如果注册失败，页面的「注册结果 / 错误详情」会显示失败信息。也可以 SSH 查看：

~~~sh
cat /tmp/warp-register.log
~~~

## 4. 命令行注册和启动

首次注册（仅当注册文件不存在时执行）：

~~~sh
warpctl register
warpctl start
warpctl status
~~~

如果注册文件已经存在，不需要再次注册，直接启动：

~~~sh
warpctl start
warpctl status
~~~

查看注册文件和日志：

~~~sh
ls -lh /etc/usque/config.json
cat /tmp/warp-register.log
logread | grep -iE 'warp|usque' | tail -n 100
~~~

## 5. 已安装旧版本的升级方式

升级前不要删除注册文件。执行：

~~~sh
set -e
cd /tmp

wget -O warp-masque_1.0.1-1_x86_64.ipk \
  https://github.com/mengxianbo/warp-openwrt/releases/latest/download/warp-masque_1.0.1-1_x86_64.ipk

opkg install --force-reinstall /tmp/warp-masque_1.0.1-1_x86_64.ipk

rm -f /tmp/luci-indexcache
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/uhttpd restart

opkg status warp-masque | grep -E 'Package|Version'
warpctl status
~~~

升级会覆盖插件程序文件，但不需要重新注册 WARP 设备。请保留以下文件：

- /etc/usque/config.json
- /etc/config/warp

其中 /etc/usque/config.json 含有设备凭据和密钥，不要上传到公开仓库或发给他人。

## 6. 默认代理端口和客户端配置

| 类型 | 默认监听地址 | 默认端口 |
|---|---|---:|
| SOCKS5 | 0.0.0.0 | 32500 |
| HTTP CONNECT | 0.0.0.0 | 32511 |

在 LuCI 页面可以修改监听地址和端口。局域网设备使用 OpenWrt 的 LAN 地址作为代理服务器：

- SOCKS5：路由器LAN地址:32500
- HTTP CONNECT：路由器LAN地址:32511

使用 SOCKS5 时，建议客户端启用远程 DNS 解析模式（例如 socks5h）。

默认监听 0.0.0.0，意味着所有本机接口都可能监听代理端口。请确保 WAN 入站防火墙不允许公网访问；不要把未加密、未认证的代理端口暴露到互联网。

## 7. 代理测试

在 OpenWrt SSH 中执行：

~~~sh
echo "===== SOCKS5 测试 ====="
curl -x socks5h://127.0.0.1:32500 https://www.cloudflare.com/cdn-cgi/trace

echo
echo "===== HTTP CONNECT 测试 ====="
curl -x http://127.0.0.1:32511 https://www.cloudflare.com/cdn-cgi/trace
~~~

成功时，Cloudflare trace 应包含：

~~~text
warp=on
~~~

检查监听端口：

~~~sh
(netstat -lntp 2>/dev/null || ss -lntp) | grep -E ':32500|:32511' || true
~~~

## 8. 故障诊断

请收集以下信息，不要先删除注册配置或重复注册：

~~~sh
echo "===== 插件版本 ====="
opkg status warp-masque | grep -E 'Package|Version'

echo
echo "===== 注册文件 ====="
ls -lh /etc/usque/config.json 2>&1

echo
echo "===== UCI 配置 ====="
uci show warp

echo
echo "===== 进程 ====="
ps w | grep -E '[u]sque|[w]arp'

echo
echo "===== 端口 ====="
(netstat -lntp 2>/dev/null || ss -lntp) | grep -E ':32500|:32511' || true

echo
echo "===== 注册日志 ====="
cat /tmp/warp-register.log 2>&1

echo
echo "===== 系统日志 ====="
logread | grep -iE 'warp|usque|register|error' | tail -n 100
~~~

## 9. 构建和发布

本修复源码位于 **rollback-build-20** 分支，以 Build #20 的源码为基础，只加入本次注册流程修复及版本号更新。

- GitHub Actions：https://github.com/mengxianbo/warp-openwrt/actions/workflows/build.yml
- GitHub Releases：https://github.com/mengxianbo/warp-openwrt/releases
- Build #20 基础提交：https://github.com/mengxianbo/warp-openwrt/commit/b15594c87cb0e0c77e17e13f4ee52bf88992a79e

向 rollback-build-20 分支推送提交或手动运行 Build WARP MASQUE IPK 工作流，即可构建并发布 IPK。

## 10. 项目范围和安全说明

- 本项目提供 SOCKS5 和 HTTP CONNECT 代理，不是全局透明代理，也不会自动接管路由器默认出口。
- LAN 客户端到路由器代理端口之间的连接不由 SOCKS5/HTTP CONNECT 自动加密。
- 不要向 WAN/公网开放未认证的代理端口。
- Cloudflare 注册、服务可用性、速度和使用限制由 Cloudflare 服务条款决定。
- 上游客户端：Diniboy1123/usque（MIT）：https://github.com/Diniboy1123/usque
