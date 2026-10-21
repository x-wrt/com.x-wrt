# mwan3plus firewall recovery

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
