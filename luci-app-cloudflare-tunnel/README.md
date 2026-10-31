# Cloudflare Tunnel for X-WRT

中文图文教程：[从购买域名到远程访问路由器](TUTORIAL.zh-CN.md)。

LuCI JavaScript view, following the structure of `luci-app-fakemesh`. The page
is under **Services → Cloudflare Tunnel** and has two inputs:

- A Cloudflare API token.
- A complete access hostname, such as `abc.example.com`.

The zone must already be active in the user's Cloudflare account. The plugin
automatically finds the longest matching zone and its account, creates a
remotely managed tunnel for this router, configures a proxied CNAME and ingress,
starts `cloudflared`, enables startup, and checks HTTPS. Use a first-level
subdomain relative to the zone for the free Universal SSL certificate.
The page polls the connector's actual readiness every 8 seconds, displays whether a token is
saved without returning its contents, and provides both an HTTPS link and a
copy-link button. The token guide explains specific and all-resource scopes.
The page warns that the management login becomes publicly reachable, explains
weak-password risk, and links to the router password page.
Connection status and access/copy actions stay at the top, with detailed setup
help below the two-field form. Stopping the tunnel requires confirmation.
Unchanged polling preserves link and button focus. Styles are scoped to this view.

The **same API token** needs these permissions and resource scopes:

| Type | Permission | Access | Scope |
| --- | --- | --- | --- |
| Account | Cloudflare Tunnel | Edit | The zone's account |
| Zone | DNS | Edit | The selected domain |
| Zone | Zone | Read | The selected domain |

User-owned and account-owned API tokens are supported; token validation uses
the actual zone, tunnel and DNS operations rather than the user-only verify API.
Create account tokens at <https://dash.cloudflare.com/?to=/:account/api-tokens>,
selecting the account that owns your domain. The guide offers either specific
domain scopes or all zones within that account.

## Build

From the OpenWrt build root:

```sh
./scripts/feeds update -i x
./scripts/feeds install -p x luci-app-cloudflare-tunnel
make menuconfig
make package/feeds/x/luci-app-cloudflare-tunnel/compile V=s
```

Select `X → Cloudflare Tunnel → luci-app-cloudflare-tunnel`. Build dependencies
are declared in the package. The generated package is architecture independent.

## Runtime

The authenticated RPC object is `luci.cloudflare_tunnel`. Only `settings` and
`status` are readable; deployment and stopping require write access. Neither
RPC settings nor status returns the saved API token or connector token.

API requests run in a background worker so LuCI does not wait for Cloudflare API
timeouts. Calls use `curl` without a shell. The API token and JSON request are
passed through an unlinked private stdin file rather than process arguments.
Persistent credentials and resource ownership are under `/etc/cloudflare-tunnel`
and `/etc/config/cloudflare-tunnel`, with private permissions. Preserve these
paths during firmware upgrades; they are package conffiles.

The dedicated `cloudflare-tunnel` procd service uses a connector token file and
does not modify `/etc/config/cloudflared` or the existing `cloudflared` service.
Its readiness endpoint is bound to `127.0.0.1:20242`.

The origin defaults to `http://127.0.0.1:80`. HTTP redirects to HTTPS are detected
and an HTTPS loopback origin is used with local certificate verification
disabled; public HTTPS verification always remains enabled. For a custom local
management port, the origin may be changed through UCI:

```sh
uci set cloudflare-tunnel.main.origin='http://127.0.0.1:8080'
uci commit cloudflare-tunnel
```

Only loopback origins are accepted. Configured rpcd web logins must have
passwords before the management page can be published. Login names are not
hardcoded; root is supported when configured by the firmware. Shadow references such
as `$p$admin` and inline rpcd password hashes are checked. No WAN firewall ports
are opened.

Repeated deployments reuse tracked resources. DNS conflicts and untracked
tunnels are rejected instead of overwritten. Changing the hostname preserves
unrelated ingress rules and removes only DNS records created by this plugin
which still point to their recorded tunnel. Failed steps retain resource IDs
so a retry can resume. **Stop tunnel** disables the local service and startup;
it leaves Cloudflare resources available for reuse.
Each router has its own ownership database. Router B never enumerates a zone
to delete router A's records; deletion requires B's saved record ID, hostname,
and tunnel target to match. The two-device regression test covers this case.

CLI commands (configuration must already be saved):

```sh
/usr/libexec/cloudflare-tunnel deploy
/usr/libexec/cloudflare-tunnel check
/usr/libexec/cloudflare-tunnel status
/usr/libexec/cloudflare-tunnel stop
```

`check` performs a read-only preflight of zone discovery, API read scopes and
the local web service. Cloudflare validates write scopes on deployment.

## Validation

```sh
lua feeds/x/luci-app-cloudflare-tunnel/tests/deploy.lua
node feeds/x/luci-app-cloudflare-tunnel/tests/view.js
```

The deployment tests load the production policy with a simulated Cloudflare
transport. They cover DNS conflicts, retries after partial failures, account
scope changes, domain discovery, hostname changes, and ownership checks.
