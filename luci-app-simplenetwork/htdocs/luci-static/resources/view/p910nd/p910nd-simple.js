'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require form';

var callUsbInfo = rpc.declare({
        object: 'luci.usb',
        method: 'info'
});

var callWwanStatus = rpc.declare({
	object: 'network.interface.wwan',
	method: 'status',
	expect: { }
});

var callWanStatus = rpc.declare({
	object: 'network.interface.wan',
	method: 'status',
	expect: { }
});

var callLanStatus = rpc.declare({
	object: 'network.interface.lan',
	method: 'status',
	expect: { }
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('p910nd'),
			L.resolveDefault(callUsbInfo(), [])
		]);
	},

	poll_status: function(map, data) {
		var wwan = data[1];
		var wan = data[2];
		var lan = data[3];
		var usb_status = map.querySelector('[data-name="_usb_status"]').querySelector('.cbi-value-field');
		var wwan_status = map.querySelector('[data-name="_usb_wwan_ip"]').querySelector('.cbi-value-field');
		var wan_status = map.querySelector('[data-name="_usb_wan_ip"]').querySelector('.cbi-value-field');
		var lan_status = map.querySelector('[data-name="_usb_lan_ip"]').querySelector('.cbi-value-field');

		//console.log(data);
		try {
			var info = data[0]['info'];
			if (info) {
				usb_status.innerHTML = '<p style="color:green;"><b>' + _('Connected') + ': ' + info + '</b></p>';
			} else {
				usb_status.innerHTML = '<p style="color:red;"><b>' + _('Printer not detected. Please check if the USB printer is properly connected.') + '</b></p>';
			}
		} catch(err) {
			usb_status.innerHTML = '<p style="color:red;"><b>' + _('Printer not detected. Please check if the USB printer is properly connected.') + '</b></p>';
		}

		if (wwan['ipv4-address'] && wwan['ipv4-address'][0] && wwan['ipv4-address'][0]['address'])
			wwan = wwan['ipv4-address'][0]['address'];
		else
			wwan = "-";

		if (wan['ipv4-address'] && wan['ipv4-address'][0] && wan['ipv4-address'][0]['address'])
			wan = wan['ipv4-address'][0]['address'];
		else
			wan = "-";

		if (lan['ipv4-address'] && lan['ipv4-address'][0] && lan['ipv4-address'][0]['address'])
			lan = lan['ipv4-address'][0]['address'];
		else
			lan = "-";

		wwan_status.innerHTML = wwan;
		wan_status.innerHTML = wan;
		lan_status.innerHTML = lan;
	},

	render: function(data) {

		var m, s, o;

		m = new form.Map('p910nd', [_('USB Print Service (RAW)')]);

		s = m.section(form.TypedSection, 'p910nd', "USB1");
		s.addremove = false;
		s.anonymous = true

		o = s.option(form.Flag, 'enabled', _('Enable Print Service'));

		o = s.option(form.ListValue, 'port', _('Port'));
		o.rmempty = true;
		o.value('0', '9100');
		o.value('1', '9101');
		o.value('2', '9102');
		o.value('3', '9103');
		o.value('4', '9104');
		o.value('5', '9105');
		o.value('6', '9106');
		o.value('7', '9107');
		o.value('8', '9108');
		o.value('9', '9109');

		o = s.option(form.Flag, 'bidirectional', _('Bidirectional mode'));

		o = s.option(form.DummyValue, '_usb_status', _('Status'));
		o.modalonly = false;
		o.default = _('Loading..');

		o = s.option(form.DummyValue, '_usb_wwan_ip', _('WiFi STA'));
		o.modalonly = false;
		o.default = '-';

		o = s.option(form.DummyValue, '_usb_wan_ip', _('LAN Port') + "(" + _('auto') + ")");
		o.modalonly = false;
		o.default = '-';

		o = s.option(form.DummyValue, '_usb_lan_ip', _('Management IP'));
		o.modalonly = false;
		o.default = '-';

		return m.render().then(L.bind(function(m, nodes) {
			//this.poll_status(nodes, data[3]);
			poll.add(L.bind(function() {
				return Promise.all([
					L.resolveDefault(callUsbInfo(), {}),
					L.resolveDefault(callWwanStatus(), {}),
					L.resolveDefault(callWanStatus(), {}),
					L.resolveDefault(callLanStatus(), {})
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), 5);
			return nodes;
		}, this, m));
	}
});
