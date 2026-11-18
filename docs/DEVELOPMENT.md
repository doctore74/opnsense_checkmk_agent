# Development

## Where the code lives

| Place | Purpose |
|---|---|
| Fork of `opnsense/plugins`, branch `feature/checkmk-agent` | the real source; the upstream pull request is made from here |
| This repository, `net-mgmt/checkmk-agent/` | copy for reading and review, together with the documentation |

After a change in the fork, update the copy here:

```sh
scripts/sync_plugin.sh ../opnsense_plugins
```

## Design

- **Listener:** `socat` listens on the configured address and port (default
  `127.0.0.1:6556`; `::` gives `TCP6-LISTEN` with `ipv6only=0` for IPv4 and
  IPv6), at most 4 queries at a time, and runs the agent wrapper for each query.
  `daemon(8)` starts it from the plugin's own rc.d script `checkmkagent`, which
  reads address, port and encryption from `/etc/rc.conf.d/checkmkagent`. `-t 30`
  lets socat wait for the agent's answer after the client has closed its
  sending side. The FreeBSD port ships only the agent script, no service
  script.
- **Why not inetd:** inetd on FreeBSD 15 resolves ports only by name from
  `/etc/services` (`getservbyname()`), and 6556 is not listed there. A plugin
  should not modify system files.
- **Why not the rc.d script of the socat package:** it uses one global instance
  file that admins may use for their own purposes.
- **Access control:** loopback by default (review of the upstream pull
  request); for network queries the admin picks the listen address and creates
  firewall rules, as with node_exporter, netdata and net-snmp.
- **Configuration:** configd templates write `/etc/rc.conf.d/checkmkagent` and
  `/usr/local/etc/checkmkagent/secret`. "Apply" in the GUI stops the service,
  reloads the templates and starts it again if enabled
  (`ApiMutableServiceControllerBase`). OPNsense starts it at boot via
  `rc.freebsd`.
- **Encryption:** `src/opnsense/scripts/checkmkagent/agent` runs
  `check_mk_agent` and, when called with `encrypt`, encrypts its output in
  format `05` with the base system's `openssl`. It follows
  `optionally_encrypt()` and `encrypt_then_mac()` of Checkmk's Linux agent
  (`check_mk_agent.linux`). Differences: the secret goes to `openssl` through a
  file descriptor instead of `-k`, and hex is decoded with `printf` octal
  escapes, as FreeBSD has no `xxd`. An empty or unreadable secret gives only
  `EncryptionPanic`, never plain text.
- **Secret file:** contains only the secret. `setup.sh` (run by rc.subr as
  `checkmkagent_setup` before each start) sets the directory
  `/usr/local/etc/checkmkagent` to `0700` and the file to `0600`. Before the
  first start, the template engine creates them as `0750`/`0640` root:wheel.
- **High availability:** `checkmkagent_xmlrpc_sync()` offers the settings for
  the HA configuration sync, like nrpe and zabbix-agent.
- **Stock output:** the plugin adds nothing to the agent output (review of the
  upstream pull request). Optional agent plugins live in `extras/agent-plugins/`
  of this repository, outside the OPNsense plugin.
- **No deinstall/upgrade hooks** (review of the upstream pull request): an
  upgrade leaves the running agent alone; after an uninstall socat keeps the
  port until the next reboot but returns no data, and after a reinstall the agent
  starts with the next Apply or reboot.

## Files

```
net-mgmt/checkmk-agent/
├── Makefile                 PLUGIN_DEPENDS=check_mk_agent socat
├── pkg-descr                plugin details shown in the firmware GUI
└── src/
    ├── etc/inc/plugins.inc.d/checkmkagent.inc    service list entry, HA sync
    ├── etc/rc.d/checkmkagent                     start/stop (socat line)
    └── opnsense/
        ├── mvc/app/models/OPNsense/CheckmkAgent/       model, menu, ACL
        ├── mvc/app/controllers/OPNsense/CheckmkAgent/  controllers, form
        ├── mvc/app/views/OPNsense/CheckmkAgent/index.volt
        ├── scripts/checkmkagent/agent                  wrapper with encryption
        ├── scripts/checkmkagent/setup.sh               secret permissions
        └── service/
            ├── conf/actions.d/actions_checkmkagent.conf
            └── templates/OPNsense/CheckmkAgent/        rc.conf.d, secret
```

## Building and testing on an OPNsense VM

Use a separate test VM, not a production firewall. If the VM sits in a
productive LAN, disable *Services › Dnsmasq DNS & DHCP* (and Kea) on it, so it
does not send DHCP answers or router advertisements into that LAN.

```sh
opnsense-code core plugins            # once: /usr/core and /usr/plugins
# copy net-mgmt/checkmk-agent to /usr/plugins/net-mgmt/ (macOS: COPYFILE_DISABLE=1 tar --no-xattrs)
cd /usr/plugins/net-mgmt/checkmk-agent
make lint
make style                            # needs phpcs
make sweep
make upgrade                          # build and install the package
/usr/local/opnsense/scripts/firmware/register.php install os-checkmk-agent
```

`register.php` is only needed for a package installed from source; otherwise the
firmware page shows the plugin as "misconfigured".

Test cases (all passed on OPNsense 26.7.9 and 26.1.11, 2026-11-18, source state
of the upstream pull request after the second review; earlier runs: 1.0-rc5,
2026-11-16):

1. `make lint`, `make sweep` (no changes), phpcs with the core ruleset and
   ShellCheck (only the usual rc.d notes) without findings
2. fresh install on a system that never had the plugin: agent disabled,
   defaults `127.0.0.1:6556` without encryption; after Enable it listens on
   loopback only, secret directory `0700`, file `0600`
3. settings, Apply and status through the real API (as the GUI does it); invalid
   address or port is refused; GUI page with the new fields loads without
   JavaScript errors
4. listen address loopback (no answer from the LAN), `::` (IPv4 and IPv6), a
   fixed IPv4 and IPv6 address, another port; output is the stock output
5. encryption with a secret containing special characters: decrypted by
   Checkmk's own `decrypt_by_agent_protocol` (2.4.0p41, 2.5.0p20, 3.0 daily);
   wrong secret gives "MAC mismatch"; empty secret or a non-root caller gives
   only `EncryptionPanic`; the secret never shows up in the process list
6. real sites with the encryption rule (2.4.0p41, 2.5.0p20, 3.0 daily): 25
   services each; with encryption enforced, plain text is refused (2026-11-16)
7. SSH query with `command=` while the listener is on loopback: agent output
   only, port forwarding refused
8. reboot: agent starts by itself (26.7 encrypted, 26.1 on `::`)
9. upgrade of an existing configuration without the new fields: agent keeps
   working with the defaults until the address is set
10. uninstall: package gone; port open until restart but no data; generated
    files and the `config.xml` section stay
11. HA pair (26.7): configuration sync incl. secret to the backup node, restart
    via *High Availability › Status*; both nodes listen on a CARP address; CARP
    failover moves the query to the backup node and back
12. on the production firewall (26.1): upgrade, listen address `::` and
    loopback, encryption, reboot, Checkmk 2.5.0p19 queries it

## Checkmk test sites

Throwaway sites in Docker, without GUI: create a site, put the host into
`etc/check_mk/conf.d/*.mk`, then `cmk -d`, `cmk -II`, `cmk -n`. Tested against
the newest 2.4.0pN (`checkmk/check-mk-cloud`), the newest 2.5.0pN and the newest
3.0.0 daily (`checkmk/check-mk-ultimate`).

## Upstream

1. Issue at `opnsense/plugins` to announce the plugin.
2. Pull request from the fork branch. Commit messages follow the repository
   style: `net-mgmt/checkmk-agent: ...`.
3. After the merge, the plugin appears in the plugin list of the next OPNsense
   release.
