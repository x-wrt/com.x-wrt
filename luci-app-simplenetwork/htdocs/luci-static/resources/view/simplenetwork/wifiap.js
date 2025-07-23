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

		s = m.section(form.NamedSection, 'wifinet0', 'wifi-iface');
		s.addremove = false;
		s.tab('wifiap', _('Wireless AP (Management)'), _('This wireless AP is used to access the management interface.'));
		s.tab('wifiap2', _('Wireless AP (User)'), _('This wireless AP is used to extend the Ethernet port to connect to the upstream network.'));

		o = s.taboption('wifiap', form.Flag, 'disabled', _('Enable'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		o = s.taboption('wifiap', form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.datatype = 'maxlength(32)';

		o = s.taboption('wifiap', form.ListValue, 'encryption', _('Encryption'));
		o.value('none', _('No Encryption'));
		o.value('psk', _('WPA-PSK'));
		o.value('psk2', _('WPA2-PSK'));
		o.value('psk-mixed', _('WPA-PSK/WPA2-PSK Mixed Mode'));

		o = s.taboption('wifiap', form.Value, 'key', _('Key'));
		o.depends('encryption', 'psk');
		o.depends('encryption', 'psk2');
		o.depends('encryption', 'psk-mixed');
		o.rmempty = false;
		o.password = true;
		o.datatype = 'wpakey';

		o = s.taboption('wifiap', form.ListValue, 'radio0_channel', _('Channel'));
		o.ucisection = 'radio0';
		o.ucioption = 'channel';
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

		o = s.taboption('wifiap2', form.Flag, 'wifinet1_disabled', _('Enable'));
		o.ucisection = 'wifinet1';
		o.ucioption = 'disabled';
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		o = s.taboption('wifiap2', form.Value, 'wifinet1_ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.ucisection = 'wifinet1';
		o.ucioption = 'ssid';
		o.datatype = 'maxlength(32)';

		o = s.taboption('wifiap2', form.ListValue, 'wifinet1_encryption', _('Encryption'));
		o.ucisection = 'wifinet1';
		o.ucioption = 'encryption';
		o.value('none', _('No Encryption'));
		o.value('psk', _('WPA-PSK'));
		o.value('psk2', _('WPA2-PSK'));
		o.value('psk-mixed', _('WPA-PSK/WPA2-PSK Mixed Mode'));

		o = s.taboption('wifiap2', form.Value, 'wifinet1_key', _('Key'));
		o.ucisection = 'wifinet1';
		o.ucioption = 'key';
		o.depends('wifinet1_encryption', 'psk');
		o.depends('wifinet1_encryption', 'psk2');
		o.depends('wifinet1_encryption', 'psk-mixed');
		o.rmempty = false;
		o.password = true;
		o.datatype = 'wpakey';

		return m.render();
	}
});
