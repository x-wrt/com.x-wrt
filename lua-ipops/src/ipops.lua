local function _lshift(a, i)
	return math.floor(a * 2^i)
end

local function _rshift(a, i)
	return math.floor(a / 2^i)
end

local function _band(a, b)
	local r = 0
	for i = 0, 31 do
		if _rshift(a, 31 - i) % 0x2 == 1 and _rshift(b, 31 - i) % 0x2 == 1 then
			r = r * 2 + 1
		else
			r = r * 2
		end
	end
	return r
end

local function _bor(a, b)
	local r = 0
	for i = 0, 31 do
		if _rshift(a, 31 - i) % 0x2 == 1 or _rshift(b, 31 - i) % 0x2 == 1 then
			r = r * 2 + 1
		else
			r = r * 2
		end
	end
	return r
end

local function _bxor(a, b)
	local r = 0
	for i = 0, 31 do
		if _rshift(a, 31 - i) % 0x2 ~= _rshift(b, 31 - i) % 0x2 then
			r = r * 2 + 1
		else
			r = r * 2
		end
	end
	return r
end

local function _bnot(a)
	local r = 0
	for i = 0, 31 do
		if _rshift(a, 31 - i) % 0x2 == 0x0 then
			r = r * 2 + 1
		else
			r = r * 2
		end
	end
	return r
end

local function get_parts_as_number(str)
	local t = {}
	for part in string.gmatch(str, "%d+") do
		table.insert(t, tonumber(part, 10))
	end
	return t
end

-- ipstr: a.b.c.d
local function ipstr2int(ipstr)
	local ip = get_parts_as_number(ipstr)
	if #ip == 4 then
		return (((ip[1] * 0x100 + ip[2]) * 0x100 + ip[3]) * 0x100 + ip[4])
	end
	return 0
end

local function int2ipstr(x)
	local a = _rshift(x, 24) % 0x100
	local b = _rshift(x, 16) % 0x100
	local c = _rshift(x, 8) % 0x100
	local d = _rshift(x, 0) % 0x100
	return string.format("%u.%u.%u.%u", a, b, c, d)
end

-- cidr: n
local function cidr2int(cidr)
	local x = 0
	for i = 0, cidr - 1 do
		x = x + _lshift(1, 31 - i)
	end
	return x
end

local function int2cidr(x)
	for i = 0, 31 do
		if _band(x, _lshift(1, 31 - i)) == 0 then
			return i
		end
	end
	return 32
end

local function cidr2maskstr(cidr)
	return int2ipstr(cidr2int(cidr))
end

local function maskstr2cidr(maskstr)
	return int2cidr(ipstr2int(maskstr))
end

-- ipaddr: a.b.c.d, a.b.c.d/cidr
-- return ip_int, mask_int
local function get_ip_and_mask(ipaddr)
	local n = get_parts_as_number(ipaddr)
	return (((n[1] * 256 + n[2]) * 256 + n[3]) * 256 + n[4]), cidr2int(n[5] or 0)
end

-- return ip_str, mask_str
local function get_ipstr_and_maskstr(ipaddr)
	local ip, mask = get_ip_and_mask(ipaddr)
	return int2ipstr(ip), int2ipstr(mask)
end

-- netstr: ipaddr, a.b.c.d-e.f.g.h, a.b.c.d/m1.m2.m3.m4
-- return: range: [n1, n2] where n1 <= n2
local function netstr2range(netstr)
	ip = get_parts_as_number(netstr)
	if #ip == 4 then
		local i = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		return {i, i}
	end

	if #ip == 5 and ip[5] >= 0 and ip[5] <= 32 then
		local i = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		local m = cidr2int(ip[5])
		local s = _band(i, m)
		local e = _bor(i, _bnot(m))
		return {s, e}
	end

	if #ip == 8 then
		local i = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		local m = (((ip[5] * 256 + ip[6]) * 256 + ip[7]) * 256 + ip[8])
		if netstr:match('/') then
			local s = _band(i, m)
			local e = _bor(i, _bnot(m))
			if s <= e then
				return {s, e}
			end
		else
			if i <= m then
				return {i, m}
			end
		end
	end

	return nil
end

local function range2netstr(range)
	if range[1] <= range[2] then
		return int2ipstr(range[1]) .. "-" .. int2ipstr(range[2])
	end
	return nil
end

-- ipgroup: [range, ...]
local function ipgroup_add_netstr(ipgroup, netstr)
	local range = netstr2range(netstr)
	if not range then
		return ipgroup
	end

	ipgroup = ipgroup or {}
	if #ipgroup == 0 then
		table.insert(ipgroup, range)
		return ipgroup
	end

	local ipgroup_new = {}
	for _, r in ipairs(ipgroup) do
		if range[1] < r[1] then
			if range[2] < r[1] then
				table.insert(ipgroup_new, range)
				range = r
			elseif range[2] >= r[1] and range[2] <= r[2] then
				range = {range[1], r[2]}
			end
		elseif range[1] >= r[1] and range[1] <= r[2] then
			if range[2] <= r[2] then
				range = {r[1], r[2]}
			elseif range[2] > r[2] then
				range = {r[1], range[2]}
			end
		else
			table.insert(ipgroup_new, r)
		end
	end
	table.insert(ipgroup_new, range)

	return ipgroup_new
end

-- ipranges: [netstr, ...]
local function ipranges2ipgroup(ipranges)
	local ipgroup = {}
	for _, netstr in ipairs(ipranges) do
		ipgroup = ipgroup_add_netstr(ipgroup, netstr)
	end
	return ipgroup
end

local function ipgroup2ipranges(ipgroup)
	local ipranges = {}
	for _, range in ipairs(ipgroup) do
		table.insert(ipranges, string.format("%s-%s", int2ipstr(range[1]), int2ipstr(range[2])))
	end
	return ipranges
end

--[[
local ipranges = {
	"1.1.1.1-2.2.2.2",
	"192.168.0.0/16",
	"192.168.0.1-192.168.0.2",
	"192.168.255.254-192.169.0.100",
	"172.16.0.1-172.16.0.100",
	"172.168.0.0/255.255.0.0",
}

for _, netstr in ipairs(ipranges) do
	print(netstr, range2netstr(netstr2range(netstr)))
end

local ipgroup = ipranges2ipgroup(ipranges)
for _, r in ipairs(ipgroup) do
	print(r[1], r[2])
end

ipranges = ipgroup2ipranges(ipgroup)
for _, ipstr in ipairs(ipranges) do
	print(ipstr)
end

local ip, mask = get_ipstr_and_maskstr("1.2.3.4/32")
print(ip, mask)
]]

return {
	ipstr2int				= ipstr2int,
	int2ipstr 				= int2ipstr,
	cidr2int 				= cidr2int,
	int2cidr 				= int2cidr,
	cidr2maskstr				= cidr2maskstr,
	maskstr2cidr				= maskstr2cidr,
	get_ip_and_mask				= get_ip_and_mask,
	get_ipstr_and_maskstr			= get_ipstr_and_maskstr,

	lshift 					= _lshift,
	rshift 					= _rshift,

	b32and 					= _band,
	b32or 					= _bor,
	b32xor 					= _bxor,
	b32not 					= _bnot,

	ipranges2ipgroup			= ipranges2ipgroup,
	ipgroup2ipranges			= ipgroup2ipranges,
	ipgroup_add_netstr			= ipgroup_add_netstr,
	netstr2range				= netstr2range,
	range2netstr				= range2netstr,
}
