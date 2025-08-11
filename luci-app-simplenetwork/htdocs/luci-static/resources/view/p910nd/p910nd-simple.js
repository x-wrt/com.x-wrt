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

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('p910nd'),
			L.resolveDefault(callUsbInfo(), [])
		]);
	},

	poll_status: function(map, data) {
		var usb_status = map.querySelector('[data-name="_usb_status"]').querySelector('.cbi-value-field');

		//console.log(data);
		try {
			var info = data[0]['info'];
			if (data.length == 1 && info) {
				usb_status.innerHTML = '<p style="color:green;"><b>' + _('Connected') + ': ' + info + '</b></p>';
			} else {
				usb_status.innerHTML = '<p style="color:red;"><b>' + _('Printer not detected. Please check if the USB printer is properly connected.') + '</b></p>';
			}
		} catch(err) {
			usb_status.innerHTML = '<p style="color:red;"><b>' + _('Printer not detected. Please check if the USB printer is properly connected.') + '</b></p>';
		}
	},

	render: function(data) {

		var m, s, o;

		m = new form.Map('p910nd', [_('RAW Printer server')]);

		s = m.section(form.TypedSection, 'p910nd', "USB1");
		s.addremove = false;
		s.anonymous = true

		o = s.option(form.Flag, 'enabled', _('TCP/IP RAW'));

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

		return m.render().then(L.bind(function(m, nodes) {
			//this.poll_status(nodes, data[3]);
			poll.add(L.bind(function() {
				return Promise.all([
					L.resolveDefault(callUsbInfo(), [])
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), 5);
			return nodes;
		}, this, m));
	}
});
