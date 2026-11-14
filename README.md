# Checkmk agent for OPNsense (os-checkmk-agent)

An OPNsense plugin that runs the Checkmk agent on the firewall. A Checkmk server
then monitors OPNsense like any other host, and Checkmk's built-in checks
evaluate the data: CPU, memory, file systems and ZFS, network interfaces,
processes, uptime, NTP and more.

The plugin is a switch in the OPNsense GUI around two packages from the OPNsense
repository: `check_mk_agent` (the Checkmk agent for FreeBSD) and `socat` (makes
it reachable on TCP port 6556). It adds optional symmetric encryption and host
labels that mark the host as OPNsense.

> Status: in development, planned as a pull request to
> [opnsense/plugins](https://github.com/opnsense/plugins). Not yet available in
> the OPNsense plugin list.

## Contents

- [Overview](#overview)
- [Screenshots](#screenshots)
- [Tested with](#tested-with)
- [Setup](#setup)
- [Encryption](#encryption)
- [Host labels](#host-labels)
- [Query over SSH](#query-over-ssh)
- [Own agent plugins and local checks](#own-agent-plugins-and-local-checks)
- [Updates](#updates)
- [OPNsense data from the REST API](#opnsense-data-from-the-rest-api)
- [Uninstalling](#uninstalling)
- [Building from source](#building-from-source)
- [Feedback](#feedback)
- [License](#license)
- [Disclaimer](#disclaimer)

## Overview

```mermaid
flowchart LR
    subgraph OPN["OPNsense"]
        GUI["GUI<br/>Services › Checkmk Agent"]
        CFG[("config.xml")]
        RC["rc.d checkmkagent"]
        FW["Firewall rule<br/>TCP 6556"]
        SOCAT["socat<br/>TCP 6556, IPv4 + IPv6"]
        WRAP["agent wrapper<br/>optional encryption"]
        AGENT["check_mk_agent<br/>+ host labels plugin<br/>+ own plugins / local checks"]
        API["OPNsense REST API"]
        GUI --> CFG --> RC --> SOCAT --> WRAP --> AGENT
    end

    subgraph CMK["Checkmk site"]
        BUILTIN["Built-in checks<br/>CPU, memory, file systems,<br/>interfaces, processes ..."]
        SPECIAL["Special agent 'opnsense'<br/>firmware, services, SMART ..."]
    end

    BUILTIN -- "agent query" --> FW --> SOCAT
    SPECIAL -- "HTTPS, API key" --> API
```

## Screenshots

Settings page under *Services › Checkmk Agent*:

![Settings](docs/screenshots/settings.png)

The firewall as a host in a fresh Checkmk 2.5 site, with only the services the
agent provides:

![Services in Checkmk](docs/screenshots/checkmk-services.png)

Host labels set by the plugin, next to Checkmk's own labels:

![Host labels](docs/screenshots/checkmk-labels.png)

## Tested with

| Component | Version | Result |
|---|---|---|
| OPNsense | 26.7 (FreeBSD 15.1), `check_mk_agent` 2.5.0p15, `socat` 1.8.1.3 | install, enable/disable, reboot, upgrade, uninstall: OK (2026-11-14) |
| Checkmk 2.4 | `checkmk/check-mk-cloud:2.4.0p40` | discovery (26 services), decryption: OK (2026-11-14) |
| Checkmk 2.5 | 2.5.0p19 Ultimate | 36 services OK in production monitoring, decryption, host labels: OK (2026-11-14) |
| Checkmk 3.0 | `checkmk/check-mk-ultimate:3.0.0-2026.11.14` (daily) | discovery (26 services), decryption: OK (2026-11-14) |

Not yet tested: OPNsense 26.1 (`check_mk_agent` 2.4.0p20).

## Setup

1. Install the plugin under *System › Firmware › Plugins* (`os-checkmk-agent`).
   `check_mk_agent` and `socat` are installed with it.
2. *Services › Checkmk Agent*: check **Enable** and click **Apply**.
3. *Firewall › Rules*, on the interface the Checkmk server comes from: allow
   TCP to port 6556 on *This Firewall*, with the Checkmk server as source.
4. In Checkmk, add the firewall as a host with "Checkmk agent (Server)" and run
   the service discovery.

The plugin never opens the port itself. Who may query the agent is decided only
by the firewall rule, so restrict the source to your Checkmk server.

## Encryption

The FreeBSD agent sends plain text. The plugin can encrypt its output with a
shared secret, in the same format as Checkmk's Linux agent (`05`: PBKDF2-SHA256
with 600000 iterations, AES-256-CBC, HMAC-SHA256).

1. In Checkmk, create the rule *Symmetric encryption (Linux, Windows)* for the
   firewall host and enter a secret.
2. On OPNsense, under *Services › Checkmk Agent*: check **Encryption**, enter the
   same secret, click **Apply**.

How the secret is handled:

- It is stored in `config.xml` like other secrets of OPNsense and its plugins,
  and therefore also in configuration backups. Keep those backups safe.
- The GUI and the API never show it again. Leave the field empty to keep the
  current secret.
- On the firewall it is written to `/usr/local/etc/checkmkagent/secret`, readable
  by root only (directory `0700`, file `0600`). It is passed to `openssl` through
  a file descriptor, never on a command line.

## Host labels

The plugin adds a small agent plugin that sends two host labels:

```
opnsense:yes
opnsense/version:26.7
```

Checkmk shows them on the host after the service discovery. Use them in rule
conditions to target all OPNsense firewalls, or one OPNsense version. The agent
itself still reports `AgentOS: freebsd`, so rules for FreeBSD hosts keep
applying.

## Query over SSH

> Not yet tested end to end; based on how OPNsense manages users and SSH.

Instead of TCP port 6556, Checkmk can also run the agent over SSH. This needs no
setting in the plugin; OPNsense's own user management does it:

1. *System › Access › Users*: create a user, e.g. `checkmk`, member of the group
   `admins`, login shell `/bin/sh`. OPNsense allows SSH only for members of
   `admins` (wheel). Do not set a password the user knows.
2. In the field *Authorized keys* of that user, enter the public key of the
   Checkmk site, restricted to the agent:

   ```
   command="/usr/local/bin/check_mk_agent",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA... checkmk
   ```

3. *System › Settings › Administration*: enable Secure Shell.
4. In Checkmk, use the rule *Individual program call instead of agent access*
   with `ssh -T -oStrictHostKeyChecking=accept-new checkmk@$HOSTADDRESS$`.

OPNsense writes the key from `config.xml`, so it survives updates and reboots.
Over SSH the transport is encrypted by SSH itself; the *Encryption* setting of
the plugin applies to port 6556 only. Enable the plugin's agent service only if
you also want port 6556.

## Own agent plugins and local checks

The agent runs executable files from:

- `/usr/local/lib/check_mk_agent/plugins/` (agent plugins)
- `/usr/local/lib/check_mk_agent/local/` (local checks)

OPNsense firmware updates and plugin updates leave your own files there alone.
They are not part of `config.xml`, though: after a fresh install of the firewall,
copy them back from your own backup. The host labels plugin belongs to this
package and comes back automatically when the plugin is installed.

## Updates

- **The plugin** is updated with OPNsense, like every other plugin.
- **The agent** comes from the FreeBSD port
  [`net-mgmt/check_mk_agent`](https://www.freshports.org/net-mgmt/check_mk_agent/).
  OPNsense builds it into its package repository, so a new agent version arrives
  with a regular OPNsense update. The plugin does not pin a version.
- Checkmk servers read the data of agents from neighbouring versions, so the
  agent version does not have to match the Checkmk version exactly
  (see the [tested versions](#tested-with)).

## OPNsense data from the REST API

This plugin delivers the operating system view through the agent. For
OPNsense-specific data, such as firmware and pending updates, OPNsense services
and SMART, use the Checkmk special agent
[**opnsense**](https://github.com/Gulaschcowboy/checkmk_extensions/tree/main/opnsense),
which queries the OPNsense REST API. Both work side by side on the same host.
Wishes for data from the REST API (for example DHCP, gateways, VPN) belong
there.

## Uninstalling

Remove the plugin under *System › Firmware › Plugins*. The agent is stopped and
the stored secret file is deleted. Remove the firewall rule for port 6556 as
well.

## Building from source

The plugin lives in `net-mgmt/checkmk-agent/` (a copy of the branch in the
`opnsense/plugins` fork). See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for
building, testing and the upstream workflow.

## Feedback

Questions, suggestions and test reports are welcome in the
[Checkmk forum](https://forum.checkmk.com/) (send me, Doc, a direct message), or
as an issue in this project.

## License

BSD-2-Clause, like OPNsense and its plugins. See [LICENSE](LICENSE).

## Disclaimer

I did not develop this plugin officially as an employee of Checkmk GmbH, but rather as a private individual.
