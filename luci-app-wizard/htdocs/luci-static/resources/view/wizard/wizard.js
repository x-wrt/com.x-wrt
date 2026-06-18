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
			uci.load('wizard')
		]);
	},

	render: function(data) {

		var m, s, o;
		var has_wifi = false;

		if (uci.sections('wireless', 'wifi-device').length > 0) {
			has_wifi = true;
		}

		m = new form.Map('wizard', [_('Router Setup Wizard')],
			_('Configure the basic Internet, Wi-Fi, local network, and optional service settings for this router.'));

		s = m.section(form.NamedSection, 'default', 'wizard');
		s.addremove = false;
		s.tab('wansetup', _('Internet Settings'), _('Choose how this router connects to the Internet.'));
		if (has_wifi) {
			s.tab('wifisetup', _('Wi-Fi Settings'), _('Set the Wi-Fi network name and password. For advanced options, go to Network > Wireless.'));
		}
		s.tab('lansetup', _('Local Network'));

		s.tab('service', _('Optional Services'), _('Turn off unused services to reduce memory usage.'));

		o = s.taboption('wansetup', form.ListValue, 'wan_proto', _('Connection type'));
		o.rmempty = false;
		o.default = 'dhcp';
		o.value('dhcp', _('Automatic (DHCP)'));
		o.value('static', _('Static IP address'));
		o.value('pppoe', _('PPPoE'));

		o = s.taboption('wansetup', form.Value, 'wan_pppoe_user', _('PPPoE username'));
		o.depends('wan_proto', 'pppoe');

		o = s.taboption('wansetup', form.Value, 'wan_pppoe_pass', _('PPPoE password'));
		o.depends('wan_proto', 'pppoe');
		o.password = true;

		o = s.taboption('wansetup', form.Value, 'wan_ipaddr', _('IPv4 address'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';

		o = s.taboption('wansetup', form.Value, 'wan_netmask', _('IPv4 subnet mask'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');

		o = s.taboption('wansetup', form.Value, 'wan_gateway', _('IPv4 gateway'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';

		o = s.taboption('wansetup', form.DynamicList, 'wan_dns', _('Custom DNS servers'));
		o.datatype = 'ip4addr';
		o.cast = 'string';

		if (has_wifi) {
			o = s.taboption('wifisetup', form.Value, 'wifi_ssid', _('Wi-Fi network name'));
			o.datatype = 'maxlength(32)';

			o = s.taboption("wifisetup", form.Value, "wifi_key", _("Wi-Fi password"));
			o.datatype = 'wpakey';
			o.password = true;
		}

		o = s.taboption('lansetup', form.Value, 'lan_ipaddr', _('IPv4 address'));
		o.datatype = 'ip4addr';

		o = s.taboption('lansetup', form.Value, 'lan_netmask', _('IPv4 subnet mask'));
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');

		o = s.taboption('service', form.Flag, "urllogger", _("Status") + ' -> ' + _('URL logging'));
		o.default = 0;
		o.rmempty = false;

		o = s.taboption('service', form.Flag, "qos", _("Network") + ' -> ' + _('QoS'));
		o.default = 0;
		o.rmempty = false;

		o = s.taboption('service', form.Flag, "miniupnpd", _("Services") + ' -> ' + _('UPnP IGD & PCP'));
		o.default = 0;
		o.rmempty = false;

		o = s.taboption('service', form.Flag, "ipv6", _('IPv6'));
		o.default = 0;
		o.rmempty = false;

		o = s.taboption('service', form.Flag, "umdns", _('mDNS'));
		o.default = 0;
		o.rmempty = false;

		o = s.taboption('service', form.Flag, "switch_ports_status", _('Switch Port Status'));
		o.default = 0;
		o.rmempty = false;

		return m.render();
	}
});
