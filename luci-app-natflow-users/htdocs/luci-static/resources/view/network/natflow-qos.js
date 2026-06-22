'use strict';
'require view';
'require dom';
'require poll';
'require request';
'require rpc';
'require network';
'require uci';
'require form';

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

function ip_token_validate(token)
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

		if (ipv6_validate(addr))
			return prefix >= 0 && prefix <= 128;

		return false;
	}

	re_ip_range = /^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])-(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$/;

	return ipv4_validate(addr) || ipv6_validate(addr) || (re_ip_range.test(addr) && ip_range_validate(addr));
}

function nets_validate(nets)
{
	var net = nets.split(',');
	for (var i = 0; i < net.length; i++) {
		if (ip_token_validate(net[i])) continue;
		return false;
	}
	return true
}

function port_range_validate(range)
{
        var d = range.split('-');
	if ((+d[1]) >= (+d[0]) && (+d[0]) >= 0 && (+d[1]) <= 65535) {
		return true;
	}
	return false;
}

function ports_validate(nets)
{
	var re_port_range = /^([0-9]{1,5})-([0-9]{1,5})$/;
	var net = nets.split(',');
	for (var i = 0; i < net.length; i++) {
		if (net[i].match(re_port_range) && port_range_validate(net[i])) continue;
		if (net[i] >= 0 && net[i] <= 65535) continue;
		return false;
	}
	return true
}

function speed_validate(v)
{
	var re = /^\d+[MGK]?bps$/;
	if (v.match(re)) {
		return true;
	}
	return false;
}

return view.extend({
        load: function() {
		return Promise.all([
			uci.load('natflow')
		]);
	},

	render: function(data) {
		var m, s, o;

		m = new form.Map('natflow', [_('Traffic Shaping')]);

		s = m.section(form.GridSection, 'qos', _('Grouped traffic shaping rules'),
				_('Match traffic by protocol, client, remote address, or port. Traffic matching the same rule shares that rule\'s bandwidth limits. Rules are checked in priority order until one matches.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.sortable = true;

		o = s.option(form.Value, 'proto', _('Protocol'))
		o.default = '';
		o.rmempty = true;
		o.value('', _('TCP and UDP'));
		o.value('tcp', 'TCP');
		o.value('udp', 'UDP');

		o = s.option(form.TextValue, 'user', _('Client IP'),
			_('Enter one or more IPv4 or IPv6 addresses, CIDR ranges, or IPv4 address ranges, separated by commas. Example: 192.168.100.0/24,2001:db8::/64,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.15.2-192.168.15.254,2001:db8::/64'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'user_port', _('Client port'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '80,443,10000-20000'
		o.validate = function(section_id, value) {
			return value == '' || ports_validate(value);
		}

		o = s.option(form.TextValue, 'remote', _('Remote IP'),
			_('Enter one or more remote IPv4 or IPv6 addresses, CIDR ranges, or IPv4 address ranges, separated by commas. Example: 123.123.1.3/29,2001:db8:1::/64'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '123.123.1.3/29,2001:db8:1::/64'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'remote_port', _('Remote port'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '80,443,10000-20000'
		o.validate = function(section_id, value) {
			return value == '' || ports_validate(value);
		}

		o = s.option(form.Value, 'rx_rate', _('Download limit'), _('Units: <code>Kbps</code>, <code>Mbps</code>, or <code>Gbps</code>. Example: 10Mbps. Use 0 for no limit.'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Value, 'tx_rate', _('Upload limit'), _('Units: <code>Kbps</code>, <code>Mbps</code>, or <code>Gbps</code>. Example: 10Mbps. Use 0 for no limit.'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Flag, 'disabled', _('Enabled'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		s = m.section(form.GridSection, 'qos_simple', _('Per-client traffic shaping rules'),
				_('Set bandwidth limits for specific client IP addresses or ranges. Each matching client is limited by the rule that matches it.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.sortable = true;

		o = s.option(form.TextValue, 'user', _('Client IP'),
			_('Enter one or more IPv4 or IPv6 addresses, CIDR ranges, or IPv4 address ranges, separated by commas. Example: 192.168.100.0/24,2001:db8::/64,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.15.2-192.168.15.254,2001:db8::/64'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'rx_rate', _('Download limit'), _('Units: <code>Kbps</code>, <code>Mbps</code>, or <code>Gbps</code>. Example: 10Mbps. Use 0 for no limit.'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Value, 'tx_rate', _('Upload limit'), _('Units: <code>Kbps</code>, <code>Mbps</code>, or <code>Gbps</code>. Example: 10Mbps. Use 0 for no limit.'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Flag, 'disabled', _('Enabled'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		return m.render();
	}
});
