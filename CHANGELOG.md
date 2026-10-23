# Changelog

## 1.0.0 — 2026-10-23

First release.

- `setup`: installs the IKEv2 VPN server through hwdsl2/setup-ipsec-vpn.
- `add` / `show`: print a one-line client command, copy it to the clipboard (local tools or OSC 52) and optionally save it to a file.
- `list`, `revoke`, `delete`: manage clients.
- Client side: `up`, `down`, `enable`, `disable`, `remove`. These also work with tunnels named `cgvpn` from the original script.
- Relay support: `relay <vpn-server>` forwards UDP 500/4500 through nginx (default) or iptables, and `add --via RELAY` creates clients that connect through it.
- `status` detects whether the host is a server, a relay or a client.
- `update`, `uninstall`, and an interactive menu.
- `install.sh` installs in one line and can run a command right after (`bash -s -- <command>`).
