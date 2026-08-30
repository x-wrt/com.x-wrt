'use strict';
'require baseclass';
'require dom';
'require rpc';
'require ui';

var callBlockUser = rpc.declare({
	object: 'luci.natflow',
	method: 'block_user',
	params: [ 'token' ],
	expect: { result: '' },
	reject: true
});

var callAllowUser = rpc.declare({
	object: 'luci.natflow',
	method: 'allow_user',
	params: [ 'token' ],
	expect: { result: '' },
	reject: true
});

function handleRPCAction(callFn, ips, ev, errMsg, errDetailMsg) {
	var btn = ev.currentTarget;
	var tr = dom.parent(btn, '.tr');
	if (tr) tr.style.opacity = 0.5;
	btn.classList.add('spinning');
	btn.disabled = true;
	btn.blur();

	var tokens = Array.isArray(ips) ? ips : [ips];
	return Promise.all(tokens.map(function(token) { return callFn(token); }))
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
}

function blockUser(ips, ev) {
	handleRPCAction(callBlockUser, ips, ev, _('Failed to block user.'), _('Failed to block user: %s'));
}

function allowUser(ips, ev) {
	handleRPCAction(callAllowUser, ips, ev, _('Failed to allow user.'), _('Failed to allow user: %s'));
}

function rate(n) {
	n = (n || 0).toFixed(2);
	return '%1024.2mbit/s (%1024.2mB/s)'.format(n * 8, n);
}

function userIps(u) {
	var ips = [];

	(Array.isArray(u.ip) ? u.ip : []).forEach(function(ip) {
		if (ip && ips.indexOf(ip) === -1)
			ips.push(ip);
	});

	(Array.isArray(u.ip6) ? u.ip6 : []).forEach(function(ip) {
		if (ip && ips.indexOf(ip) === -1)
			ips.push(ip);
	});

	return ips;
}

function accessLabel(u) {
	if (u.access_type === 'wireless_mesh')
		return _('Wireless Mesh');
	else if (u.access_type === 'wireless')
		return _('Wireless');
	else if (u.access_type === 'vpn')
		return _('VPN');
	else
		return _('Wired');
}

function addStyles(wrapper) {
	if (document.getElementById('natflow-users-table-styles'))
		return;

	wrapper.appendChild(E('style', { 'id': 'natflow-users-table-styles' }, `
		.natflow-users-table { display: flex !important; flex-direction: column; width: 100%; border: none !important; }
		.natflow-users-table tbody { display: flex; flex-direction: column; width: 100%; }
		.natflow-users-table .tr { display: flex; align-items: center; padding: 12px 8px; border-bottom: 1px solid rgba(0,0,0,0.05); transition: opacity 0.3s ease; }
		.natflow-users-table .table-titles { font-weight: 600; color: #6c757d; background: transparent !important; }
		.natflow-users-table .td, .natflow-users-table .th { border: none !important; padding: 8px 10px; word-break: break-all; }

		.natflow-users-table .th:nth-child(1), .natflow-users-table .td:nth-child(1) { flex: 1 1 30%; }
		.natflow-users-table .th:nth-child(2), .natflow-users-table .td:nth-child(2) { flex: 1 1 25%; }
		.natflow-users-table .th:nth-child(3), .natflow-users-table .td:nth-child(3) { flex: 1 1 35%; }
		.natflow-users-table .th:nth-child(4), .natflow-users-table .td:nth-child(4) { flex: 0 0 72px; text-align: right; }

		@media screen and (max-width: 800px) {
			.natflow-users-table .table-titles { display: none !important; }
			.natflow-users-table .tr:not(.table-titles) {
				flex-direction: row; flex-wrap: wrap; align-items: flex-start;
				background: rgba(0,0,0,0.02); border-radius: 12px; margin-bottom: 12px;
				padding: 12px 16px; border: 1px solid rgba(0,0,0,0.05) !important;
			}
			.natflow-users-table .td { flex: 1 1 100% !important; text-align: left !important; padding: 4px 0 !important; }
			.natflow-users-table .td:nth-child(1) { order: 1; flex: 1 1 65% !important; border-bottom: 1px dashed rgba(0,0,0,0.1); padding-bottom: 8px !important; margin-bottom: 8px !important; }
			.natflow-users-table .td:nth-child(4) { order: 2; flex: 1 1 35% !important; text-align: right !important; border-bottom: 1px dashed rgba(0,0,0,0.1); padding-bottom: 8px !important; margin-bottom: 8px !important; display: flex; justify-content: flex-end; align-items: flex-start; }
			.natflow-users-table .td:nth-child(2) { order: 3; flex: 1 1 45% !important; background: rgba(255,255,255,0.5); padding: 8px !important; border-radius: 6px 0 0 6px; border-right: 1px solid rgba(0,0,0,0.05); }
			.natflow-users-table .td:nth-child(3) { order: 4; flex: 1 1 55% !important; background: rgba(255,255,255,0.5); padding: 8px !important; border-radius: 0 6px 6px 0; }
		}

		[data-darkmode="true"] .natflow-users-table .tr:not(.table-titles) { background: rgba(255,255,255,0.03); }
		[data-darkmode="true"] .natflow-users-table .td:nth-child(2), [data-darkmode="true"] .natflow-users-table .td:nth-child(3) { background: rgba(0,0,0,0.2); border-color: rgba(255,255,255,0.05); }
	`));
}

function renderConnection(u) {
	var label = accessLabel(u);
	var w = u.wireless;

	if (w && w.ssid) {
		var band = w.band || '';
		var signal = w.signal;
		var noise = (w.noise !== undefined) ? w.noise : -90;
		var quality = w.quality;

		if (quality === undefined || quality === null) {
			if (signal !== undefined && signal !== null) {
				var snr = -30 - noise;
				quality = snr !== 0 ? Math.max(0, Math.min(100, 100 * ((signal - noise) / snr))) : 0;
			} else {
				quality = 0;
			}
		}

		var qColor = (quality < 25) ? '#dc3545' : ((quality < 50) ? '#ffc107' : '#198754');

		return E('div', {}, [
			E('div', { 'style': 'display: inline-block; padding: 2px 6px; font-size: 11px; font-weight: bold; border-radius: 4px; background: rgba(13, 110, 253, 0.1); color: #0d6efd; margin-bottom: 4px;' }, band ? '%s %s'.format(label, band) : label),
			E('div', { 'style': 'font-size: 13px; font-weight: 600;' }, w.ssid),
			E('div', { 'style': 'font-size: 12px; margin-top: 2px; color: #6c757d;' }, [
				E('span', { 'style': 'display: inline-block; width: 8px; height: 8px; border-radius: 50%; background-color: %s; margin-right: 5px;'.format(qColor) }),
				'%d dBm (%d%%)'.format(signal || 0, parseInt(quality))
			])
		]);
	}

	if (u.access_type === 'vpn' && u.ifname) {
		return E('div', {}, [
			E('div', { 'style': 'display: inline-block; padding: 2px 6px; font-size: 11px; font-weight: bold; border-radius: 4px; background: rgba(111, 66, 193, 0.1); color: #6f42c1; margin-bottom: 4px;' }, label),
			E('div', { 'style': 'font-size: 13px; font-weight: 600;' }, u.ifname)
		]);
	}

	if (u.access_type !== 'wired' && u.ifname) {
		return E('div', {}, [
			E('div', { 'style': 'display: inline-block; padding: 2px 6px; font-size: 11px; font-weight: bold; border-radius: 4px; background: rgba(13, 110, 253, 0.1); color: #0d6efd; margin-bottom: 4px;' }, label),
			E('div', { 'style': 'font-size: 13px; font-weight: 600;' }, u.ifname)
		]);
	}

	return E('div', {}, [
		E('div', { 'style': 'display: inline-block; padding: 2px 6px; font-size: 11px; font-weight: bold; border-radius: 4px; background: rgba(25, 135, 84, 0.1); color: #198754; margin-bottom: 4px;' }, label),
		E('div', { 'style': 'font-size: 13px; color: #6c757d; margin-top: 2px;' }, u.ifname || 'LAN')
	]);
}

function renderUserRow(hosts, u) {
	var mac = u.mac ? u.mac.toUpperCase() : '?';
	var name = hosts.getHostnameByMACAddr(mac) || u.hostname;
	var ips = userIps(u);

	var nodeDeviceInfo = E('div', {}, [
		E('div', { 'style': 'font-weight: 600; font-size: 14px;' }, name || '?'),
		E('div', { 'class': 'text-muted', 'style': 'font-family: monospace; font-size: 12px; opacity: 0.7;' }, mac)
	]);

	ips.forEach(function(ip) {
		nodeDeviceInfo.appendChild(E('div', { 'style': 'font-family: monospace; font-size: 13px; margin-top: 3px; color: var(--bs-info, #0dcaf0); word-break: break-all;' }, ip));
	});

	if (u.idle_time !== undefined && u.idle_time !== null) {
		var activeStr = (u.idle_time < 5) ? _('Active now') : _('%s ago').format('%t'.format(u.idle_time));
		nodeDeviceInfo.appendChild(E('div', { 'style': 'font-size: 11px; color: #6c757d; margin-top: 3px;' }, [
			E('span', { 'style': 'opacity: 0.8; margin-right: 2px;' }, '⏱️ '),
			activeStr
		]));
	}

	var nodeTraffic = E('div', { 'style': 'display: flex; gap: 10px; flex-direction: column;' }, [
		E('div', {}, [
			E('div', { 'style': 'color: var(--bs-success, #198754); font-weight: 600; font-size: 13px;' }, [ E('span', '↓ '), '%1024.2mB'.format(u.rx_bytes) ]),
			E('div', { 'style': 'font-size: 11px; opacity: 0.7; margin-top: 2px;' }, rate(u.rx_speed_bytes))
		]),
		E('div', {}, [
			E('div', { 'style': 'color: var(--bs-primary, #0d6efd); font-weight: 600; font-size: 13px;' }, [ E('span', '↑ '), '%1024.2mB'.format(u.tx_bytes) ]),
			E('div', { 'style': 'font-size: 11px; opacity: 0.7; margin-top: 2px;' }, rate(u.tx_speed_bytes))
		])
	]);

	var isBlocked = (u.status == 6);
	var btnText = isBlocked ? _('Disabled') : _('Enabled');
	var hoverText = isBlocked ? _('Enable') : _('Disable');
	var btnClass = isBlocked ? 'cbi-button-negative' : 'cbi-button-positive';
	var hoverClass = isBlocked ? 'cbi-button-positive' : 'cbi-button-negative';
	var btnHandler = isBlocked ? allowUser : blockUser;

	var action = E('button', {
		'class': 'btn ' + btnClass,
		'style': 'padding: 2px 8px; font-size: 11px; border-radius: 4px; min-width: 64px;',
		'click': L.bind(btnHandler, null, ips),
		'mouseover': function(ev) {
			if (!ev.currentTarget.disabled) {
				ev.currentTarget.textContent = hoverText;
				ev.currentTarget.classList.remove(btnClass);
				ev.currentTarget.classList.add(hoverClass);
			}
		},
		'mouseout': function(ev) {
			if (!ev.currentTarget.disabled) {
				ev.currentTarget.textContent = btnText;
				ev.currentTarget.classList.remove(hoverClass);
				ev.currentTarget.classList.add(btnClass);
			}
		}
	}, [ btnText ]);

	return [ nodeDeviceInfo, renderConnection(u), nodeTraffic, action ];
}

function buildTable() {
	return E('table', { 'class': 'table natflow-users-table', 'id': 'natflow-users' }, [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, [ _('Device Info') ]),
			E('th', { 'class': 'th' }, [ _('Connection') ]),
			E('th', { 'class': 'th' }, [ _('Traffic (RX / TX)') ]),
			E('th', { 'class': 'th cbi-section-actions' }, [ _('Internet') ])
		]),
		E('tr', { 'class': 'tr placeholder' }, [
			E('td', { 'class': 'td' }, [
				E('em', {}, [ _('Collecting data...') ])
			])
		])
	]);
}

function renderUserTable(hosts, users) {
	users = Array.isArray(users) ? users : [];
	users.sort(function(a, b) { return b.rx_bytes - a.rx_bytes; });

	var wrapper = E('div', { 'class': 'natflow-users-wrapper', 'style': 'padding: 1.5em; margin-bottom: 20px;' });
	addStyles(wrapper);

	var table = buildTable();
	var rows = users.map(function(u) { return renderUserRow(hosts, u); });

	cbi_update_table(table, rows, E('em', _('No information available')));

	wrapper.appendChild(table);
	return wrapper;
}

function updateUserTable(table, hosts, users) {
	if (!table)
		return;

	users = Array.isArray(users) ? users : [];
	users.sort(function(a, b) { return b.rx_bytes - a.rx_bytes; });

	var rows = users.map(function(u) { return renderUserRow(hosts, u); });
	cbi_update_table(table, rows, E('em', _('No information available')));
}

return baseclass.extend({
	blockUser: blockUser,
	allowUser: allowUser,
	userIps: userIps,
	rate: rate,
	renderUserTable: renderUserTable,
	updateUserTable: updateUserTable
});
