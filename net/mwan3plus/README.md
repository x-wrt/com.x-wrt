# mwan3plus runtime recovery

Route monitoring shares the mwan3 lifecycle lock with startup, shutdown and
interface hotplug. This prevents a LAN route event from being discarded while
hotplug has flushed a WAN table and has not yet restored its default route.
The monitor reloads configuration under the lock, checks the runtime enable
state, and reconciles non-default routes when it starts. It starts under the
command lock so that a concurrent stop cannot finish before the monitor is
launched.
The monitor retries a nonblocking lock: OpenWrt's BusyBox `lock` forks a
persistent lock owner, so killing a blocked lock waiter during stop could
otherwise leave an orphan that acquires the lock and blocks the next start.

The monitor also listens for link events. A LAN bridge can be logically up
while all cables are disconnected: its main-table routes have `linkdown`,
so startup excludes them from the WAN tables. Plugging in a cable clears
that flag without emitting a route update. On an administratively up link
with carrier (`UP,LOWER_UP`), mwan3 now reconciles the main-table routes into
active WAN tables. Link-down and deleted-link events do not activate tables.

Startup, hotplug and monitor events use the same connected-route metrics:
the owning WAN table omits the main-table metric; other tables retain that
metric, or use the source table ID (256 for an unmanaged interface) when the
main route has none. Delete events use the same normalized route key, ignoring
transient `linkdown` and expiry attributes in both events and table entries. Route
replacement is limited to the current table; an insertion failure never
deletes matching routes in other tables. WANs with overlapping prefixes should
still use distinct network route metrics.

Run the isolated route synchronization tests with:

```sh
python3 tests/test_route_sync.py -v
```

These cover missing LAN routes, carrier-only recovery, hotplug/monitor
serialization, stopping a lock waiter, connected-route deletion and recovery,
route withdrawal without carrier, gateway changes, failed replacements, runtime
disable, and IPv6 route expiry attributes. The fixtures do not modify host
networking.

The package installs `/usr/share/mwan3/mwan3-reload.sh` and registers it as
the `firewall.mwan3` script include during installation or upgrade. The old
`firewall.mwan3_ipv6_masq` include is removed; NAT66 helpers remain owned by
the existing mwan3 interface startup and hotplug code.

With fw4, the include has `fw4_compatible=1` and no `reload` option, which
fw4 does not support. fw4 invokes script includes on start and reload.
Its normal reload/restart only rebuilds `inet fw4`, preserving mwan3's
iptables-nft mangle tables and IPv6 NAT table. The callback therefore checks
the required IPv4/IPv6 `mwan3_hook` chains and their PREROUTING/OUTPUT jumps
and skips reconstruction when they are present. With fw3, the include uses
`reload=0`, so a normal reload skips the callback entirely.

After all nftables tables are flushed (for example, firewall service stop
followed by start), the callback restores missing hooks through the existing
mwan3 stop/start implementation. This also rebuilds policies, tracking,
routes and NAT66 helpers for interfaces that are up. NAT66 operations use
`ip6tables -w` to wait for concurrent xtables operations. The health check
detects missing mangle hooks; it does not detect arbitrary partial rule loss
such as deleting only a NAT66 helper while leaving all mangle hooks intact.

The include launches `mwan3 firewall-reload` asynchronously so that a mwan3
user hook can restart the firewall without waiting on its own mwan3 lock.
The internal command acquires the existing command lock, reloads configuration,
checks the runtime enable state, and keeps the lock until recovery completes.
Disabled/not-started mwan3 stays disabled. Concurrent callbacks recheck rules
after acquiring the lock, so only the first callback rebuilds missing hooks.
Failed restoration of the hooks is logged and can be retried by a later
callback or by invoking `mwan3 firewall-reload` directly.

| State | Owner/trigger | Persistence and retry |
| --- | --- | --- |
| `firewall.mwan3`, legacy `firewall.mwan3_ipv6_masq` removal | Package uci-defaults, installation/upgrade | Only changed fields are staged; commit only with pending owner changes. Failed operations return nonzero for retry. An identical rerun performs zero persistent writes. |
| Enable state, locks, tracking status | Existing mwan3 lifecycle | Existing `/var` runtime state; no configuration commit from the recovery callback. |
| Mangle/NAT66 rules, ipsets, routes | Existing mwan3 startup/hotplug | Kernel state; no persistent files. |
| Recovery notices/errors | `mwan3 firewall-reload` | Existing system logger; no new persistent log files. |

Run the isolated lifecycle, migration and NAT66 regression tests from this
directory:

```sh
python3 tests/test_firewall_reload.py -v
MWAN3_TEST_SHELL=/absolute/path/to/ash python3 tests/test_firewall_reload.py -v
```

The tests require Python 3.9+, Bash (or a compatible BusyBox ash), `flock`
and standard host utilities. Network/UCI commands use private fixtures.
For the optional real fw4 parser/include runner test, also set
`MWAN3_TEST_FW4_SOURCE` to the matching prepared firewall4 source directory
(containing `root/` and `tests/lib/`) and `MWAN3_TEST_UCODE` to an absolute
path to a host ucode executable with its fs module. That test uses fw4's own
dependency mocks and the same private network fixtures; it does not exercise
the kernel nftables dataplane.
