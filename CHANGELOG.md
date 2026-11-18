# Changelog

## [Unreleased]

### Changed

- After the upstream review: the plugin keeps the agent output stock (no bundled
  agent plugins), has no deinstall/upgrade hooks and a short description.
- After the second upstream review: listen address (default `127.0.0.1`) and
  port (default 6556) are settings; `setup.sh` instead of a package hook sets
  the secret permissions; the secret file holds only the secret; the encryption
  wrapper follows Checkmk's Linux agent more closely.

### Added

- Configuration sync for high availability (*System › High Availability ›
  Settings*).
- OPNsense plugin `os-checkmk-agent` 1.0: runs the Checkmk agent on TCP port
  6556 (IPv4 and IPv6) via `socat`, switchable in the GUI under
  *Services › Checkmk Agent*.
- Optional symmetric encryption, compatible with Checkmk's rule
  *Symmetric encryption (Linux, Windows)*.
- Optional agent plugins (host labels, SSH daemon configuration, logins) in
  `extras/agent-plugins/`, outside the OPNsense plugin.
- Documentation, test results and a copy of the plugin source.
