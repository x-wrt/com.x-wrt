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
			uci.load('autoreboot'),
		]);
	},

	render: function(data) {

		var m, s, o;

		m = new form.Map('autoreboot', [_('Scheduled Reboot')],
			_('Scheduled reboot Setting'));

		s = m.section(form.TypedSection, 'main');
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Flag, "enable", _("Enable"));
		o.rmempty = false;
		o.default = 0;

		o = s.option(form.ListValue, "week", _("Week Day"));
		o.value(7, _("Everyday"));
		o.value(1, _("Monday"));
		o.value(2, _("Tuesday"));
		o.value(3, _("Wednesday"));
		o.value(4, _("Thursday"));
		o.value(5, _("Friday"));
		o.value(6, _("Saturday"));
		o.value(0, _("Sunday"));
		o.default = 0;

		o = s.option(form.ListValue, "hour", _("Hour"));
		o.datatype = "range(0,23)";
		o.rmempty = false;
		for (var i = 0; i < 24; i++) {
			o.value(i, "%02d".format(i));
		}

		o = s.option(form.ListValue, "minute", _("Minute"));
		o.datatype = "range(0,59)";
		o.rmempty = false;
		for (var i = 0; i < 60; i++) {
			o.value(i, "%02d".format(i));
		}

		return m.render();
	}
});
