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
function nets_validate(nets)
{
	var re_ip = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
	var re_ip_cidr = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/([0-9]|1[0-9]|2[0-9]|3[012])$/
	var re_ip_range = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
	var net = nets.split(',');
	for (i = 0; i < net.length; i++) {
		if (net[i].match(re_ip)) continue;
		if (net[i].match(re_ip_cidr)) continue;
		if (net[i].match(re_ip_range) && ip_range_validate(net[i])) continue;
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
	for (i = 0; i < net.length; i++) {
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

		m = new form.Map('natflow', [_('QoS traffic shaping')]);

		s = m.section(form.GridSection, 'qos', _('QoS rules'),
				_('Set traffic control for traffic groups that meet the conditions, and share a bandwidth limitation rule within the same group. Multiple rules can be added and matched in order of priority until a match is successful.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.sortable = true;

		o = s.option(form.Value, 'proto', _('Protocol'))
		o.default = '';
		o.rmempty = true;
		o.value('', 'TCP and UDP');
		o.value('tcp', 'TCP');
		o.value('udp', 'UDP');

		o = s.option(form.Value, 'user', _('User IP'),
			_('Can be a single or multiple ipaddr(s)(/cidr) or iprange, split with comma (e.g. "192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111") without quotes'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.15.2-192.168.15.254'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'user_port', _('User Port'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '80,443,10000-20000'
		o.validate = function(section_id, value) {
			return value == '' || ports_validate(value);
		}

		o = s.option(form.Value, 'remote', _('Remote IP'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '123.123.1.3/29'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'remote_port', _('Remote Port'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '80,443,10000-20000'
		o.validate = function(section_id, value) {
			return value == '' || ports_validate(value);
		}

		o = s.option(form.Value, 'rx_rate', _('Download rate limit'), _('Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code> Example: 10Mbps or 0 = no limit'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Value, 'tx_rate', _('Upload rate limit'), _('Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code> Example: 10Mbps or 0 = no limit'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Flag, 'disabled', _('Enable'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		s = m.section(form.GridSection, 'qos_simple', _('Simple QoS rules'),
				_('Set traffic control rules for specific IP users, where multiple rules can be added. Each matched IP user is subject to traffic control based on the bandwidth limits set in the rules.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.sortable = true;

		o = s.option(form.Value, 'user', _('User IP'),
			_('Can be a single or multiple ipaddr(s)(/cidr) or iprange, split with comma (e.g. "192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111") without quotes'));
		o.default = '';
		o.rmempty = true;
		o.placeholder = '192.168.15.2-192.168.15.254'
		o.validate = function(section_id, value) {
			return value == '' || nets_validate(value);
		}

		o = s.option(form.Value, 'rx_rate', _('Download rate limit'), _('Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code> Example: 10Mbps or 0 = no limit'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Value, 'tx_rate', _('Upload rate limit'), _('Unit: <code>Kbps</code> <code>Mbps</code> <code>Gbps</code> Example: 10Mbps or 0 = no limit'));
		o.default = '0Mbps';
		o.rmempty = true;
		o.placeholder = '0Mbps'
		o.validate = function(section_id, value) {
			return value == '' || value == "0" || speed_validate(value);
		}

		o = s.option(form.Flag, 'disabled', _('Enable'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		return m.render();
	}
});
