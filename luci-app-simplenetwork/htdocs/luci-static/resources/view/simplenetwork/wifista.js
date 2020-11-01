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
	load: function() {
		return Promise.all([
			uci.load('network'),
			uci.load('wireless')
		]);
	},

	render: function(data) {

		var m, s, ss, o;

		m = new form.Map('wireless', [_('Wireless STA')],
			_('Configure the WiFi STA'));

		s = m.section(form.NamedSection, 'wifinet1', 'wifi-iface');
		s.addremove = false;

		o = s.option(form.Flag, 'disabled', _('Enabled'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;

		o = s.option(form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.datatype = 'maxlength(32)';

		o.render = function(option_index, section_id, in_table) {
			var current_ssid = uci.get('wireless', 'wifinet1', 'ssid');
			if (current_ssid != undefined) {
				this.value(current_ssid);
			}
			return network.getWifiDevice("radio0").then(L.bind(function(radioDev) {
				return radioDev.getScanList().then(L.bind(function(results) {
					results.sort(function(a, b) {
						var diff = (b.quality - a.quality) || (a.channel - b.channel);
						if (diff)
							return diff;
						if (a.ssid < b.ssid)
							return -1;
						else if (a.ssid > b.ssid)
							return 1;
						if (a.bssid < b.bssid)
							return -1;
						else if (a.bssid > b.bssid)
							return 1;
					});

					for (var i = 0; i < results.length; i++) {
						this.value(results[i].ssid, results[i].ssid + " (" + _('Channel') + " " + results[i].channel + " " + network.formatWifiEncryption(results[i].encryption) + ")");
						if (current_ssid == results[i].ssid, results[i].ssid) {
							current_ssid = undefined;
						}
					}
					if (current_ssid != undefined) {
						this.value(current_ssid);
					}
					return form.Value.prototype.render.apply(this, [ option_index, section_id, in_table ]);
				}, this));
			}, this));
		}

		o = s.option(form.ListValue, 'encryption', _('Encryption'));
		o.value('none', _('No Encryption'));
		o.value('psk', _('WPA-PSK'));
		o.value('psk2', _('WPA2-PSK'));
		o.value('psk-mixed', _('WPA-PSK/WPA2-PSK Mixed Mode'));

		o = s.option(form.Value, 'key', _('Key'));
		o.depends('encryption', 'psk');
		o.depends('encryption', 'psk2');
		o.depends('encryption', 'psk-mixed');
		o.rmempty = true;
		o.password = true;

		m.chain('network');
		o = s.option(form.SectionValue, '_interface', form.TypedSection, 'interface', _('STA Network'));
		ss = o.subsection;
		ss.uciconfig = 'network';
		ss.addremove = false;
		ss.anonymous = true;
		ss.filter = function(section_id) {
			return (section_id == 'wwan');
		};

		o = ss.option(form.ListValue, 'proto', _('Protocol'));
		o.rmempty = false;
		o.value('dhcp', _('DHCP client'));
		o.value('static', _('Static address'));

		o = ss.option(form.Value, 'ipaddr', _('IPv4 address'));
		o.depends('proto', 'static');
		o.datatype = 'ip4addr';

		o = ss.option(form.Value, 'netmask', _('IPv4 netmask'));
		o.depends('proto', 'static');
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');

		o = ss.option(form.Value, 'gateway', _('IPv4 gateway'));
		o.depends('proto', 'static');
		o.datatype = 'ip4addr';

		o = ss.option(form.DynamicList, 'dns', _('Use custom DNS servers'));
		o.datatype = 'ip4addr';
		o.cast = 'string';

		return m.render();
	}
});
