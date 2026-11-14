# Changelog

## [Unreleased]

### Added

- OPNsense plugin `os-checkmk-agent` 1.0: runs the Checkmk agent on TCP port
  6556 (IPv4 and IPv6) via `socat`, switchable in the GUI under
  *Services › Checkmk Agent*.
- Optional symmetric encryption, compatible with Checkmk's rule
  *Symmetric encryption (Linux, Windows)*.
- Host labels `opnsense` and `opnsense/version`.
- Documentation, test results and a copy of the plugin source.
