'use strict';
'require view';
'require dom';
'require poll';
'require request';
'require rpc';
'require network';
'require uci';
'require form';

var callLuciGetUsers = rpc.declare({
	object: 'luci.natflow',
	method: 'get_users',
	expect: { result: [] }
});

var callKickUser = rpc.declare({
        object: 'luci.natflow',
        method: 'kick_user',
        params: [ 'token' ],
        expect: { result : "OK" },
});

var callBlockUser = rpc.declare({
        object: 'luci.natflow',
        method: 'block_user',
        params: [ 'token' ],
        expect: { result : "OK" },
});

var callAllowUser = rpc.declare({
        object: 'luci.natflow',
        method: 'allow_user',
        params: [ 'token' ],
        expect: { result : "OK" },
});

var handleKickUser = function(num, ev) {
        dom.parent(ev.currentTarget, '.tr').style.opacity = 0.5;
        ev.currentTarget.classList.add('spinning');
        ev.currentTarget.disabled = true;
        ev.currentTarget.blur();
        callKickUser(num);
};

var handleBlockUser = function(num, ev) {
        dom.parent(ev.currentTarget, '.tr').style.opacity = 0.5;
        ev.currentTarget.classList.add('spinning');
        ev.currentTarget.disabled = true;
        ev.currentTarget.blur();
        callBlockUser(num);
};

var handleAllowUser = function(num, ev) {
        dom.parent(ev.currentTarget, '.tr').style.opacity = 0.5;
        ev.currentTarget.classList.add('spinning');
        ev.currentTarget.disabled = true;
        ev.currentTarget.blur();
        callAllowUser(num);
};

var pollInterval = 5;

Math.log2 = Math.log2 || function(x) { return Math.log(x) * Math.LOG2E; };

function rate(n, br) {
	n = (n || 0).toFixed(2);
	return '%1024.2mbit/s (%1024.2mB/s)'.format(n * 8, n)
}

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

return view.extend({
        load: function() {
		return Promise.all([
			network.getHostHints(),
			callLuciGetUsers(),
			uci.load('natflow')
		]);
	},

        poll_status: function(nodes, data) {
		var hosts = data[0];
		var users = Array.isArray(data[1]) ? data[1] : [];

		users.sort(function(a, b) {
			return b.rx_bytes - a.rx_bytes;
		});

		var rows = users.map(function(u) {
			var mac = u.mac.toUpperCase();
			var name = hosts.getHostnameByMACAddr(mac);

			return [
				u.ip,
				name ? "%s<br />(%s)".format(mac, name) : mac,
				'%1024.2mB (%d %s)<br />%s'.format(u.rx_bytes, u.rx_pkts, _('packets'), rate(u.rx_speed_bytes)),
				'%1024.2mB (%d %s)<br />%s'.format(u.tx_bytes, u.tx_pkts, _('packets'), rate(u.tx_speed_bytes)),
				u.status == 6 ?
				E('button', {
					'class': 'btn cbi-button-remove',
					'click': L.bind(handleAllowUser, this, u.ip)
				}, [ _('Allow access') ]) :
				E('button', {
					'class': 'btn cbi-button-remove',
					'click': L.bind(handleBlockUser, this, u.ip)
				}, [ _('Block access') ])
			];
		});

		cbi_update_table(nodes.querySelector('#user_status_table'), rows, E('em', _('No information available')));

		return;
	},

	render: function(data) {
		var m, s, o;

		m = new form.Map('natflow', [_('User Access Control')]);

		s = m.section(form.GridSection, '_active_users');

		s.render = L.bind(function(view, section_id) {
			var table = E('table', { 'class': 'table cbi-section-table', 'id': 'user_status_table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th col-2' }, [ _('IP address') ]),
					E('th', { 'class': 'th col-2' }, [ _('MAC address') ]),
					E('th', { 'class': 'th col-7' }, [ _('RX') ]),
					E('th', { 'class': 'th col-7' }, [ _('TX') ]),
					E('th', { 'class': 'th cbi-section-actions' }, '')
				]),
				E('tr', { 'class': 'tr placeholder' }, [
					E('td', { 'class': 'td' }, [
						E('em', {}, [ _('Loading data...') ])
					])
				])
			]);

			var hosts = data[0];
			var users = Array.isArray(data[1]) ? data[1] : [];

			users.sort(function(a, b) {
				return b.rx_bytes - a.rx_bytes;
			});

			var rows = users.map(function(u) {
				var mac = u.mac.toUpperCase();
				var name = hosts.getHostnameByMACAddr(mac);

				return [
					u.ip,
					name ? "%s<br />(%s)".format(mac, name) : mac,
					'%1024.2mB (%d %s)<br />%s'.format(u.rx_bytes, u.rx_pkts, _('packets'), rate(u.rx_speed_bytes)),
					'%1024.2mB (%d %s)<br />%s'.format(u.tx_bytes, u.tx_pkts, _('packets'), rate(u.tx_speed_bytes)),
					u.status == 6 ?
					E('button', {
						'class': 'btn cbi-button-remove',
						'click': L.bind(handleAllowUser, this, u.ip)
					}, [ _('Allow access') ]) :
					E('button', {
						'class': 'btn cbi-button-remove',
						'click': L.bind(handleBlockUser, this, u.ip)
					}, [ _('Block access') ])
				];
			});

			cbi_update_table(table, rows, E('em', _('No information available')));

			return E('div', { 'class': 'cbi-section cbi-tblsection' }, [ E('h3', _('Active Users')), table ]);
		}, o, this);

		s = m.section(form.GridSection, 'auth', _('User IP ranges'), _('Clients in these IP ranges are managed as users.'));
		s.addremove = false;
		s.anonymous = true;
		s.nodescriptions = true;
		s.sortable = false;

		o = s.option(form.TextValue, 'sipgrp', _('Client IP ranges'),
			_('Enter one or more IPv4 or IPv6 addresses, CIDR ranges, or IPv4 address ranges, separated by commas. Example: 192.168.100.0/24,2001:db8::/64,1.2.3.4,172.16.0.100-172.16.0.111'));
		o.rmempty = false;
		o.placeholder = '192.168.15.2-192.168.15.254,2001:db8::/64'
		o.validate = function(section_id, value) {
			return nets_validate(value);
		}

		return m.render().then(L.bind(function(m, nodes) {
			poll.add(L.bind(function() {
				return Promise.all([
					network.getHostHints(),
					callLuciGetUsers()
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), pollInterval);
			return nodes;
		}, this, m));
	}
});
