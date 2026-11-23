local sys = require "luci.sys"
local fs = require "nixio.fs"

-- Compatibility guard retained from the Build #20 baseline.
local original_cbid = AbstractValue.cbid
function AbstractValue.cbid(self, section)
	if section == nil then
		local parent = self.section
		if type(parent) == "table" then
			section = parent.section
		end
	end

	if section == nil then
		error("WARP CBI: missing UCI section for option " .. tostring(self.option))
	end

	return original_cbid(self, section)
end

local CONFIG = "/etc/usque/config.json"
local REGISTER_LOG = "/tmp/warp-register.log"
local ENROLL_LOG = "/tmp/warp-enroll.log"

local function read_file(path, fallback)
	local f = io.open(path, "r")
	if not f then
		return fallback
	end
	local value = f:read("*a") or ""
	f:close()
	if value == "" then
		return fallback
	end
	return value
end

local m = Map("warp",
	translate("Cloudflare WARP MASQUE 代理"),
	translate("基于 MASQUE / Connect-IP 协议的 WARP 代理。此插件不使用 WireGuard。首次使用请先注册设备。"))

local s = m:section(NamedSection, "main", "warp", translate("基本设置"))
s.addremove = false

local enabled = s:option(Flag, "enabled", translate("启用代理服务"))
enabled.default = "0"
enabled.rmempty = false

local bind = s:option(Value, "bind", translate("监听地址"))
bind.default = "0.0.0.0"
bind.description = translate("默认监听所有接口供局域网设备使用。请保持 WAN 入站防火墙关闭，不要将无加密代理端口暴露到公网。")

local socks = s:option(Value, "socks_port", translate("SOCKS5 代理端口"))
socks.datatype = "port"
socks.default = "32500"

local http = s:option(Value, "http_port", translate("HTTP CONNECT 代理端口"))
http.datatype = "port"
http.default = "32511"

local user = s:option(Value, "username", translate("代理用户名（可选）"))
user.rmempty = true

local pass = s:option(Value, "password", translate("代理密码（可选）"))
pass.password = true
pass.rmempty = true

local reg_state = s:option(DummyValue, "_register_state", translate("WARP 注册状态"))
reg_state.rawhtml = false
function reg_state.cfgvalue(self, section)
	if fs.stat(CONFIG) and fs.stat(CONFIG).size and fs.stat(CONFIG).size > 0 then
		return translate("已注册：检测到设备配置。重复点击注册不会创建新设备。")
	end
	return translate("尚未注册：请点击“注册 WARP 设备”。")
end

local reg = s:option(Button, "_register", translate("注册 WARP 设备"))
reg.inputtitle = translate("注册 WARP 设备")
reg.inputstyle = "apply"
function reg.write(self, section)
	-- Run synchronously: wait for usque to finish and retain stdout/stderr.
	local rc = sys.call("/usr/bin/warpctl register >" .. REGISTER_LOG .. " 2>&1")
	local f = io.open(REGISTER_LOG, "a")
	if f then
		f:write("\nLuCI 注册操作退出码：", tostring(rc), "\n")
		f:close()
	end
end

local result = s:option(DummyValue, "_register_result", translate("注册结果 / 错误详情"))
result.rawhtml = false
function result.cfgvalue(self, section)
	return read_file(REGISTER_LOG, translate("尚无注册记录。请点击“注册 WARP 设备”开始注册。"))
end

local enroll = s:option(Button, "_enroll", translate("重新注册 MASQUE 密钥"))
enroll.inputtitle = translate("重新注册")
enroll.inputstyle = "reload"
function enroll.write(self, section)
	sys.call("/usr/bin/warpctl enroll >" .. ENROLL_LOG .. " 2>&1")
end

local start = s:option(Button, "_start", translate("启动代理"))
start.inputtitle = translate("启动")
start.inputstyle = "apply"
function start.write(self, section)
	sys.call("/usr/bin/warpctl start >/tmp/warp-start.log 2>&1")
end

local stop = s:option(Button, "_stop", translate("停止代理"))
stop.inputtitle = translate("停止")
stop.inputstyle = "reset"
function stop.write(self, section)
	sys.call("/usr/bin/warpctl stop")
end

return m
