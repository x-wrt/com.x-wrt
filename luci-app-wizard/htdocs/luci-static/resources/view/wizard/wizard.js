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
		var serviceOption = function(name, title, defaultValue, alt) {
			var opt = s.taboption('service', form.ListValue, name, title, alt);
			opt.default = defaultValue || '0';
			opt.rmempty = false;
			opt.widget = 'radio';
			opt.value('1', _('Enable'));
			opt.value('0', _('Disable'));
			return opt;
		};
		var kmodOption = function(name, title, defaultValue, description) {
			var opt = s.taboption('kmods', form.ListValue, name, title, description);
			opt.default = defaultValue || '1';
			opt.rmempty = false;
			opt.widget = 'radio';
			opt.value('1', _('Load (Keep in filesystem)'));
			opt.value('0', _('Do not load (Delete from filesystem)'));
			return opt;
		};

		if (uci.sections('wireless', 'wifi-device').length > 0) {
			has_wifi = true;
		}

		m = new form.Map('wizard', [_('Router Setup Wizard')],
			_('Configure the basic Internet, Wi-Fi, local network, optional service, and kernel module settings for this router.'));

		s = m.section(form.NamedSection, 'default', 'wizard');
		s.addremove = false;
		s.tab('wansetup', _('Internet Settings'), _('Choose how this router connects to the Internet.'));
		if (has_wifi) {
			s.tab('wifisetup', _('Wi-Fi Settings'), _('Set the Wi-Fi network name and password. For advanced options, go to Network > Wireless.'));
		}
		s.tab('lansetup', _('Local Network'));

		s.tab('service', _('Optional Services'), _('Turn off unused services to reduce memory usage.'));
		s.tab('kmods', _('Kernel Modules'), _('Select kernel modules to enable or disable to optimize memory usage. Disabled modules will be removed from the filesystem, while enabled ones will be restored from /rom/. Note: Modifying these options requires restarting the device to take effect.'));

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

		serviceOption('urllogger', _("Status") + ' -> ' + _('URL logging'), '0');
		serviceOption('qos', _("Network") + ' -> ' + _('Traffic Shaping'), '0');
		serviceOption('miniupnpd', _("Services") + ' -> ' + _('UPnP IGD & PCP'), '0');
		serviceOption('ipv6', _('IPv6'), '1', _('If disabled, IPv6 services will not be provided on the local network.'));
		serviceOption('umdns', _('mDNS'), '1', _('It is recommended not to disable this service if using FakeMesh.'));
		serviceOption('switch_ports_status', _('Switch Port Status'), '0', _('This service can usually be disabled. If disabled, it will not respond to switch port hotplug events.'));

		kmodOption('kmod_wireguard', _('WireGuard (wireguard)'), '1', _('WireGuard VPN encrypted tunnel driver. If you do not use WireGuard, disable it to save memory.'));
		kmodOption('kmod_openvpn_tun', _('OpenVPN & TUN (ovpn, tun)'), '1', _('OpenVPN kernel acceleration module (ovpn) and TUN/TAP virtual network device driver.'));
		kmodOption('kmod_gre_sit', _('GRE & SIT Tunnels (ip_gre, ip6_gre, sit)'), '1', _('GRE cross-network packet encapsulation and IPv6-in-IPv4 (SIT) protocol tunnel drivers.'));
		kmodOption('kmod_vlan', _('IPVLAN & MACVLAN (ipvlan, macvlan)'), '1', _('IPVLAN and MACVLAN virtual network interface drivers, commonly used for multi-WAN or container networking.'));
		kmodOption('kmod_qos', _('QoS & Traffic Control (sch_cake, sch_htb, cls_*)'), '1', _('CAKE / HTB traffic shaping queue disciplines and TC packet classifiers. Can be disabled if traffic shaping is not needed.'));
		kmodOption('kmod_alg', _('NAT Helpers / ALG (sip, h323, pptp, ftp, etc.)'), '1', _('Application Layer Gateway (ALG) NAT helpers for legacy protocols such as SIP, H.323, PPTP, FTP, TFTP.'));
		kmodOption('kmod_crypto', _('Cryptodev & AF_ALG (cryptodev, algif_*)'), '1', _('User-space hardware crypto engine (/dev/crypto) and AF_ALG socket crypto interfaces.'));
		kmodOption('kmod_usb', _('USB Core Driver (usbcore, usb-common)'), '1', _('USB core bus driver stack. Can be disabled if the router has no USB ports or no USB devices.'));
		kmodOption('kmod_ppp', _('PPPoE & PPTP Dialers (pppoe, pptp, ppp_generic)'), '1', _('PPPoE broadband dialer and PPTP protocol drivers. Can be disabled if using static IP or DHCP WAN.'));

		return m.render();
	}
});
