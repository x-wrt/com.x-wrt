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
function nets_validate(nets)
{
	var re_ip = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
	var re_ip_cidr = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/([0-9]|1[0-9]|2[0-9]|3[012])$/
	var re_ip_range = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
	var net = nets.split(',');
	for (var i = 0; i < net.length; i++) {
		if (net[i].match(re_ip)) continue;
		if (net[i].match(re_ip_cidr)) continue;
		if (net[i].match(re_ip_range) && ip_range_validate(net[i])) continue;
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
			_('Enter one or more IPv4 addresses, CIDR ranges, or IP ranges, separated by commas. Example: 192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.15.2-192.168.15.254'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.TextValue, 'ipv6', _('Client IPv6 addresses'));
		o.default = '';
		o.rmempty = true;

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
