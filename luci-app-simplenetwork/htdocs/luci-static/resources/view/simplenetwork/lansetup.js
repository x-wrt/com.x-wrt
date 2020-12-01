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
			uci.load('network')
		]);
	},

	render: function(data) {

		var m, s, o;

		m = new form.Map('network', [_('LAN Port')],
			_('Configure the lan port network'));

		s = m.section(form.NamedSection, 'lan', 'interface');
		s.addremove = false;

		o = s.option(form.Value, 'ipaddr', _('IPv4 address'));
		o.datatype = 'ip4addr';
		o.rmempty = false;

		o = s.option(form.Value, 'netmask', _('IPv4 netmask'));
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.rmempty = false;

		s = m.section(form.NamedSection, 'wan', 'interface', _('LAN Port') + "(" + _('auto') + ")");
		s.addremove = false;

		o = s.option(form.ListValue, 'wan_proto', _('Protocol'));
		o.rmempty = false;
		o.value('dhcp', _('DHCP client'));
		o.value('static', _('Static address'));
		o.ucioption = 'proto';

		o = s.option(form.Value, 'wan_ipaddr', _('IPv4 address'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.rmempty = false;
		o.ucioption = 'ipaddr';

		o = s.option(form.Value, 'wan_netmask', _('IPv4 netmask'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.value('255.255.255.0');
		o.value('255.255.0.0');
		o.value('255.0.0.0');
		o.rmempty = false;
		o.ucioption = 'netmask';

		o = s.option(form.Value, 'wan_gateway', _('IPv4 gateway'));
		o.depends('wan_proto', 'static');
		o.datatype = 'ip4addr';
		o.ucioption = 'gateway';

		o = s.option(form.DynamicList, 'wan_dns', _('Use custom DNS servers'));
		o.datatype = 'ip4addr';
		o.cast = 'string';
		o.ucioption = 'dns';

		return m.render();
	}
});
