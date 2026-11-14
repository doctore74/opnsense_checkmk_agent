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

- **Listener:** `socat` listens on TCP 6556 (IPv4 and IPv6, `TCP6-LISTEN` with
  `ipv6only=0`), at most 4 queries at a time, and runs the agent wrapper for each
  query. `daemon(8)` starts it from the plugin's own rc.d script `checkmkagent`.
  `-t 30` lets socat wait for the agent's answer after the client has closed its
  sending side.
- **Why not inetd:** inetd on FreeBSD 15 resolves ports only by name from
  `/etc/services` (`getservbyname()`), and 6556 is not listed there. A plugin
  should not modify system files.
- **Why not the rc.d script of the socat package:** it uses one global instance
  file that admins may use for their own purposes.
- **Access control:** firewall rules created by the admin, as with
  node_exporter, netdata and net-snmp.
- **Configuration:** configd templates write `/etc/rc.conf.d/checkmkagent` and
  `/usr/local/etc/checkmkagent/secret`. "Apply" in the GUI stops the service,
  reloads the templates and starts it again if enabled
  (`ApiMutableServiceControllerBase`). OPNsense starts it at boot via
  `rc.freebsd`.
- **Encryption:** `src/opnsense/scripts/checkmkagent/agent` runs
  `check_mk_agent` and, if a secret is set, encrypts its output in format `05`
  with the base system's `openssl`. FreeBSD has no `xxd`, so hex is decoded with
  `printf` octal escapes.
- **Secret permissions:** templates copy the permissions of the target
  directory. `+POST_INSTALL.pre` creates `/usr/local/etc/checkmkagent` with mode
  `0700` before the first template reload, so the secret file gets `0600`.
- **Host labels:** `src/lib/check_mk_agent/plugins/opnsense` prints a
  `<<<labels:sep(0)>>>` section with `opnsense` and `opnsense/version`.
- **Package hooks:** `+PRE_DEINSTALL.pre` stops the agent and removes the secret
  directory; `+POST_INSTALL.post` starts the agent again after an upgrade if it
  is enabled.

## Files

```
net-mgmt/checkmk-agent/
├── Makefile                 PLUGIN_DEPENDS=check_mk_agent socat
├── pkg-descr                plugin details shown in the firmware GUI
├── +POST_INSTALL.pre        secret directory 0700
├── +POST_INSTALL.post       restart after upgrade
├── +PRE_DEINSTALL.pre       stop, remove secret
└── src/
    ├── etc/inc/plugins.inc.d/checkmkagent.inc    service list entry
    ├── etc/rc.d/checkmkagent                     start/stop (socat line)
    ├── lib/check_mk_agent/plugins/opnsense       host labels
    └── opnsense/
        ├── mvc/app/models/OPNsense/CheckmkAgent/       model, menu, ACL
        ├── mvc/app/controllers/OPNsense/CheckmkAgent/  controllers, form
        ├── mvc/app/views/OPNsense/CheckmkAgent/index.volt
        ├── scripts/checkmkagent/agent                  wrapper with encryption
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

Test cases (all passed on OPNsense 26.7, 2026-11-14):

1. `make lint`, `make sweep` without findings
2. install: `check_mk_agent` and `socat` come along, agent disabled
3. enable/disable/enable in GUI order (stop, template reload, start)
4. agent answers on IPv4 and IPv6
5. encryption: output starts with `05` and is decrypted by Checkmk's own
   `decrypt_by_agent_protocol` (2.4, 2.5, 3.0); secret file `0600`
6. host labels discovered in a Checkmk site
7. reboot: agent starts by itself
8. upgrade: agent running again if enabled, stopped if disabled
9. uninstall: agent stopped, secret removed

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
