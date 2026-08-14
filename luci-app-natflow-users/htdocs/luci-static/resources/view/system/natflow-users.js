'use strict';
'require view';
'require poll';
'require rpc';
'require network';
'require uci';
'require form';
'require validation';

var callLuciGetUsers = rpc.declare({
	object: 'luci.natflow',
	method: 'get_mac_users',
	expect: { result: [] }
});

var pollInterval = 5;

function ip_range_validate(range)
{
	var dot = range.replace('-', '.');
	var d = dot.split('.');
	return (((((((+d[0])*256)+(+d[1]))*256)+(+d[2]))*256)+(+d[3])) <= (((((((+d[4])*256)+(+d[5]))*256)+(+d[6]))*256)+(+d[7]));
}

function ipv4_validate(addr)
{
	return validation.parseIPv4(addr) !== null;
}

function ipv6_validate(addr)
{
	return validation.parseIPv6(addr) !== null;
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
	return true;
}

return view.extend({
	load: function() {
		return Promise.all([
			network.getHostHints(),
			L.resolveDefault(callLuciGetUsers(), []),
			uci.load('natflow'),
			L.require('view.natflow-users')
		]);
	},

	poll_status: function(nodes, data) {
		var hosts = data[0];
		var users = Array.isArray(data[1]) ? data[1] : [];
		var users_ui = data[2];
		var table = nodes.querySelector('#natflow-users');

		users_ui.updateUserTable(table, hosts, users);
	},

	render: function(data) {
		var m, s, o;
		var hosts = data[0];
		var users = Array.isArray(data[1]) ? data[1] : [];
		var users_ui = data[3];
		this.users_ui = users_ui;

		m = new form.Map('natflow', [_('User Access Control')]);

		s = m.section(form.GridSection, '_active_users');

		s.render = L.bind(function() {
			return E('div', { 'class': 'cbi-section cbi-tblsection' }, [
				E('h3', _('Active Users')),
				users_ui.renderUserTable(hosts, users)
			]);
		}, this);

		s = m.section(form.GridSection, 'auth', _('User IP ranges'), _('Clients in these IP ranges are managed as users.'));
		s.addremove = false;
		s.anonymous = true;
		s.nodescriptions = true;
		s.sortable = false;

		o = s.option(form.TextValue, 'sipgrp', _('Client IP ranges'),
			_('Enter one or more IPv4 or IPv6 addresses, CIDR ranges, or IPv4 address ranges, separated by commas. Example: 192.168.100.0/24,2001:db8::/64,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.rmempty = false;
		o.placeholder = '192.168.15.2-192.168.15.254,2001:db8::/64';
		o.validate = function(section_id, value) {
			return nets_validate(value);
		};

		return m.render().then(L.bind(function(m, nodes) {
			poll.add(L.bind(function() {
				return Promise.all([
					network.getHostHints(),
					callLuciGetUsers(),
					this.users_ui
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), pollInterval);
			return nodes;
		}, this, m));
	}
});
