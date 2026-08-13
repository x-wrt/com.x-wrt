'use strict';
'require view';
'require dom';
'require poll';
'require request';
'require rpc';
'require network';
'require uci';
'require form';
'require ui';
'require validation';

var callLuciGetUsers = rpc.declare({
	object: 'luci.natflow',
	method: 'get_users',
	expect: { result: [] }
});

var callKickUser = rpc.declare({
        object: 'luci.natflow',
        method: 'kick_user',
        params: [ 'token' ],
        expect: { result : '' },
        reject: true
});

var callBlockUser = rpc.declare({
        object: 'luci.natflow',
        method: 'block_user',
        params: [ 'token' ],
        expect: { result : '' },
        reject: true
});

var callAllowUser = rpc.declare({
        object: 'luci.natflow',
        method: 'allow_user',
        params: [ 'token' ],
        expect: { result : '' },
        reject: true
});

var handleRPCAction = function(callFn, token, ev, errMsg, errDetailMsg) {
        var btn = ev.currentTarget;
        var tr = dom.parent(btn, '.tr');
        if (tr) tr.style.opacity = 0.5;
        btn.classList.add('spinning');
        btn.disabled = true;
        btn.blur();

        var tokens = Array.isArray(token) ? token : [token];
        return Promise.all(tokens.map(function(t) { return callFn(t); }))
                .then(function(results) {
                        var failed = results.some(function(res) { return res !== 'OK'; });
                        if (failed) {
                                ui.addNotification(null, E('p', errMsg), 'error');
                                if (tr) tr.style.opacity = 1;
                                btn.classList.remove('spinning');
                                btn.disabled = false;
                        }
                })
                .catch(function(err) {
                        ui.addNotification(null, E('p', errDetailMsg.format(err.message || err)), 'error');
                        if (tr) tr.style.opacity = 1;
                        btn.classList.remove('spinning');
                        btn.disabled = false;
                });
};

var handleKickUser = function(num, ev) {
        handleRPCAction(callKickUser, num, ev, _('Failed to kick user.'), _('Failed to kick user: %s'));
};

var handleBlockUser = function(num, ev) {
        handleRPCAction(callBlockUser, num, ev, _('Failed to block user.'), _('Failed to block user: %s'));
};

var handleAllowUser = function(num, ev) {
        handleRPCAction(callAllowUser, num, ev, _('Failed to allow user.'), _('Failed to allow user: %s'));
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

		var render_user_row = function(u) {
			var mac = u.mac.toUpperCase();
			var name = hosts.getHostnameByMACAddr(mac) || u.hostname;

			var mac_elm = name ? E('span', {}, [ mac, E('br'), '(', name, ')' ]) : mac;
			var rx_elm = E('span', {}, [
				'%1024.2mB (%d %s)'.format(u.rx_bytes, u.rx_pkts, _('packets')),
				E('br'),
				rate(u.rx_speed_bytes)
			]);
			var tx_elm = E('span', {}, [
				'%1024.2mB (%d %s)'.format(u.tx_bytes, u.tx_pkts, _('packets')),
				E('br'),
				rate(u.tx_speed_bytes)
			]);

			var ip_cell = u.ip;
			var mac_cell = mac_elm;
			var rx_cell = rx_elm;
			var tx_cell = tx_elm;

			if (u.status == 6) {
				ip_cell = E('span', { 'style': 'color:red' }, [ ip_cell ]);
				mac_cell = E('span', { 'style': 'color:red' }, [ mac_cell ]);
				rx_cell = E('span', { 'style': 'color:red' }, [ rx_cell ]);
				tx_cell = E('span', { 'style': 'color:red' }, [ tx_cell ]);
			}

			return [
				ip_cell,
				mac_cell,
				rx_cell,
				tx_cell,
				u.status == 6 ?
				E('button', {
					'class': 'btn cbi-button-negative',
					'click': L.bind(handleAllowUser, this, u.ip)
				}, [ _('Disconnected') ]) :
				E('button', {
					'class': 'btn cbi-button-positive',
					'click': L.bind(handleBlockUser, this, u.ip)
				}, [ _('Allowed') ])
			];
		};

		var rows = users.map(render_user_row);

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
					E('th', { 'class': 'th cbi-section-actions' }, [ _('Internet') ])
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

			var render_user_row = function(u) {
				var mac = u.mac.toUpperCase();
				var name = hosts.getHostnameByMACAddr(mac) || u.hostname;

				var mac_elm = name ? E('span', {}, [ mac, E('br'), '(', name, ')' ]) : mac;
				var rx_elm = E('span', {}, [
					'%1024.2mB (%d %s)'.format(u.rx_bytes, u.rx_pkts, _('packets')),
					E('br'),
					rate(u.rx_speed_bytes)
				]);
				var tx_elm = E('span', {}, [
					'%1024.2mB (%d %s)'.format(u.tx_bytes, u.tx_pkts, _('packets')),
					E('br'),
					rate(u.tx_speed_bytes)
				]);

				var ip_cell = u.ip;
				var mac_cell = mac_elm;
				var rx_cell = rx_elm;
				var tx_cell = tx_elm;

				if (u.status == 6) {
					ip_cell = E('span', { 'style': 'color:red' }, [ ip_cell ]);
					mac_cell = E('span', { 'style': 'color:red' }, [ mac_cell ]);
					rx_cell = E('span', { 'style': 'color:red' }, [ rx_cell ]);
					tx_cell = E('span', { 'style': 'color:red' }, [ tx_cell ]);
				}

				return [
					ip_cell,
					mac_cell,
					rx_cell,
					tx_cell,
					u.status == 6 ?
					E('button', {
						'class': 'btn cbi-button-negative',
						'click': L.bind(handleAllowUser, this, u.ip)
					}, [ _('Disconnected') ]) :
					E('button', {
						'class': 'btn cbi-button-positive',
						'click': L.bind(handleBlockUser, this, u.ip)
					}, [ _('Allowed') ])
				];
			};

			var rows = users.map(render_user_row);

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
