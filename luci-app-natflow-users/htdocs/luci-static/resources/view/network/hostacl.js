'use strict';
'require view';
'require dom';
'require poll';
'require request';
'require rpc';
'require network';
'require uci';
'require form';
'require validation';

var callHostHints;

callHostHints = rpc.declare({
	object: 'luci-rpc',
	method: 'getHostHints',
	expect: { '': {} }
});

function ip_range_validate(range)
{
	var dot = range.replace('-', '.');
	var d = dot.split('.');
	return (((((((+d[0])*256)+(+d[1]))*256)+(+d[2]))*256)+(+d[3])) <= (((((((+d[4])*256)+(+d[5]))*256)+(+d[6]))*256)+(+d[7]));
}

function ipv4_validate(addr)
{
	var re_ip = /^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$/;

	return re_ip.test(addr);
}

function ipv6_validate(addr)
{
	var parts, left, right, count;

	if (!addr || addr.indexOf(':::') >= 0)
		return false;

	if (addr.indexOf('::') != addr.lastIndexOf('::'))
		return false;

	function count_groups(part) {
		var groups, n = 0;

		if (part == '')
			return 0;

		groups = part.split(':');

		for (var i = 0; i < groups.length; i++) {
			if (groups[i] == '')
				return -1;

			if (groups[i].indexOf('.') >= 0) {
				if (i != groups.length - 1 || !ipv4_validate(groups[i]))
					return -1;
				n += 2;
			}
			else if (!/^[0-9a-fA-F]{1,4}$/.test(groups[i])) {
				return -1;
			}
			else {
				n++;
			}
		}

		return n;
	}

	parts = addr.split('::');

	if (parts.length == 1)
		return count_groups(addr) == 8;

	left = count_groups(parts[0]);
	right = count_groups(parts[1]);
	count = left + right;

	return left >= 0 && right >= 0 && count < 8;
}

function ipv4_token_validate(token)
{
	var parts, addr, prefix, re_ip_range;

	token = token.trim();

	if (token == '')
		return false;

	parts = token.split('/');

	if (parts.length > 2 || parts[0] == '')
		return false;

	addr = parts[0];

	if (parts.length == 2) {
		prefix = +parts[1];

		if (!/^\d+$/.test(parts[1]))
			return false;

		if (ipv4_validate(addr))
			return prefix >= 0 && prefix <= 32;

		return false;
	}

	re_ip_range = /^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])-(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$/;

	return ipv4_validate(addr) || (re_ip_range.test(addr) && ip_range_validate(addr));
}

function ipv6_cidr_token_validate(token)
{
	var parts, prefix;

	token = token.trim();

	if (token == '')
		return false;

	parts = token.split('/');

	if (parts.length != 2 || parts[0] == '' || parts[1] == '')
		return false;

	if (!ipv6_validate(parts[0]) || !/^\d+$/.test(parts[1]))
		return false;

	prefix = +parts[1];

	return prefix >= 0 && prefix <= 128;
}

function nets_validate(nets, token_validate)
{
	var net = nets.split(',');
	for (var i = 0; i < net.length; i++) {
		if (token_validate(net[i])) continue;
		return false;
	}
	return true
}

function calculateNetwork(addr, mask) {
	addr = validation.parseIPv4(String(addr));

	if (!isNaN(mask))
		mask = validation.parseIPv4(network.prefixToMask(+mask));
	else
		mask = validation.parseIPv4(String(mask));

	if (addr == null || mask == null)
		return null;

	return [
		[
			addr[0] & (mask[0] >>> 0 & 255),
			addr[1] & (mask[1] >>> 0 & 255),
			addr[2] & (mask[2] >>> 0 & 255),
			addr[3] & (mask[3] >>> 0 & 255)
		].join('.'),
		mask.join('.')
	];
}

function isValidMAC(sid, s) {
	if (!s)
		return true;

	let macaddrs = L.toArray(s);

	for (var i = 0; i < macaddrs.length; i++)
		if (!macaddrs[i].match(/^(([0-9a-f]{1,2}|\*)[:-]){5}([0-9a-f]{1,2}|\*)$/i))
			return _('Enter a valid MAC address. Wildcards are allowed.') + ' ' + _('Invalid MAC: %s').format(macaddrs[i]);

	return true;
}

function expandAndFormatMAC(macs) {
	let result = [];

	macs.forEach(mac => {
		if (isValidMAC(mac)) {
			const expandedMac = mac.split(':').map(part => {
				return (part.length === 1 && part !== '*') ? '0' + part : part;
			}).join(':').toUpperCase();
			result.push(expandedMac);
		}
	});

	return result.length ? result.join(' ') : null;
}

return view.extend({
	load: function() {
		return Promise.all([
			callHostHints(),
			uci.load('hostacl')
		]);
	},

	render: function(data) {
		var hosts = data[0];
		var m, s, o;

		m = new form.Map('hostacl', [_('Web Access Control')],
				_('Control which websites selected clients can access.'));

		s = m.section(form.NamedSection, '@main[0]', 'main');
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.enabled = '1';
		o.disabled = '0';
		o.default = o.disabled;

		s = m.section(form.GridSection, 'rule', _('Access control rules'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;
		s.sortable = true;
		s.max_cols = 3;

		o = s.option(form.TextValue, 'host', _('Domains'), _('Domain names to match, separated by commas.'));
		o.rmempty = false;
		o.placeholder = "baidu.com,qq.com"
		o.default = '';

		o = s.option(form.ListValue, 'action', _('Action'));
		o.rmempty = false;
		o.default = 'reset';
		o.value('record', _('Log only'));
		o.value('drop', _('Drop'));
		o.value('reset', _('Reset connection'));
		o.value('redirect', _('Redirect'));

		o = s.option(form.Flag, 'disabled', _('Enabled'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		o = s.option(form.TextValue, 'ip', _('Client IPv4 addresses'),
			_('Enter one or more IPv4 addresses, IPv4 CIDR ranges, or IPv4 address ranges, separated by commas. Example: 192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value, ipv4_token_validate) ||
				_('Enter valid IPv4 addresses, IPv4 CIDR ranges, or IPv4 address ranges separated by commas.');
		}

		o = s.option(form.TextValue, 'ipv6', _('Client IPv6 CIDR ranges'),
			_('Enter one or more IPv6 CIDR ranges separated by commas. Example: 2001:db8::/64,fd00::/8'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '2001:db8::/64,fd00::/8'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value, ipv6_cidr_token_validate) ||
				_('Enter valid IPv6 CIDR ranges separated by commas.');
		}

		o = s.option(form.DynamicList, 'mac', _('Client MAC addresses'));
		o.rmempty = true;
		o.cfgvalue = function(section) {
			var macs = L.toArray(uci.get('hostacl', section, 'mac'));
			return expandAndFormatMAC(macs);
		};
		o.validate = isValidMAC;
		Object.keys(hosts).forEach(function(mac) {
			var hint = hosts[mac].name || L.toArray(hosts[mac].ipaddrs || hosts[mac].ipv4)[0];
			o.value(mac, hint ? '%s (%s)'.format(mac, hint) : mac);
		});

		return m.render();
	}
});
