'use strict';
'require view';
'require form';
'require rpc';
'require poll';
'require ui';
'require dom';

var callSettings = rpc.declare({ object: 'luci.cloudflare_tunnel', method: 'settings', expect: { '': {} } });
var callStatus = rpc.declare({ object: 'luci.cloudflare_tunnel', method: 'status', expect: { '': {} } });
var callDeploy = rpc.declare({ object: 'luci.cloudflare_tunnel', method: 'deploy', params: [ 'settings' ], expect: { '': {} } });
var callStop = rpc.declare({ object: 'luci.cloudflare_tunnel', method: 'stop', expect: { '': {} } });
var tokenURL = 'https://dash.cloudflare.com/?to=/:account/api-tokens';

function hostnameValid(value) {
	value = String(value || '').trim().replace(/\.$/, '');
	return value.length <= 253 && value.indexOf('.') > 0 && value.split('.').every(function(label) {
		return label.length > 0 && label.length <= 63 && /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/i.test(label);
	});
}

function checked(reply) {
	// A failed deployment is valid status data and must still render.
	if (reply.error && !reply.phase)
		throw new Error(reply.error.message || _('The operation could not be completed.'));
	return reply;
}

return view.extend({
	load: function() {
		return Promise.all([ callSettings().then(checked), callStatus().then(checked) ]);
	},

	securityNotice: function() {
		return E('div', { class: 'alert-message warning', role: 'note' }, [
			E('strong', {}, _('Your router login page will be public')),
			E('p', {}, _('By default, this feature exposes the router’s management login page to the Internet. Other people can open the domain and attempt to log in. A weak password can be guessed or cracked, putting the router at risk.')),
			E('p', {}, [ _('Set a long, unique router password before enabling remote access.'), ' ',
				E('a', { href: L.url('admin', 'system', 'admin', 'password'), target: '_blank', rel: 'noopener noreferrer' }, _('Set router password')), ' ',
				_('On the password page, select the account you use for Web login.') ])
		]);
	},

	officialLinks: function() {
		function link(url, label) {
			return E('a', { href: url, target: '_blank', rel: 'noopener noreferrer', class: 'cbi-button cbi-button-action' }, label);
		}
		return E('div', { class: 'cf-setup-links' }, [
			E('p', {}, _('Cloudflare setup: create an account, add your domain, then create an API token.')),
			E('div', { class: 'cf-link-actions' }, [
				link('https://dash.cloudflare.com/sign-up', _('Register a Cloudflare account')), ' ',
				link('https://dash.cloudflare.com/', _('Manage domains')), ' ',
				link(tokenURL, _('Create API Token'))
			])
		]);
	},

	copyLink: function(url) {
		function fallback() {
			var previous = document.activeElement;
			var field = E('textarea', { readonly: 'readonly', tabindex: '-1', 'aria-hidden': 'true',
				style: 'position: fixed; left: -9999px; top: 0' });
			field.value = url;
			document.body.appendChild(field);
			try {
				field.select();
				if (!document.execCommand('copy')) throw new Error('Copy failed');
				return Promise.resolve();
			}
			catch (error) {
				return Promise.reject(error);
			}
			finally {
				field.remove();
				if (previous && previous.focus) previous.focus();
			}
		}
		var operation = window.isSecureContext && navigator.clipboard
			? navigator.clipboard.writeText(url).catch(fallback) : fallback();
		return operation.then(function() {
			ui.addNotification(null, E('p', {}, _('Link copied.')), 'info');
		}).catch(function() {
			ui.addNotification(null, E('p', {}, _('Could not copy the link. Select the access address and copy it manually.')), 'error');
		});
	},

	tokenGuide: function() {
		return E('details', { id: 'cf-token-guide' }, [
			E('summary', {}, _('How to create a CF API Token')),
			E('ol', {}, [
				E('li', {}, [ _('Open') + ' ', E('a', { href: tokenURL, target: '_blank', rel: 'noopener noreferrer' }, _('Account API Tokens')), '. ',
					_('Select the account that owns your domain, choose Create Token, and give it a name.') ]),
				E('li', {}, _('Add all three permissions below to the same token.')),
				E('li', {}, _('Choose the account and zone resource scopes described below.')),
				E('li', {}, _('Select Continue to summary → Create Token, then paste the generated token into CF API Token.'))
			]),
			E('table', { class: 'table' }, [
				E('tr', { class: 'tr table-titles' }, [ E('th', { class: 'th' }, _('Type')), E('th', { class: 'th' }, _('Permission')), E('th', { class: 'th' }, _('Access')) ]),
				E('tr', { class: 'tr' }, [ E('td', { class: 'td' }, 'Account'), E('td', { class: 'td' }, 'Cloudflare Tunnel'), E('td', { class: 'td' }, 'Edit') ]),
				E('tr', { class: 'tr' }, [ E('td', { class: 'td' }, 'Zone'), E('td', { class: 'td' }, 'DNS'), E('td', { class: 'td' }, 'Edit') ]),
				E('tr', { class: 'tr' }, [ E('td', { class: 'td' }, 'Zone'), E('td', { class: 'td' }, 'Zone'), E('td', { class: 'td' }, 'Read') ])
			]),
			E('p', {}, [ E('strong', {}, _('Specific resources (recommended)') + ': '),
				_('Create the token in the domain’s account. Limit zone permissions to the specific domain you want to use.') ]),
			E('p', {}, [ E('strong', {}, _('Simple resource selection') + ': '),
				_('Select All zones in the current account. The same three permissions apply to all domains in this account.') ]),
			E('p', {}, _('To update an existing token, open Edit on the Account API Tokens page, keep all three permissions, and save the zone scopes.'))
		]);
	},

	updateStatus: function(status) {
		if (typeof(status.token_saved) === 'boolean')
			this.tokenSaved = status.token_saved;
		var busy = status.phase === 'deploying';
		this.deployButton.disabled = this.readonly || busy;
		this.stopButton.disabled = this.readonly || busy || (!status.running && !status.hostname);
		// Keep links and keyboard focus mounted when polling changes nothing visible.
		var fingerprint = JSON.stringify([ status.phase, status.stage, status.connected,
			status.hostname, status.https_ok, status.dns_cache_pending, status.error,
			status.warnings, this.tokenSaved ]);
		if (this.statusFingerprint === fingerprint) return;
		this.statusFingerprint = fingerprint;
		var stages = {
			zone: _('Finding the Cloudflare zone…'),
			tunnel: _('Creating or reusing this router’s tunnel…'),
			dns: _('Configuring DNS…'),
			configure: _('Updating the tunnel route…'),
			start: _('Starting the tunnel…'),
			https: _('Checking the HTTPS address…')
		};
		var label = {
			unconfigured: _('Not configured'),
			deploying: stages[status.stage] || _('Deploying…'),
			ready: status.https_ok ? _('Connected — HTTPS verified') : _('Connected — HTTPS verification pending'),
			connecting: _('Connecting…'),
			stopped: _('Stopped'),
			error: _('Deployment failed')
		}[status.phase] || _('Not configured');
		var phaseTone = status.phase === 'error' ? 'danger'
			: busy || status.phase === 'connecting' || (status.phase === 'ready' && !status.https_ok) ? 'warning'
			: status.phase === 'ready' ? 'success' : 'muted';
		var connectionTone = status.connected ? 'success'
			: busy || status.phase === 'connecting' ? 'warning'
			: status.phase === 'error' ? 'danger' : 'muted';
		var children = [ E('div', { class: 'cf-status-heading' }, [
			E('h3', {}, _('Tunnel connection')),
			E('strong', { class: 'cf-connection-state cf-state-' + connectionTone }, status.connected ? _('Connected') : _('Disconnected'))
		]), E('p', {}, [ E('span', { class: 'cf-state-label cf-state-' + phaseTone, role: 'status' }, label) ]) ];
		children.push(E('p', { class: 'cf-token-state' }, [ E('strong', {}, _('CF API Token') + ': '),
			this.tokenSaved ? _('Token saved — leave blank to keep it') : _('Token not saved') ]));
		if (status.hostname && hostnameValid(status.hostname)) {
			var url = 'https://' + status.hostname + '/';
			children.push(E('div', { class: 'cf-access' }, [
				E('div', { class: 'cf-access-address' }, [ E('strong', {}, _('Access address')),
					E('a', { href: url, target: '_blank', rel: 'noopener noreferrer' }, url) ]),
				E('div', { class: 'cf-link-actions' }, [
					E('a', { class: 'cbi-button cbi-button-action', href: url, target: '_blank', rel: 'noopener noreferrer' }, _('Visit router')),
					E('button', { type: 'button', class: 'cbi-button cbi-button-neutral', click: ui.createHandlerFn(this, 'copyLink', url) }, _('Copy link')) ]) ]));
		}
		if (status.error)
			children.push(E('p', { class: 'alert-message warning', style: 'white-space: pre-wrap' }, status.error.message));
		if (status.phase === 'ready' && !status.https_ok)
			children.push(E('p', {}, _('The tunnel is connected, but HTTPS is not verified yet. DNS caches or certificate issuance may need more time. Retry deployment to check again.')));
		if (status.dns_cache_pending)
			children.push(E('p', {}, _('Public HTTPS is verified. If the link still opens an old website, allow the local DNS cache to refresh.')));
		(status.warnings || []).forEach(function(message) {
			children.push(E('p', { class: 'alert-message warning' }, message));
		});
		dom.content(this.statusNode, children);
	},

	refreshStatus: function() {
		return callStatus().then(checked).then(this.updateStatus.bind(this));
	},

	deploy: function() {
		var self = this;
		return this.map.save(function() {
			var values = self.map.data.get('json', 'main');
			self.deployButton.disabled = true;
			return callDeploy({ hostname: values.hostname, api_token: values.api_token || '' }).then(checked).then(function() {
				self.tokenSaved = true;
				self.map.data.set('json', 'main', 'api_token', '');
				var input = self.tokenOption.getUIElement('main');
				if (input) input.setValue('');
				return self.refreshStatus();
			});
		}).catch(function(error) {
			ui.addNotification(null, E('p', {}, error.message), 'error');
			self.deployButton.disabled = self.readonly;
		});
	},

	stop: function() {
		ui.showModal(_('Stop tunnel'), [
			E('p', {}, _('Remote access through this domain will stop. Your saved settings will be kept.')),
			E('div', { class: 'right' }, [
				E('button', { type: 'button', class: 'cbi-button cbi-button-neutral', click: ui.hideModal }, _('Cancel')), ' ',
				E('button', { type: 'button', class: 'cbi-button cbi-button-negative', click: ui.createHandlerFn(this, 'confirmStop') }, _('Stop tunnel')) ])
		]);
	},

	confirmStop: function() {
		var self = this;
		ui.hideModal();
		this.stopButton.disabled = true;
		return callStop().then(checked).then(function() {
			return self.refreshStatus();
		}).catch(function(error) {
			ui.addNotification(null, E('p', {}, error.message), 'error');
			return self.refreshStatus();
		});
	},

	render: function(data) {
		var self = this, settings = data[0], m, s, o;
		this.readonly = !L.hasViewPermission();
		this.tokenSaved = settings.token_saved === true;
		m = new form.JSONMap({ main: { hostname: settings.hostname || '', api_token: '' } });
		m.readonly = this.readonly;
		s = m.section(form.NamedSection, 'main', 'main');
		s.addremove = false;

		o = s.option(form.Value, 'api_token', _('CF API Token'),
			_('Use one token with Account → Cloudflare Tunnel → Edit, Zone → DNS → Edit, and Zone → Zone → Read. Include the zone’s account and domain in its resource scopes. Leave blank to keep the saved token.'));
		o.password = true;
		o.rmempty = true;
		o.validate = function(section, value) {
			if (!value && self.tokenSaved) return true;
			return /^[A-Za-z0-9_-]{20,512}$/.test((value || '').trim()) ? true : _('Enter a Cloudflare API token.');
		};
		this.tokenOption = o;

		o = s.option(form.Value, 'hostname', _('Access hostname'),
			_('The domain must already be active in your Cloudflare account. Use a first-level subdomain, such as abc.example.com, for the free HTTPS certificate.'));
		o.placeholder = 'abc.example.com';
		o.rmempty = false;
		o.validate = function(section, value) {
			return hostnameValid(value) ? true : _('Enter a complete hostname, such as abc.example.com.');
		};

		this.map = m;
		this.statusNode = E('section', { class: 'cbi-section cf-status', 'aria-label': _('Tunnel connection') });
		this.deployButton = E('button', { class: 'cbi-button cbi-button-positive', disabled: true,
			click: ui.createHandlerFn(this, 'deploy') }, _('Save and deploy'));
		this.stopButton = E('button', { class: 'cbi-button cbi-button-negative', disabled: true,
			click: ui.createHandlerFn(this, 'stop') }, _('Stop tunnel'));
		return m.render().then(function(node) {
			self.updateStatus(data[1]);
			poll.add(function() { return self.refreshStatus(); }, 8);
			return E('div', { class: 'cf-tunnel' }, [
				E('link', { rel: 'stylesheet', href: L.resource('view/cloudflare-tunnel/config.css') }),
				E('h2', {}, _('Cloudflare Tunnel')),
				E('p', {}, _('Enter a Cloudflare API token and a complete access hostname, such as abc.example.com. The plugin automatically publishes this router’s management page.')),
				self.statusNode, self.securityNotice(),
				E('section', { class: 'cbi-section cf-configuration' }, [
					E('h3', {}, _('Tunnel settings')), node,
					E('div', { class: 'cbi-page-actions' }, [ self.stopButton, ' ', self.deployButton ]) ]),
				E('section', { class: 'cbi-section cf-help' }, [
					E('h3', {}, _('Cloudflare setup guide')), self.officialLinks(), self.tokenGuide() ]) ]);
		});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
