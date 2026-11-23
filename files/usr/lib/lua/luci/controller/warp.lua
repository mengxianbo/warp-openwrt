module("luci.controller.warp", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/warp") then
		return
	end
	local page = entry({"admin", "services", "warp"}, cbi("warp/main"), _("WARP MASQUE"), 80)
	page.dependent = true
end
