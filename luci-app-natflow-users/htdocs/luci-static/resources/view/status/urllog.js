'use strict';
'require view';
'require fs';
'require poll';
'require ui';

var hasNotifiedLogErr = false;

return view.extend({
	retrieveLog: async function() {
		return fs.exec_direct('/bin/cat', [ '/tmp/url.log' ]).then(function(logdata) {
			hasNotifiedLogErr = false;
			const loglines = (logdata || '').trim().split(/\n/);
			return { value: loglines.join('\n'), rows: loglines.length + 1 };
		}).catch(function(err) {
			if (!hasNotifiedLogErr) {
				hasNotifiedLogErr = true;
				ui.addNotification(null, E('p', {}, _('Unable to load log data: %s').format(err.message || err)));
			}
			return { value: _('Log data is unavailable'), rows: 10 };
		});
	},

	pollLog: async function() {
		const element = document.getElementById('syslog');
		if (element) {
			const log = await this.retrieveLog();
			element.value = log.value;
			element.rows = log.rows;
		}
	},

	load: async function() {
		poll.add(this.pollLog.bind(this));
		return await this.retrieveLog();
	},

	render: function(loglines) {
		var scrollDownButton = E('button', {
				'id': 'scrollDownButton',
				'class': 'cbi-button cbi-button-neutral'
			}, _('Scroll to tail', 'scroll to bottom (the tail) of the log file')
		);
		scrollDownButton.addEventListener('click', function() {
			scrollUpButton.focus();
		});

		var scrollUpButton = E('button', {
				'id' : 'scrollUpButton',
				'class': 'cbi-button cbi-button-neutral'
			}, _('Scroll to head', 'scroll to top (the head) of the log file')
		);
		scrollUpButton.addEventListener('click', function() {
			scrollDownButton.focus();
		});

		return E([], [
			E('h2', {}, [ _('URL Log') ]),
			E('div', { 'id': 'content_urllog' }, [
				E('div', {'style': 'padding-bottom: 20px'}, [scrollDownButton]),
				E('textarea', {
					'id': 'syslog',
					'style': 'font-size:12px',
					'readonly': 'readonly',
					'wrap': 'off',
					'rows': loglines.rows,
				}, [ loglines.value ]),
				E('div', {'style': 'padding-bottom: 20px'}, [scrollUpButton])
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
