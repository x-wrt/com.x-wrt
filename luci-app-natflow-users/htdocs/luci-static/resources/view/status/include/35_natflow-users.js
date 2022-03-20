'use strict';
'require baseclass';
'require dom';
'require rpc';
'require uci';
'require network';

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

var pollInterval = 3;

Math.log2 = Math.log2 || function(x) { return Math.log(x) * Math.LOG2E; };

function rate(n, br) {
	n = (n || 0).toFixed(2);
	return '%1024.2mbit/s (%1024.2mB/s)'.format(n * 8, n)
}

return baseclass.extend({
	title: _('Active Users'),

	load: function() {
		return Promise.all([
			network.getHostHints(),
			callLuciGetUsers(),
		]);
	},

	render: function(data) {
		var table = E('table', { 'class': 'table', 'id': 'users' }, [
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

		return table;
	}
});
