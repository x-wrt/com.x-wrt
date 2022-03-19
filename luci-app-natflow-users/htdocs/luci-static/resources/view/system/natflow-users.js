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

var handleKickUser = function(num, ev) {
        dom.parent(ev.currentTarget, '.tr').style.opacity = 0.5;
        ev.currentTarget.classList.add('spinning');
        ev.currentTarget.disabled = true;
        ev.currentTarget.blur();
        callKickUser(num);
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
				'%1024.2mB (%d %s)<br />%s'.format(u.rx_bytes, u.rx_pkts, _('Pkts.'), rate(u.rx_speed_bytes)),
				'%1024.2mB (%d %s)<br />%s'.format(u.tx_bytes, u.tx_pkts, _('Pkts.'), rate(u.tx_speed_bytes)),
				E('button', {
					'class': 'btn cbi-button-remove',
					'click': L.bind(handleKickUser, this, u.ip)
				}, [ _('Delete') ])
			];
		});

		cbi_update_table(nodes.querySelector('#user_status_table'), rows, E('em', _('No information available')));

		return;
	},

	render: function(data) {
		var m, s, o;

		m = new form.Map('natflow', [_('User Authentication')]);

		s = m.section(form.GridSection, '_active_users');

		s.render = L.bind(function(view, section_id) {
			var table = E('table', { 'class': 'table cbi-section-table', 'id': 'user_status_table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th col-2' }, [ _('IPv4 address') ]),
					E('th', { 'class': 'th col-2' }, [ _('MAC address') ]),
					E('th', { 'class': 'th col-7' }, [ _('RX') ]),
					E('th', { 'class': 'th col-7' }, [ _('TX') ]),
					E('th', { 'class': 'th cbi-section-actions' }, '')
				]),
				E('tr', { 'class': 'tr placeholder' }, [
					E('td', { 'class': 'td' }, [
						E('em', {}, [ _('Collecting data...') ])
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
					'%1024.2mB (%d %s)<br />%s'.format(u.rx_bytes, u.rx_pkts, _('Pkts.'), rate(u.rx_speed_bytes)),
					'%1024.2mB (%d %s)<br />%s'.format(u.tx_bytes, u.tx_pkts, _('Pkts.'), rate(u.tx_speed_bytes)),
					E('button', {
						'class': 'btn cbi-button-remove',
						'click': L.bind(handleKickUser, this, u.ip)
					}, [ _('Delete') ])
				];
			});

			cbi_update_table(table, rows, E('em', _('No information available')));

			return E('div', { 'class': 'cbi-section cbi-tblsection' }, [ E('h3', _('Active Users')), table ]);
		}, o, this);

		s = m.section(form.GridSection, 'auth', _('User rules'), _('IPs in this range are treated as users'));
		s.addremove = false;
		s.anonymous = true;
		s.nodescriptions = true;
		s.sortable = false;

		o = s.option(form.Value, 'sipgrp', _('IP range'),
			_('Can be a single or multiple ipaddr(s)(/cidr) or iprange, split with comma (e.g. "192.168.100.0/24,1.2.3.4,172.16.0.100-172.16.0.111") without quotes'));
		o.rmempty = false;
		o.placeholder = '192.168.15.2-192.168.15.254'
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
