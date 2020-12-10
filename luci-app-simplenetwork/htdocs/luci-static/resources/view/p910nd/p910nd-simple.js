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
			uci.load('p910nd')
		]);
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

		return m.render();
	}
});
