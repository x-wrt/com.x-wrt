-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", translate("NATCAP Service"), translate("NATCAP accelerates selected network traffic through proxy servers."))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("General Settings"))
s:tab("advanced", translate("Advanced Settings"))
s:tab("serverlist", translate("Server List"))
s:tab("macfilter", translate("MAC Filter"))
s:tab("ipfilter", translate("IP Filter"))
s:tab("system", translate("System Settings"))
s:tab("bypasslist", translate("Bypass List"))
s:tab("bypasslist_domain", translate("Bypass Domain List"))

e = s:taboption("general", Flag, "enabled", translate("Enable NATCAP"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Value, "account", translate("NATCAP Account"))
e.rmempty = true
e.placeholder = 'account'

e = s:taboption("serverlist", DynamicList, "server", translate("NATCAP Servers"), translate("Enter the server in ip:port format."))
e.datatype = "list(string)"
e.placeholder = "1.2.3.4:0"

e = s:taboption("general", ListValue, "cnipwhitelist_mode", translate("Traffic Proxy Mode"))
e.default = "0"
e:value("0", translate("Smart Proxy"))
e:value("1", translate("Proxy All International Traffic"))
e:value("2", translate("Custom Proxy Rules"))
e.rmempty = false

e = s:taboption("general", Value, "server_persist_timeout", translate("Server Switch Interval (s)"), translate("Interval for automatic server switching."))
e.default = '30'
e.rmempty = true
e.placeholder = '30'

e = s:taboption("general", Flag, "server_persist_lock", translate("Lock Current Server"), translate("Do not switch servers automatically based on link detection."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "enable_encryption", translate("Enable Encryption"))
e.default = e.enabled
e.rmempty = false

e = s:taboption("advanced", Flag, "sproxy", translate("TCP Proxy Acceleration"), translate("Use the server TCP proxy and BBR congestion control for acceleration."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "block_dns6", translate("Block IPv6 DNS"), translate("Block IPv6 DNS requests to prevent DNS poisoning."))
e.default = e.enabled
e.rmempty = false

e = s:taboption("advanced", Value, "dns_server", translate("DNS Server"), translate("Enter the server in ip:port format."))
e.datatype = "ip4addrport"
e.placeholder = "8.8.8.8:53"

e = s:taboption("advanced", Flag, "encode_mode", translate("Force TCP Encapsulation over UDP"), translate("Enable only if normal mode does not work."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "udp_encode_mode", translate("Force UDP Encapsulation over TCP"), translate("Enable only if normal mode does not work."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Value, "natcap_redirect_port", translate("Local Server TCP Listen Port"), translate("0 disables this option; any other value enables it."))
e.datatype = "portrange"
e.rmempty = true
e.placeholder = '0'

e = s:taboption("advanced", Value, "natcap_client_redirect_port", translate("Local Client TCP Listen Port"), translate("0 disables this option; any other value enables it."))
e.datatype = "portrange"
e.rmempty = true
e.placeholder = '0'

e = s:taboption("advanced", Flag, "http_confusion", translate("HTTP Obfuscation"), translate("Disguise the traffic into HTTP."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Value, "htp_confusion_host", translate("Obfuscation Host"))
e.rmempty = true
e.placeholder = 'bing.com'

e = s:taboption("macfilter", ListValue, "macfilter", translate("MAC Address Filter"))
e:value("", translate("Disabled"))
e:value("allow", translate("Allowlist (clients allowed to use NATCAP)"))
e:value("deny", translate("Blocklist (clients denied NATCAP)"))

e = s:taboption("macfilter", DynamicList, "maclist", translate("MAC List"))
e.datatype = "macaddr"
nt.mac_hints(function(mac, name) e:value(mac, "%s (%s)" %{ mac, name }) end)

e = s:taboption("ipfilter", ListValue, "ipfilter", translate("IP Address Filter"))
e:value("", translate("Disabled"))
e:value("allow", translate("Allowlist (clients allowed to use NATCAP)"))
e:value("deny", translate("Blocklist (clients denied NATCAP)"))

e = s:taboption("ipfilter", DynamicList, "iplist", translate("IP List"))
e.datatype = "ipaddr"
e.placeholder = '192.168.1.0/24'

e = s:taboption("system", Flag, "access_to_cn", translate("Access China from Overseas"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Value, "config_version", translate("Config Version"))
e.rmempty = true

e = s:taboption("system", Flag, "full_proxy", translate("Proxy All Traffic"), translate("Send all traffic through the proxy."))
e.default = e.disabled
e.rmempty = false

local speed_validate = function(self, value)
	if not value or value == 0 or value == "0" then
		return value
	end

	local i, j
	local v

	i, j = value:find("Kbps$") or value:find("kbps$")
	if i then
		v = tonumber(value:sub(0, i - 1))
		if not v then
			return nil, translate("Invalid rate limit")
		end
		value = v .. "Kbps"
		return value
	end

	i, j = value:find("Mbps$") or value:find("mbps$")
	if i then
		v = tonumber(value:sub(0, i - 1))
		if not v then
			return nil, translate("Invalid rate limit")
		end
		value = v .. "Mbps"
		return value
	end

	i, j = value:find("Gbps$") or value:find("gbps$")
	if i then
		v = tonumber(value:sub(0, i - 1))
		if not v then
			return nil, translate("Invalid rate limit")
		end
		value = v .. "Gbps"
		return value
	end

	return nil, translate("Invalid rate limit")
end

e = s:taboption("system", Value, "rx_speed_limit", translate("Download Rate Limit"), translate("Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code>. Example: 10Mbps, or 0 for no limit."))
e.placeholder = '0Mbps'
e.rmempty = true
e.validate = speed_validate

e = s:taboption("system", Value, "tx_speed_limit", translate("Upload Rate Limit"), translate("Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code>. Example: 10Mbps, or 0 for no limit."))
e.placeholder = '0Mbps'
e.rmempty = true
e.validate = speed_validate

e = s:taboption("system", Flag, "peer_sni_ban", translate("Disable Remote Manager"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Flag, "peer_mode", translate("Peer Mode"), translate("Enable only if normal mode does not work."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Value, "ui", translate("UI Mode"))
e.rmempty = true
e.placeholder = 'none'

e = s:taboption("bypasslist", DynamicList, "bypasslist", translate("Bypass List"))
e.datatype = "list(string)"
e.placeholder = "1.2.3.4"

e = s:taboption("bypasslist_domain", DynamicList, "bypasslist_domain", translate("Bypass Domain List"))
e.datatype = "list(string)"
e.placeholder = "example.com"

return m
