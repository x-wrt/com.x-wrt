'use strict';
'require view';
'require dom';
'require poll';
'require ui';
'require uci';
'require rpc';
'require form';
'require network';

var callWwanStatus = rpc.declare({
    object: 'network.interface.wwan',
    method: 'status',
    expect: { }
});

var ssidValid = function(ssid) {
	if (ssid.startsWith('None')) {
		return 'none';
	} else if (ssid.startsWith('WPA2 PSK')) {
		return 'psk2';
	} else if (ssid.startsWith('WPA PSK')) {
		return 'psk';
	} else if (ssid.startsWith('mixed WPA/WPA2 PSK')) {
		return 'psk-mixed';
	}

	return null;
}

var findEncryptionBySsid = function(scanRes, ssid) {
    for (var i = 0; i < scanRes.length; i++) {
        if (scanRes[i].ssid == ssid) {
            return ssidValid(network.formatWifiEncryption(scanRes[i].encryption));
        }
    }
    return '';
}

var wwan_status_cnt = 0;
return view.extend({
	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			classes.ui.changes.apply(mode == '1');
		});
	},
	load: function() {
		return Promise.all([
			uci.changes(),
			uci.load('network'),
			uci.load('wireless'),
			L.resolveDefault(callWwanStatus(), [])
		]);
	},

	_this: this,

	startScan: false,
	ssidOpt: null,

	handleScan: function(m, ev) {
		this.startScan = true;
		this.ssidOpt.keylist = [];
		this.ssidOpt.vallist = [];
		return m.render();
	},

	poll_status: function(map, data) {
		var wwan_status = map.querySelector('[data-name="_wwan_status"]').querySelector('.cbi-value-field');
		var status_ipaddr = map.querySelector('[data-name="_status_ipaddr"]').querySelector('.cbi-value-field');
		var status_netmask = map.querySelector('[data-name="_status_netmask"]').querySelector('.cbi-value-field');
		var status_gateway = map.querySelector('[data-name="_status_gateway"]').querySelector('.cbi-value-field');
		var status_dns = map.querySelector('[data-name="_status_dns"]').querySelector('.cbi-value-field');

		//console.log(data);
		try {
			if (data.length == 1) {
				var ipaddr = data[0]['ipv4-address'][0]['address'];
				var netmask = network.prefixToMask(+data[0]['ipv4-address'][0]['mask']);
				var gateway = '0.0.0.0';
				var dns = data[0]['dns-server'];
				var routes = data[0]['route'];

				for (var x = 0; x < routes.length; x++) {
					if (routes[x].target == '0.0.0.0' && routes[x].mask == 0) {
						gateway = routes[x].nexthop;
						break;
					}
				}

				status_ipaddr.innerHTML = ipaddr;
				status_netmask.innerHTML = netmask;
				status_gateway.innerHTML = gateway;
				if (dns.length > 0) {
					status_dns.innerHTML = dns[0];
					for (var x = 1; x < dns.length; x++) {
						status_dns.innerHTML = status_dns.innerHTML + " " + dns[x];
					}
				} else {
					status_dns.innerHTML = '-';
				}

				wwan_status.innerHTML = '<p style="color:green;"><b>' + _('Connected') + '</b></p>';
			}
		} catch(err) {
			status_ipaddr.innerHTML = '-';
			status_netmask.innerHTML = '-';
			status_gateway.innerHTML = '-';
			status_dns.innerHTML = '-';

			if (uci.get('wireless', 'wifinet2', 'disabled', 0) == 1) {
				wwan_status_cnt = 3;
			}
			if (wwan_status_cnt == 0) {
				wwan_status_cnt = 1;
				wwan_status.innerHTML = '<p style="color:black;"><b>' + _('Loading...') + '</b></p>';
			} else if (wwan_status_cnt == 1) {
				wwan_status_cnt = 2;
				wwan_status.innerHTML = '<p style="color:black;"><b>' + _('Loading...') + '</b></p>';
			} else if (wwan_status_cnt == 2) {
				wwan_status.innerHTML = '<p style="color:red;"><b>' + _('Not connected, Please check your settings') + '</b></p>';
			} else {
				wwan_status.innerHTML = '<p style="color:red;"><b>' + _('Not connected') + '</b></p>';
			}
		}
	},

	render: function(data) {
		var m, s, ss, o;
		var _this = this;
		var scanRes = {};

		m = new form.Map('wireless', [_('Wireless STA')],
			_('Configure the WiFi STA'));
		m.chain('network');

		s = m.section(form.NamedSection, 'wifinet2', 'wifi-iface');
		s.addremove = false;

		o = s.option(form.Flag, 'disabled', _('Enable'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.enabled;
		o.onchange = function(ev, section, value) {
			if (value == 1) {
				uci.set('wireless', 'wifinet2', 'disabled', value);
			} else {
				uci.unset('wireless', 'wifinet2', 'disabled');
			}
			return this.map.save();
		}

		o = s.option(form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
		o.datatype = 'maxlength(32)';
		_this.ssidOpt = o;
		o.onchange = function(ev, section_id, value) {
			var enc = findEncryptionBySsid(scanRes, value);
			if (enc) {
				uci.set('wireless', 'wifinet2', 'encryption', enc);
				uci.set('wireless', 'wifinet2', 'ssid', value);
				if (_this.encOpt)
					_this.encOpt.default = enc;
				this.map.render();
			}
			return true;
		};
		o.render = function(option_index, section_id, in_table) {
			var current_ssid = uci.get('wireless', 'wifinet2', 'ssid');
			if (_this.startScan == false) {
				if (current_ssid != undefined) {
					this.value(current_ssid);
				}
				return form.Value.prototype.render.apply(this, [ option_index, section_id, in_table ]);
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

					scanRes = results;

					for (var i = 0; i < results.length; i++) {
						if (results[i].ssid == undefined) {
							//alert(results[i].ssid);
							continue;
						}
						if (ssidValid(network.formatWifiEncryption(results[i].encryption)) == null) {
							continue;
						}
						this.value(results[i].ssid, results[i].ssid + " (" + _('Channel') + " " + results[i].channel + " " + network.formatWifiEncryption(results[i].encryption) + ")");
						if (current_ssid == results[i].ssid) {
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

		o = s.option(form.Button, '_scan');
		o.title = '&#160;';
		o.inputtitle = _('SCAN WiFi');
		o.inputstyle = 'apply';
		o.onclick = L.bind(this.handleScan, this, m);

		o = s.option(form.Value, 'key', _('Key'));
		o.rmempty = true;
		o.datatype = 'wpakey';
		o.validate = function(section_id, value) {
			// Find the selected SSID
			var _ssid = this.map.lookupOption('ssid', section_id);
			var ssid = _ssid ? _ssid[0].formvalue(section_id) : null;
			var enc = '';
			if (scanRes && ssid) {
				enc = findEncryptionBySsid(scanRes, ssid);
			}
			// If encryption type is not 'none', key must be 8-63 chars and non-empty
			if (enc && enc !== 'none') {
				if (!value || value.length < 8 || value.length > 63) {
					return _('key between 8 and 63 characters');
				}
			}
			// If encryption is 'none', allow empty key
			return true;
		};

		o = s.option(form.DummyValue, '_wwan_status', _('Status'));
		o.modalonly = false;
		o.default = _('Loading..');

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
		o.rmempty = false;

		o = ss.option(form.Value, 'netmask', _('IPv4 netmask'));
		o.depends('proto', 'static');
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.rmempty = false;

		o = ss.option(form.Value, 'gateway', _('IPv4 gateway'));
		o.depends('proto', 'static');
		o.datatype = 'ip4addr';

		o = ss.option(form.DynamicList, 'dns', _('Use custom DNS servers'));
		o.datatype = 'ip4addr';
		o.cast = 'string';

		o = ss.option(form.DummyValue, '_status_ipaddr', _('IPv4 address'));
		o.depends('proto', 'dhcp');
		o.modalonly = false;
		o.default = '-';

		o = ss.option(form.DummyValue, '_status_netmask', _('IPv4 netmask'));
		o.depends('proto', 'dhcp');
		o.modalonly = false;
		o.default = '-';

		o = ss.option(form.DummyValue, '_status_gateway', _('IPv4 gateway'));
		o.depends('proto', 'dhcp');
		o.modalonly = false;
		o.default = '-';

		o = ss.option(form.DummyValue, '_status_dns', _('DNS'));
		o.depends('proto', 'dhcp');
		o.modalonly = false;
		o.default = '-';

		return m.render().then(L.bind(function(m, nodes) {
			//this.poll_status(nodes, data[3]);
			poll.add(L.bind(function() {
				return Promise.all([
					L.resolveDefault(callWwanStatus(), [])
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), 5);
			return nodes;
		}, this, m));
	}
});
