'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require form';

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

		o = s.option(form.Value, 'key', _('Key'), _('Leave empty if encryption is not required'));
		o.rmempty = true;
		o.password = true;
		o.datatype = 'wpakey';

		o = s.option(form.ListValue, 'band', _('Band'));
		o.value('5g', _('5G'));
		o.value('2g', _('2G'));
		o.default = '5g';

		o = s.option(form.ListValue, 'role', _('Role'));
		o.value('agent', _('Agent'));
		o.value('controller', _('Controller'), _('Set the gateway router as controller, others as agent.'));
		o.default = 'agent';

		return m.render();
	}
});
