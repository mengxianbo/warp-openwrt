local fs = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("warp", translate("Cloudflare WARP MASQUE 代理"), translate("基于 MASQUE / Connect-IP 协议的 WARP 代理。此插件不使用 WireGuard。首次使用请先注册设备。"))
s = m:section(NamedSection, "main", "warp", translate("基本设置"))
s.addremove = false

enabled = s:option(Flag, "enabled", translate("启用代理服务"))
enabled.default = "0"
enabled.rmempty = false

bind = s:option(Value, "bind", translate("监听地址"))
bind.default = "0.0.0.0"
bind.description = translate("默认监听所有接口供局域网设备使用。请保持 WAN 入站防火墙关闭，不要将无加密代理端口暴露到公网。")

socks = s:option(Value, "socks_port", translate("SOCKS5 代理端口"))
socks.datatype = "port"
socks.default = "32500"

http = s:option(Value, "http_port", translate("HTTP CONNECT 代理端口"))
http.datatype = "port"
http.default = "32511"

user = s:option(Value, "username", translate("代理用户名（可选）"))
user.rmempty = true

pass = s:option(Value, "password", translate("代理密码（可选）"))
pass.password = true
pass.rmempty = true

status = m:section(SimpleSection)
reg = status:option(Button, "_register", translate("注册 WARP 设备"))
reg.inputtitle = translate("注册 WARP 设备")
reg.inputstyle = "apply"
function reg.write(self, section)
	sys.call("mkdir -p /etc/usque; chmod 700 /etc/usque; /usr/bin/warpctl register >/tmp/warp-register.log 2>&1 &")
end

enroll = status:option(Button, "_enroll", translate("重新注册 MASQUE 密钥"))
enroll.inputtitle = translate("重新注册")
enroll.inputstyle = "reload"
function enroll.write(self, section)
	sys.call("/usr/bin/warpctl enroll >/tmp/warp-enroll.log 2>&1 &")
end

start = status:option(Button, "_start", translate("启动代理"))
start.inputtitle = translate("启动")
start.inputstyle = "apply"
function start.write(self, section)
	sys.call("/usr/bin/warpctl start >/tmp/warp-start.log 2>&1")
end

stop = status:option(Button, "_stop", translate("停止代理"))
stop.inputtitle = translate("停止")
stop.inputstyle = "reset"
function stop.write(self, section)
	sys.call("/usr/bin/warpctl stop")
end

log = status:option(DummyValue, "_log", translate("注册日志（/tmp/warp-register.log）"))
log.rawhtml = false
log.default = translate("注册后可通过 SSH 查看：cat /tmp/warp-register.log")

return m
