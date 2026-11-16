# Optional agent plugins for OPNsense

Small agent plugins for the Checkmk agent on OPNsense. They are **not** part of
the OPNsense plugin `os-checkmk-agent`, which keeps the agent output stock. Use
them if you want the extra data.

| File | Section | In Checkmk |
|---|---|---|
| `opnsense` | `<<<labels:sep(0)>>>` | host labels `opnsense:yes` and `opnsense/version:<version>`, for rule conditions |
| `sshd_config` | `<<<sshd_config>>>` | service *SSH daemon configuration* (`sshd -T` of OPNsense's SSH daemon in `/usr/local/sbin`) |
| `logins` | `<<<logins>>>` | service *Logins* (number of logged-in users) |

## Install

As root on the firewall, for each plugin you want:

```sh
fetch -o /usr/local/lib/check_mk_agent/plugins/opnsense \
  https://gitlab.thatsallmine.de/checkmk1/opnsense_checkmk_agent/-/raw/main/extras/agent-plugins/opnsense
chmod 755 /usr/local/lib/check_mk_agent/plugins/opnsense
```

Then run the service discovery for the host in Checkmk.

Firmware and plugin updates leave the files alone. They are not stored in
`config.xml`, so keep a copy for a fresh install of the firewall.

Tested on OPNsense 26.7 and 26.1 with Checkmk 2.5 (2026-11-14/15).

## License

BSD-2-Clause, see [LICENSE](../../LICENSE).
