local sys = require "luci.sys"
local fs = require "nixio.fs"

-- Compatibility guard for LuCI CBI renderers which may call an option
-- without forwarding its section identifier. AbstractValue instances retain
-- their owning section in self.section; NamedSection retains the UCI name in
-- its own .section field.
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

local register_log = "/tmp/warp-register.log"
local config_file = "/etc/usque/config.json"

local function read_register_log()
	local f = io.open(register_log, "r")
	if not f then
		return translate("尚无注册日志。请点击“注册 WARP 设备”开始注册。")
	end
	local content = f:read("*a") or ""
	f:close()
	if content == "" then
		return translate("注册日志为空。")
	end
	return content
end

local m = Map("warp",
	translate("Cloudflare WARP MASQUE 代理"),
	translate("基于 MASQUE / Connect-IP 协议的 WARP 代理。使用专用系统用户和 IPv4/IPv6 策略路由隔离其他代理；main 路由表无路由时阻断，避免代理回环。main 默认路由应指向物理 WAN。首次使用请先注册设备。"))

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

local isolation = s:option(DummyValue, "_isolation", translate("代理隔离"))
isolation.rawhtml = false
isolation.default = translate("WARP 使用独立 UID warp；策略优先级 90 走 main 表，优先级 91 在 main 无路由时阻断。查看详情：warpctl status")

local reg_state = s:option(DummyValue, "_register_state", translate("WARP 注册状态"))
reg_state.rawhtml = false
function reg_state.cfgvalue(self, section)
	if fs.access(config_file) then
		return translate("已检测到注册配置。重复点击注册不会创建新设备。")
	end
	return translate("尚未注册。点击下方按钮开始注册。")
end

local reg = s:option(Button, "_register", translate("注册 WARP 设备"))
reg.inputtitle = translate("注册 WARP 设备")
reg.inputstyle = "reload"
function reg.write(self, section)
	-- This is a synchronous CBI action: wait for usque to finish so the page
	-- reloads with the actual result rather than leaving an orphaned prompt.
	local rc = sys.call("/usr/bin/warpctl register >" .. register_log .. " 2>&1")
	local f = io.open(register_log, "a")
	if f then
		f:write("\nLuCI 注册操作退出码：", tostring(rc), "\n")
		f:close()
	end
end

local register_log_view = s:option(DummyValue, "_register_log", translate("注册结果 / 错误详情"))
register_log_view.rawhtml = false
function register_log_view.cfgvalue(self, section)
	return read_register_log()
end

local enroll = s:option(Button, "_enroll", translate("重新注册 MASQUE 密钥"))
enroll.inputtitle = translate("重新注册")
enroll.inputstyle = "reload"
function enroll.write(self, section)
	sys.call("/usr/bin/warpctl enroll >/tmp/warp-enroll.log 2>&1")
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
