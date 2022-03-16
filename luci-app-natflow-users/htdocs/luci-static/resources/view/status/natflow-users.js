'use strict';
'require view';
'require poll';
'require request';
'require rpc';

var callLuciConntrackList = rpc.declare({
	object: 'luci.natflow',
	method: 'get_users',
	expect: { result: [] }
});

var pollInterval = 3;

return view.extend({
	updateConntrack: function(conn) {
		var lookup_queue = [ ];
		var rows = [];

		conn.sort(function(a, b) {
			return b.rx_bytes - a.rx_bytes;
		});

		for (var i = 0; i < conn.length; i++)
		{
			var c  = conn[i];

			rows.push([
				c.ip,
				c.mac,
				'%1024.2mB (%d %s)'.format(c.rx_bytes, c.rx_pkts, _('Pkts.')),
				'%1024.2mB (%d %s)'.format(c.tx_bytes, c.tx_pkts, _('Pkts.'))
			]);
		}

		cbi_update_table('#users', rows, E('em', _('No information available')));
	},

	pollData: function() {
		poll.add(L.bind(function() {
			var tasks = [
				L.resolveDefault(callLuciConntrackList(), [])
			];

			return Promise.all(tasks).then(L.bind(function(datasets) {
				this.updateConntrack(datasets[0]);
			}, this));
		}, this), pollInterval);
	},

	render: function(data) {
		var v = E([], [
			E('br'),

			E('div', { 'class': 'cbi-section-node' }, [
				E('table', { 'class': 'table', 'id': 'users' }, [
					E('tr', { 'class': 'tr table-titles' }, [
						E('th', { 'class': 'th col-2 hide-xs' }, [ _('IPv4 address') ]),
						E('th', { 'class': 'th col-2' }, [ _('MAC address') ]),
						E('th', { 'class': 'th col-7' }, [ _('Download') ]),
						E('th', { 'class': 'th col-7' }, [ _('Upload') ])
					]),
					E('tr', { 'class': 'tr placeholder' }, [
						E('td', { 'class': 'td' }, [
							E('em', {}, [ _('Collecting data...') ])
						])
					])
				])
			])
		]);

		this.pollData();

		return v;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
