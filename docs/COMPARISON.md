# Monitoring OPNsense with Checkmk: the options compared

There are several ways to bring an OPNsense firewall into Checkmk. They
complement each other; this page helps to pick and combine them.

| Short name | What it is |
|---|---|
| **Plugin** | this project, `os-checkmk-agent`: Checkmk's FreeBSD agent as an OPNsense plugin |
| **API agent** | [opnsense](https://github.com/Gulaschcowboy/checkmk_extensions/tree/main/opnsense), a Checkmk *special agent*: a program on the Checkmk server that queries the OPNsense REST API – nothing is installed on the firewall |
| **Bashclub** | the [Bashclub OPNsense agent](https://github.com/bashclub/checkmk-opnsense-agent): a Python agent with many OPNsense-specific checks, installed manually as a startup script |
| **SNMP** | OPNsense's official plugin `os-net-snmp` together with Checkmk's built-in SNMP checks |

Legend: ✔ provided · ➕ possible via the REST API (endpoint exists in OPNsense
26.7), not part of the API agent today · – not provided

## Data

| Data | Plugin | API agent | Bashclub | SNMP |
|---|---|---|---|---|
| CPU load | ✔ | ✔ load average | ✔ | – |
| CPU utilization | ✔ | – | ✔ | ✔ |
| Memory and swap | ✔ | ✔ | ✔ | ✔ |
| File systems | ✔ | ✔ | ✔ | ✔ |
| ZFS (datasets, ARC, zpool) | ✔ | – | ✔ | – |
| Uptime | ✔ | ✔ (in *OPNsense System*) | ✔ | ✔ |
| Network interfaces | ✔ | ➕ | ✔ | ✔ (physical interfaces) |
| Processes, threads, TCP connections, kernel counters | ✔ | – | ✔ | – |
| Disk I/O | ✔ | – | – | – |
| NTP | ✔ | ➕ | ✔ | – |
| SSH daemon configuration | ✔ | – | ✔ | – |
| Logins | ✔ | – | – | – |
| Host labels | ✔ | – | ✔ | – |
| Own agent plugins and local checks | ✔ | – | ✔ | – |
| Firmware version, pending updates | – | ✔ | ✔ | – |
| OPNsense services | – | ✔ | ✔ | – |
| SMART | – | ✔ (with os-smart) | ✔ | – |
| Temperatures | – | queried, no service | ✔ | – |
| Gateways (latency, loss) | – | ➕ | ✔ | – |
| CARP / high availability | – | ➕ | ✔ | – |
| VPN: IPsec, OpenVPN, WireGuard | – | ➕ | ✔ | – |
| Unbound DNS resolver | – | ➕ | ✔ | – |
| DHCP | – | ➕ Kea, Dnsmasq | ✔ ISC DHCP | – |
| Certificates (expiry) | – | ➕ | ✔ ACME client | – |
| Package audit (vulnerabilities) | – | – | ✔ | – |
| Firewall states, pf statistics | – | ➕ | – | – |
| IDS alerts | – | ➕ | – | – |
| Squid, HAProxy, nginx, APC UPS | – | – | ✔ | – |

## Operation

| Aspect | Plugin | API agent | Bashclub | SNMP |
|---|---|---|---|---|
| Installation | OPNsense plugin list (planned), until then a package from the releases | MKP on the Checkmk server | script copied to the firewall | OPNsense plugin `os-net-snmp` |
| Configuration | OPNsense GUI, stored in `config.xml` | Checkmk rule (API key) | config file on the firewall | OPNsense GUI |
| Survives a fresh install with config restore | ✔ | ✔ (nothing on the firewall) | – script and config to copy back | ✔ |
| Connection | TCP 6556 or SSH | HTTPS to the OPNsense API | TCP 6556 | UDP 161 |
| Encryption | symmetric (format `05`) or SSH | TLS | ✔ | SNMPv3 |
| Updates | with OPNsense (agent from the FreeBSD port) | with the MKP | own update function | with OPNsense |
| License | BSD-2-Clause | GPL-2.0 | BSD-2-Clause (per its file header) | BSD (net-snmp) |

## Recommendation

- **Plugin + API agent** together: the plugin delivers the operating system
  view from Checkmk's own agent and checks, the API agent the OPNsense view
  from the REST API. Both are configured in the GUI (OPNsense and Checkmk) and
  survive updates and reinstalls. The overlapping basics (CPU, memory, file
  systems, uptime) come from both; use one of them for each.
- **Bashclub** covers most in one agent today. It is a good choice when you need
  its additional checks now; keep a copy of the script and its configuration
  with your backups.
- **SNMP** is the lightest option if you only need interfaces and the basics.

Where two sources deliver the same data, disable one of the services in
Checkmk (rule *Disabled services*, or on the discovery page); no change to the
plugin or the API agent is needed.

## Agent and SNMP on the same firewall

Both queried at the same time from fresh Checkmk 2.5.0p19 sites, same OPNsense
26.7 virtual machine (2 cores, 4 GB RAM), default settings in Checkmk:

| | Checkmk agent (this plugin) | SNMP (`os-net-snmp`, SNMPv2c) |
|---|---|---|
| Services found | **28** | 21 |
| CPU | *CPU load* (1/5/15 min, per core: 0.29 / 0.14) **and** *CPU utilization* (2.08 %) | *CPU utilization* only (2.00 %) |
| Memory | RAM and swap from FreeBSD's own counters (`sysctl`): 1.18 GiB used of 3.82 GiB | from the generic host resources MIB, with its own definition of "used": 994 MiB of 3.95 GiB |
| File systems | 13, from ZFS itself (`zfs get`): correct size and free space per dataset | 14 – including two nullfs mounts of Unbound that repeat the numbers of `/` (one full disk would alert three times) |
| ZFS | *ZFS arc cache*, *zpool status* | – |
| Processes, threads, TCP connections, kernel counters, disk I/O | ✔ | – |
| NTP | *NTP Time* with offset, stratum, jitter | – |
| HW/SW inventory | ✔ | – |
| Own checks | local checks and agent plugins as small scripts | – |

Why the agent is the better fit for a firewall:

- **Security:** SNMPv2c sends the community string and all data in plain text;
  SNMPv3 needs extra users and settings on both sides. The agent is reached only
  through a firewall rule and can encrypt its output (or run over SSH).
- **Fewer moving parts:** one TCP connection per check interval returns all data;
  SNMP walks many tables over UDP.
- **Built-in checks:** the agent's sections are evaluated by Checkmk's own checks
  for FreeBSD and ZFS – no extra check code to maintain.
- **Extensible:** anything that can be scripted becomes a service.

SNMP is still the lightest option if interfaces and the basics are enough.

## How the columns were verified

- **Plugin:** tested on OPNsense 26.7 and 26.1 with Checkmk 2.4, 2.5 and 3.0.
- **SNMP:** tested on OPNsense 26.7 with `os-net-snmp` (SNMPv2c) and a fresh
  Checkmk 2.5.0p19 site, default settings: 21 services, all OK – CPU
  utilization, memory, uptime, SNMP info, 2 interfaces, 14 file systems.
  Not found: CPU load, ZFS, processes, TCP connections, NTP, disk I/O.
- **API agent:** version 1.1.1 tested on OPNsense 26.7 with a fresh
  Checkmk 2.5.0p19 site (API key of an admin user, port 443): 30 services –
  *OPNsense System* (status, uptime, load average), *OPNsense Memory*, 12
  *OPNsense Filesystem*, *OPNsense Firmware*, 13 *OPNsense Service* (including
  the service of this plugin, `checkmkagent`). Temperatures are queried but
  give no service; SMART was not tested (no os-smart on the virtual machine).
  The ➕ endpoints were looked up in the OPNsense 26.7 source, not queried.
- **Bashclub:** from the source code of version 1.2.16 and the services it
  delivered on an OPNsense 26.1 firewall.

## Disclaimer

I did not develop this plugin officially as an employee of Checkmk GmbH, but rather as a private individual.
