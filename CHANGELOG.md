# Changelog

## 1.1.1 — 2026-10-24

- Fix `relay --iptables` failing with "relay-iptables.sh: No such file or directory" on a host where `/etc/swanlink` didn't exist yet.
- Fix `install.sh` ending with "tmp: unbound variable" after a successful install.

## 1.1.0 — 2026-10-24

- A swanlink client can now also be a relay. `relay` switches to `--iptables` on a client, because strongSwan holds UDP 500/4500. The relay keeps forwarding while the local tunnel is down.
- `relay` in nginx mode refuses to start when another process (for example charon) holds UDP 500/4500, instead of leaving nginx unable to listen.
- iptables relay: the DNAT rule skips packets coming from the VPN server, so the server's packets to a client running on the relay box are never sent back to the server.
- The client command refuses to run on an nginx relay.
- `status` shows both the client and the relay on a host that is both, and the client menu can add or remove a relay.

## 1.0.1 — 2026-10-23

- Fix shellcheck SC2015 warnings that failed CI: the certificate export check and the nginx reload during relay removal now use explicit `if` blocks. No behavior change.

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
