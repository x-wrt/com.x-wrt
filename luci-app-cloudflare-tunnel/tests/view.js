// Exercise the production LuCI view with small UI/RPC stubs, without a browser.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../htdocs/luci-static/resources/view/cloudflare-tunnel/config.js'), 'utf8');
const state = { saved: [], rpc: [], polling: [], notifications: [], modal: null, renders: 0 };
const E = (tag, attrs, children) => {
	if (children === undefined) { children = attrs; attrs = {}; }
	return { tag, attrs: attrs || {}, children: Array.isArray(children) ? children : [children], disabled: !!(attrs && attrs.disabled) };
};
const text = node => node == null ? '' : typeof node === 'string' ? node : (node.children || []).map(text).join('');
const walk = node => !node || typeof node !== 'object' ? [] : [node].concat((node.children || []).flatMap(walk));
class JSONMap {
	constructor(values) {
		this.values = values;
		this.options = [];
		this.data = { get: (_, key) => this.values[key], set: (_, key, field, value) => { this.values[key][field] = value; } };
	}
	section() {
		return { option: (_, name) => {
			const option = { name, getUIElement: () => ({setValue: value => { this.values.main[name] = value; }}) };
			this.options.push(option);
			return option;
		} };
	}
	render() { return Promise.resolve(E('form', {}, [])); }
	save(fn) { return Promise.resolve().then(fn); }
}
const settings = { hostname: 'abc.example.com', api_token: '', token_saved: true };
let status = { phase: 'ready', connected: true, running: true, hostname: 'abc.example.com', https_ok: true };
const rpc = { declare: spec => (...args) => {
	state.rpc.push({method: spec.method, args});
	if (spec.method === 'settings') return Promise.resolve(settings);
	if (spec.method === 'status') return Promise.resolve(status);
	if (spec.method === 'deploy') { state.saved.push(args[0]); return Promise.resolve({accepted: true}); }
	return Promise.resolve({stopped: true});
} };
const clipboard = [];
const view = new Function('view', 'form', 'rpc', 'poll', 'ui', 'dom', 'E', '_', 'L', 'window', 'navigator', source)(
	{extend: value => value}, {JSONMap}, rpc, {add: (fn, seconds) => state.polling.push({fn, seconds})},
	{createHandlerFn: (owner, name, ...args) => owner[name].bind(owner, ...args), addNotification: (...args) => state.notifications.push(args),
		showModal: (title, children) => {state.modal = E('div', {}, children);}, hideModal: () => {state.modal = null;}},
	{content: (node, children) => {state.renders++; node.children = children;}}, E, value => value,
	{hasViewPermission: () => true, url: (...parts) => '/cgi-bin/luci/' + parts.join('/'), resource: path => '/luci-static/resources/' + path},
	{isSecureContext: true}, {clipboard: {writeText: value => {clipboard.push(value); return Promise.resolve();}}}
);

(async () => {
	await view.render(await view.load());
	assert.deepEqual(view.map.options.map(option => option.name), ['api_token', 'hostname']);
	const token = view.map.options[0], hostname = view.map.options[1];
	assert.equal(token.password, true);
	assert.equal(view.map.values.main.api_token, '');
	assert.equal(token.validate('main', ''), true);
	assert.equal(hostname.validate('main', 'abc.example.com'), true);
	assert.notEqual(hostname.validate('main', 'https://abc.example.com'), true);
	assert.notEqual(hostname.validate('main', 'abc.example.com/'), true);
	assert.notEqual(hostname.validate('main', '-abc.example.com'), true);
	assert.match(text(view.statusNode), /Connected/);
	assert(walk(view.statusNode).some(node => node.attrs.class === 'cf-connection-state cf-state-success'));
	assert.match(text(view.statusNode), /Token saved/);
	assert.equal(walk(view.statusNode).find(node => node.tag === 'a').attrs.href, 'https://abc.example.com/');
	const copy = walk(view.statusNode).find(node => node.tag === 'button' && text(node) === 'Copy link');
	assert(copy);
	await copy.attrs.click();
	assert.deepEqual(clipboard, ['https://abc.example.com/']);
	assert.match(text(state.notifications[0][1]), /Link copied/);
	assert.equal(state.polling.length, 1);
	assert.equal(state.polling[0].seconds, 8);
	const renders = state.renders, originalCopy = copy;
	await state.polling[0].fn();
	assert.equal(state.renders, renders, 'unchanged polling must keep the DOM and keyboard focus');
	assert.equal(walk(view.statusNode).find(node => node.tag === 'button'), originalCopy);
	const guide = view.tokenGuide();
	assert.equal(walk(guide).find(node => node.tag === 'a').attrs.href, 'https://dash.cloudflare.com/?to=/:account/api-tokens');
	assert.match(text(guide), /Cloudflare Tunnel/);
	assert.match(text(guide), /Specific resources/);
	assert.match(text(guide), /All zones/);
	assert.deepEqual(walk(view.officialLinks()).filter(node => node.tag === 'a').map(node => node.attrs.href), [
		'https://dash.cloudflare.com/sign-up', 'https://dash.cloudflare.com/', 'https://dash.cloudflare.com/?to=/:account/api-tokens'
	]);
	const notice = view.securityNotice();
	assert.match(text(notice), /login page to the Internet/);
	assert.match(text(notice), /weak password/);
	assert.equal(walk(notice).find(node => node.tag === 'a').attrs.href, '/cgi-bin/luci/admin/system/admin/password');
	view.updateStatus({phase: 'deploying', stage: 'dns', connected: true});
	assert.equal(view.deployButton.disabled, true);
	assert.match(text(view.statusNode), /Configuring DNS/);
	assert(walk(view.statusNode).some(node => node.attrs.class === 'cf-state-label cf-state-warning'));
	view.updateStatus({phase: 'ready', connected: true, hostname: 'abc.example.com', https_ok: false});
	assert.match(text(view.statusNode), /HTTPS verification pending/);
	view.updateStatus({phase: 'ready', connected: true, hostname: 'abc.example.com', https_ok: true, dns_cache_pending: true});
	assert.match(text(view.statusNode), /local DNS cache/);
	view.updateStatus({phase: 'error', error: {message: '<script>unsafe</script>'}});
	assert.equal(walk(view.statusNode).filter(node => node.tag === 'script').length, 0);
	status = {phase: 'error', connected: true, error: {code: 'conflict', message: 'DNS record belongs to another tunnel'}};
	await state.polling[0].fn();
	assert.match(text(view.statusNode), /Deployment failed/);
	assert(walk(view.statusNode).some(node => node.attrs.class === 'cf-state-label cf-state-danger'));
	assert(walk(view.statusNode).some(node => node.attrs.class === 'cf-connection-state cf-state-success'), 'a failed update must not hide a still-connected tunnel');
	assert.match(text(view.statusNode), /DNS record belongs to another tunnel/);
	assert.equal(state.notifications.length, 1);
	status = {phase: 'ready', connected: true, hostname: 'abc.example.com', https_ok: true};
	view.map.values.main.api_token = 'new-test-token-value-12345';
	await view.deploy();
	assert.equal(state.saved.length, 1);
	assert.deepEqual(state.saved[0], {hostname: 'abc.example.com', api_token: 'new-test-token-value-12345'});
	assert.equal(view.map.values.main.api_token, '');
	status = {phase: 'stopped', connected: false, hostname: 'abc.example.com'};
	await state.polling[0].fn();
	assert.match(text(view.statusNode), /Disconnected/);
	assert(walk(view.statusNode).some(node => node.attrs.class === 'cf-connection-state cf-state-muted'));
	view.updateStatus({phase: 'unconfigured', token_saved: false});
	assert.match(text(view.statusNode), /Token not saved/);
	view.updateStatus({phase: 'stopped', token_saved: true});
	assert.match(text(view.statusNode), /Token saved/);
	const stoppedBefore = state.rpc.filter(call => call.method === 'stop').length;
	view.stop();
	assert.match(text(state.modal), /Remote access through this domain will stop/);
	assert.equal(state.rpc.filter(call => call.method === 'stop').length, stoppedBefore);
	await walk(state.modal).find(node => node.tag === 'button' && text(node) === 'Cancel').attrs.click();
	assert.equal(state.modal, null);
	view.stop();
	await walk(state.modal).find(node => node.tag === 'button' && text(node) === 'Stop tunnel').attrs.click();
	assert.equal(state.rpc.filter(call => call.method === 'stop').length, stoppedBefore + 1);
	view.readonly = true; view.updateStatus(status);
	assert.equal(view.deployButton.disabled, true);
	assert.equal(view.stopButton.disabled, true);
	assert.equal(state.notifications.length, 1);
	console.log('PASS two-field JS form, live connection status, access/copy links, token status, secret clearing and read-only controls');
})().catch(error => {console.error(error); process.exit(1);});
