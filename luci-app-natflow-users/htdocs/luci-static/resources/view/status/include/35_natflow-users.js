'use strict';
'require baseclass';
'require rpc';
'require network';

var callLuciGetUsers = rpc.declare({
	object: 'luci.natflow',
	method: 'get_mac_users',
	expect: { result: [] }
});

return baseclass.extend({
	title: _('Active Users'),

	load: function() {
		return Promise.all([
			network.getHostHints(),
			callLuciGetUsers(),
			L.require('view.natflow-users')
		]);
	},

	render: function(data) {
		var hosts = data[0];
		var users = data[1];
		var users_ui = data[2];

		return users_ui.renderUserTable(hosts, users, 'kick');
	}
});
