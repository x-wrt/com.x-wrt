'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require form';

return view.extend({
	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			classes.ui.changes.apply(mode == '1');
		});
	},
	load: function() {
		return Promise.all([
			uci.load('network')
		]);
	},

	render: function(data) {

		var m, s, o;

		m = new form.Map('network', [_('LAN Port')],
			_('Configure network parameters for the LAN port'));

		s = m.section(form.NamedSection, 'lan', 'interface');
		s.addremove = false;

		o = s.option(form.Value, 'ipaddr', _('Management IP'));
		o.datatype = 'ip4addr';
		o.rmempty = false;

		o = s.option(form.Value, 'netmask', _('Management netmask'));
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.rmempty = false;

		return m.render();
	}
});
