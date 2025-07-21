'use strict';
'require view';
'require dom';
'require poll';
'require ui';
'require uci';
'require rpc';
'require form';
'require network';

return view.extend({
	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			classes.ui.changes.apply(mode == '1');
		});
	},
	load: function() {
		return Promise.all([
			uci.load('wireless')
		]);
	},

	render: function(data) {

		var m, s, ss, sss, o;

		m = new form.Map('wireless', [_('Wireless AP')],
			_('Configure the WiFi AP'));

		s = m.section(form.NamedSection, 'wifinet1', 'wifi-iface');
		s.addremove = false;

		o = s.option(form.Flag, 'disabled', _('Enable'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		o = s.option(form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.datatype = 'maxlength(32)';

		o = s.option(form.ListValue, 'encryption', _('Encryption'));
		o.value('none', _('No Encryption'));
		o.value('psk', _('WPA-PSK'));
		o.value('psk2', _('WPA2-PSK'));
		o.value('psk-mixed', _('WPA-PSK/WPA2-PSK Mixed Mode'));

		o = s.option(form.Value, 'key', _('Key'));
		o.depends('encryption', 'psk');
		o.depends('encryption', 'psk2');
		o.depends('encryption', 'psk-mixed');
		o.rmempty = false;
		o.password = true;
		o.datatype = 'wpakey';

		s = m.section(form.NamedSection, 'radio0', 'wifi-device');
		s.addremove = false;

		o = s.option(form.ListValue, 'channel', _('Channel'));
		o.value('auto', _('auto'));
		o.value('1');
		o.value('2');
		o.value('3');
		o.value('4');
		o.value('5');
		o.value('6');
		o.value('7');
		o.value('8');
		o.value('9');
		o.value('10');
		o.value('11');
		o.value('12');
		o.value('13');

		return m.render();
	}
});
