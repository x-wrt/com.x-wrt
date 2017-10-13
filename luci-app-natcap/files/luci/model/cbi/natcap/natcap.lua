-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local nt = require "luci.sys".net

local m = Map("natcapd", luci.util.pcdata(translate("Natcap 服务")), translate("Natcap 流量免审计"))

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("一般配置"))
s:tab("advanced", translate("高级配置"))
s:tab("macfilter", translate("MAC过滤"))

e = s:taboption("general", Flag, "enabled", translate("启用 Natcap"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Value, "account", translate("Natcap 帐号"))
e.rmempty = true
e.placeholder = 'account'

e = s:taboption("general", DynamicList, "server", translate("Natcap 服务器"), translate("请按照格式填写服务器（ip:port）"))
e.datatype = "list(ipaddrport(1))"
e.placeholder = "1.2.3.4:0"

e = s:taboption("general", Flag, "cnipwhitelist_mode", translate("启用国内国际分流模式"), translate("一般不需要启用，除非用来打游戏。"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Value, "dns_server", translate("DNS 服务器"), translate("请按照格式填写服务器（ip:port）"))
e.datatype = "ipaddrport(1)"
e.placeholder = "8.8.8.8:53"

e = s:taboption("advanced", Flag, "enable_encryption", translate("启用加密"))
e.default = e.enabled
e.rmempty = false

e = s:taboption("advanced", Value, "server_persist_timeout", translate("服务器切换时间（秒）"), translate("多久切换一次服务器。"))
e.default = '60'
e.rmempty = true
e.placeholder = '60'

e = s:taboption("advanced", Value, "natcap_redirect_port", translate("本地TCP监听端口"), translate("0 禁用，其它启用"))
e.datatype = "portrange"
e.rmempty = true
e.placeholder = '0'

e = s:taboption("advanced", Flag, "encode_mode", translate("强制UDP模式"), translate("一般不要启用，除非正常模式不通。"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "sproxy", translate("TCP代理加速"), translate("推荐使用，利用服务器的TCP代理和谷歌BBR算法加速。"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "enable_hosts", translate("自动hosts加速"), translate("尝试使用，使用hosts名单加速可能更快，如果异常请关闭。"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Flag, "http_confusion", translate("启用HTTP混淆"), translate("把流量伪装成HTTP。"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("advanced", Value, "htp_confusion_host", translate("混淆Host"))
e.rmempty = true
e.placeholder = 'bing.com'

e = s:taboption("general", Flag, "pptpd", translate("启用PPTP服务器"), translate("允许你用VPN连接自己的路由器，路由器需要有公网IP。"))
e.default = e.disabled
e.rmempty = false

local u = m:section(TypedSection, "pptpuser", "")
u.addremove = true
u.anonymous = true
u.template = "cbi/tblsection"

e = u:option(Value, "username", translate("PPTP用户"))
e.datatype = "string"
e.rmempty  = false

e = u:option(Value, "password", translate("密码"))
e.datatype = "string"
e.rmempty  = false

e = s:taboption("macfilter", ListValue, "macfilter", translate("MAC地址过滤"))
e:value("", translate("disable"))
e:value("allow", translate("白名单（允许列表使用Natcap）"))
e:value("deny", translate("黑名单（禁止列表使用Natcap）"))

e = s:taboption("macfilter", DynamicList, "maclist", translate("MAC列表"))
e.datatype = "macaddr"
e:depends({macfilter="allow"})
e:depends({macfilter="deny"})
nt.mac_hints(function(mac, name) e:value(mac, "%s (%s)" %{ mac, name }) end)

return m
