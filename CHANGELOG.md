# Changelog

## [Unreleased]

### Changed

- After the upstream review: the plugin keeps the agent output stock (no bundled
  agent plugins), has no deinstall/upgrade hooks and a short description.

### Added

- OPNsense plugin `os-checkmk-agent` 1.0: runs the Checkmk agent on TCP port
  6556 (IPv4 and IPv6) via `socat`, switchable in the GUI under
  *Services › Checkmk Agent*.
- Optional symmetric encryption, compatible with Checkmk's rule
  *Symmetric encryption (Linux, Windows)*.
- Optional agent plugins (host labels, SSH daemon configuration, logins) in
  `extras/agent-plugins/`, outside the OPNsense plugin.
- Documentation, test results and a copy of the plugin source.
