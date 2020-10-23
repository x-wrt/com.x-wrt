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
		o.value('9100');
		o.value('9101');
		o.value('9102');
		o.value('9103');
		o.value('9104');
		o.value('9105');
		o.value('9106');
		o.value('9107');
		o.value('9108');
		o.value('9109');

		o = s.option(form.Flag, 'bidirectional', _('Bidirectional mode'));

		return m.render();
	}
});
