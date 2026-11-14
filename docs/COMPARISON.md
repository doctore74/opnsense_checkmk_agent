# Monitoring OPNsense with Checkmk: the options compared

There are several ways to bring an OPNsense firewall into Checkmk. They
complement each other; this page helps to pick and combine them.

| Short name | What it is |
|---|---|
| **Plugin** | this project, `os-checkmk-agent`: Checkmk's FreeBSD agent as an OPNsense plugin |
| **Special agent** | the Checkmk special agent [opnsense](https://github.com/Gulaschcowboy/checkmk_extensions/tree/main/opnsense): queries the OPNsense REST API from the Checkmk server |
| **Bashclub** | the [Bashclub OPNsense agent](https://github.com/bashclub/checkmk-opnsense-agent): a Python agent with many OPNsense-specific checks, installed manually as a startup script |
| **SNMP** | OPNsense's official plugin `os-net-snmp` together with Checkmk's built-in SNMP checks |

Legend: ✔ provided · ➕ possible via the REST API (endpoint exists in OPNsense
26.7), not part of the special agent today · – not provided

## Data

| Data | Plugin | Special agent | Bashclub | SNMP |
|---|---|---|---|---|
| CPU load | ✔ | ✔ load average | ✔ | – |
| CPU utilization | ✔ | – | ✔ | ✔ |
| Memory and swap | ✔ | ✔ | ✔ | ✔ |
| File systems | ✔ | ✔ | ✔ | ✔ |
| ZFS (datasets, ARC, zpool) | ✔ | – | ✔ | – |
| Uptime | ✔ | ✔ | ✔ | ✔ |
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
| Temperatures | – | ✔ queried | ✔ | – |
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

| Aspect | Plugin | Special agent | Bashclub | SNMP |
|---|---|---|---|---|
| Installation | OPNsense plugin list (planned), until then a package from the releases | MKP on the Checkmk server | script copied to the firewall | OPNsense plugin `os-net-snmp` |
| Configuration | OPNsense GUI, stored in `config.xml` | Checkmk rule (API key) | config file on the firewall | OPNsense GUI |
| Survives a fresh install with config restore | ✔ | ✔ (nothing on the firewall) | – script and config to copy back | ✔ |
| Connection | TCP 6556 or SSH | HTTPS to the OPNsense API | TCP 6556 | UDP 161 |
| Encryption | symmetric (format `05`) or SSH | TLS | ✔ | SNMPv3 |
| Updates | with OPNsense (agent from the FreeBSD port) | with the MKP | own update function | with OPNsense |
| License | BSD-2-Clause | GPL-2.0 | BSD-2-Clause (per its file header) | BSD (net-snmp) |

## Recommendation

- **Plugin + special agent** together: the plugin delivers the operating system
  view from Checkmk's own agent and checks, the special agent the OPNsense view
  from the REST API. Both are configured in the GUI (OPNsense and Checkmk) and
  survive updates and reinstalls. The overlapping basics (CPU, memory, file
  systems, uptime) come from both; use one of them for each.
- **Bashclub** covers most in one agent today. It is a good choice when you need
  its additional checks now; keep a copy of the script and its configuration
  with your backups.
- **SNMP** is the lightest option if you only need interfaces and the basics.

Where two sources deliver the same data, disable one of the services in
Checkmk (rule *Disabled services*, or on the discovery page); no change to the
plugin or the special agent is needed.

## How the columns were verified

- **Plugin:** tested on OPNsense 26.7 and 26.1 with Checkmk 2.4, 2.5 and 3.0.
- **SNMP:** tested on OPNsense 26.7 with `os-net-snmp` (SNMPv2c) and a fresh
  Checkmk 2.5.0p19 site, default settings: 21 services, all OK – CPU
  utilization, memory, uptime, SNMP info, 2 interfaces, 14 file systems.
  Not found: CPU load, ZFS, processes, TCP connections, NTP, disk I/O.
- **Special agent:** from its source code. The ➕ endpoints were looked up in
  the OPNsense 26.7 source, not queried.
- **Bashclub:** from the source code of version 1.2.16 and the services it
  delivered on an OPNsense 26.1 firewall.
