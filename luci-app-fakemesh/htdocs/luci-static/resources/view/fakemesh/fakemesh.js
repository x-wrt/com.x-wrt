'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require form';
'require network';

return view.extend({
	load: function() {
		return Promise.all([
			uci.changes(),
			uci.load('wireless'),
			uci.load('fakemesh')
		]);
	},

	render: function(data) {

		var m, s, o;
		var has_wifi = false;

		if (uci.sections('wireless', 'wifi-device').length > 0) {
			has_wifi = true;
		}

		m = new form.Map('fakemesh', [_('Fake Mesh Setup')],
			_('Basic settings for your fake mesh overlay network'));

		s = m.section(form.NamedSection, 'default', 'fakemesh');
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.enabled = '1';
		o.disabled = '0';
		o.default = o.disabled;

		o = s.option(form.Value, 'id', _('Mesh ID'));
		o.datatype = 'maxlength(32)';

		o = s.option(form.Value, 'key', _('Key'), _('Leave empty if encryption is not required.'));
		o.rmempty = true;
		o.password = true;
		o.datatype = 'wpakey';

		o = s.option(form.ListValue, 'band', _('Band'));
		o.value('5g', _('5G'));
		o.value('2g', _('2G'));
		o.default = '5g';

		o = s.option(form.ListValue, 'role', _('Role'), _('Set the gateway router as controller, others as agent.'));
		o.value('wap', _('Wired AP'));
		o.value('agent', _('Agent'));
		o.value('controller', _('Controller'));
		o.default = 'agent';

		o = s.option(form.Value, 'access_ip', _('Access IP address'), _('The simple ip address to access the controller.'));
		o.depends('role', 'controller');
		o.placeholder = '10.10.10.1'
		o.rmempty = true;
		o.datatype = 'ip4addr';

		o = s.option(form.Flag, 'sync_ac', _('Sync Config'), _('Sync config from the Controller.'));
		o.enabled = '1';
		o.disabled = '0';
		o.default = o.enabled;

		s = m.section(form.GridSection, 'wifim', _('Wireless Management'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;
		s.sortable = false;

		o = s.option(form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.datatype = 'maxlength(32)';

		o = s.option(form.ListValue, 'encryption', _('Encryption'));
		o.value('none', _('No Encryption'));
		o.value('psk', _('WPA-PSK'));
		o.value('psk2', _('WPA2-PSK'));
		o.value('psk-mixed', _('WPA-PSK/WPA2-PSK Mixed Mode'));
		o.value('sae', _('WPA3-SAE'));
		o.value('sae-mixed', _('WPA2-PSK/WPA3-SAE Mixed Mode'));

		o = s.option(form.Value, 'key', _('Key'));
		o.depends('encryption', 'psk');
		o.depends('encryption', 'psk2');
		o.depends('encryption', 'psk-mixed');
		o.depends('encryption', 'sae');
		o.depends('encryption', 'sae-mixed');
		o.rmempty = false;
		o.password = true;
		o.datatype = 'wpakey';

		o = s.option(form.ListValue, 'band', _('Band'));
		o.value('2g5g', _('2G+5G'));
		o.value('5g', _('5G'));
		o.value('2g', _('2G'));
		o.default = '2g5g';

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = o.enabled;

		return m.render();
	}
});
