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
		var splitIPv4CIDR = function(value) {
			var parts, prefix, octets, bits, i;

			if (typeof(value) != 'string' || value.indexOf('/') < 0)
				return null;

			parts = value.split('/');
			if (parts.length != 2 || !parts[0] || !parts[1])
				return null;

			prefix = +parts[1];
			if (prefix < 0 || prefix > 32 || prefix != Math.floor(prefix))
				return null;

			octets = [];
			for (i = 0; i < 4; i++) {
				bits = Math.max(Math.min(prefix - (i * 8), 8), 0);
				octets.push(bits ? 256 - Math.pow(2, 8 - bits) : 0);
			}

			return {
				addr: parts[0],
				netmask: octets.join('.')
			};
		};
		var serviceOption = function(name, title, defaultValue) {
			var opt = s.taboption('service', form.ListValue, name, title);
			opt.default = defaultValue || '0';
			opt.rmempty = false;
			opt.widget = 'radio';
			opt.value('1', _('Enable'));
			opt.value('0', _('Disable'));
			return opt;
		};

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
		o.cfgvalue = function(section_id) {
			var value = uci.get('wizard', section_id, 'lan_ipaddr');
			var cidr = splitIPv4CIDR(value);

			return cidr ? cidr.addr : value;
		};

		o = s.taboption('lansetup', form.Value, 'lan_netmask', _('IPv4 subnet mask'));
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.cfgvalue = function(section_id) {
			var cidr = splitIPv4CIDR(uci.get('wizard', section_id, 'lan_ipaddr'));

			return cidr ? cidr.netmask : uci.get('wizard', section_id, 'lan_netmask');
		};

		serviceOption('urllogger', _("Status") + ' -> ' + _('URL logging'));
		serviceOption('qos', _("Network") + ' -> ' + _('QoS'));
		serviceOption('miniupnpd', _("Services") + ' -> ' + _('UPnP IGD & PCP'));
		serviceOption('ipv6', _('IPv6'), '1');
		serviceOption('umdns', _('mDNS'), '1');
		serviceOption('switch_ports_status', _('Switch Port Status'));

		return m.render();
	}
});
