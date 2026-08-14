'use strict';
'require view';
'require poll';
'require rpc';
'require network';

var callLuciGetUsers = rpc.declare({
	object: 'luci.natflow',
	method: 'get_mac_users',
	expect: { result: [] }
});

var pollInterval = 3;

return view.extend({
	load: function() {
		return Promise.all([
			network.getHostHints(),
			L.resolveDefault(callLuciGetUsers(), []),
			L.require('view.natflow-users')
		]);
	},

	updateUsers: function(hosts, users, users_ui) {
		var table = document.getElementById('natflow-users');
		users_ui.updateUserTable(table, hosts, users, 'kick');
	},

	pollData: function(hosts, users, users_ui) {
		var self = this;

		poll.add(function() {
			return Promise.all([
				network.getHostHints(),
				L.resolveDefault(callLuciGetUsers(), [])
			]).then(function(data) {
				self.updateUsers(data[0], data[1], users_ui);
			});
		}, pollInterval);
	},

	render: function(data) {
		var hosts = data[0];
		var users = data[1];
		var users_ui = data[2];

		this.pollData(hosts, users, users_ui);

		return E([], [
			E('div', { 'class': 'cbi-section-node' }, [
				users_ui.renderUserTable(hosts, users, 'kick')
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
