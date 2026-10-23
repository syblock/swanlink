# swanlink

Set up an IKEv2 VPN server and connect other Linux servers to it, with one command on each side.

```text
 ┌──────────────────────┐   sudo swanlink add box1    ┌────────────────────────┐
 │  VPN server          │ ──────────────────────────▶ │ one-line command       │
 │  Libreswan + IKEv2   │                             │ (copied to clipboard)  │
 └──────────────────────┘                             └───────────┬────────────┘
            ▲                                                     │ paste
            │            IKEv2 / IPsec (all traffic)              ▼
            └──────────────────────────────────────── ┌────────────────────────┐
                                                      │ client server (box1)   │
                                                      │ strongSwan, host +     │
                                                      │ Docker traffic via VPN │
                                                      └────────────────────────┘
```

- **Server:** installs [hwdsl2/setup-ipsec-vpn](https://github.com/hwdsl2/setup-ipsec-vpn) (Libreswan, IKEv2 with certificates).
- **Client:** `swanlink add <name>` prints one shell line. Paste it on any Debian or Ubuntu machine. It installs strongSwan, sets up the tunnel and sends **all** traffic through the VPN, Docker containers included. The command needs nothing else on the client: no files to copy, no `scp`.
- **Manage:** list, show again or revoke clients. On a client, bring the tunnel up or down.

## Quick start

**1. Install swanlink** (on the server, and on clients if you want `up`/`down` there):

```bash
curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash
```

**2. Set up the VPN server:**

```bash
sudo swanlink setup
```

**3. Create a client and get its command:**

```bash
sudo swanlink add office-box
```

swanlink prints a line like this and copies it to your clipboard:

```text
echo H4sIAAAAAAACA+1a...== | base64 -d | gunzip | sudo bash
```

**4. Paste that line on the client machine.** It connects and then prints the client's new public IP. That IP should be your VPN server's IP.

You can also install and run a command in one step:

```bash
curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash -s -- setup
curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash -s -- add office-box
```

Run `sudo swanlink` with no arguments for an interactive menu.

## Commands

### On the VPN server

| Command | What it does |
|---|---|
| `swanlink setup [--dns NAME] [--ip ADDR] [--force]` | Install the IKEv2 VPN server |
| `swanlink add <name>` | Create a client and print its connect command |
| `swanlink show <name>` | Print the connect command for an existing client again |
| `swanlink list` | List clients |
| `swanlink revoke <name> [-y]` | Revoke a client; it can no longer connect |
| `swanlink delete <name> [-y]` | Delete a client certificate (does **not** revoke it) |

Options for `add` and `show`:

| Option | Meaning |
|---|---|
| `--server ADDR` | The server's identity and address. Default: the server's IKEv2 ID (its DNS name or public IP) |
| `--via RELAY` | Connect through a relay at `RELAY` instead of straight to the server. See [Connecting through a relay](#connecting-through-a-relay) |
| `-o, --out FILE` | Also save the command to `FILE` (mode 600) |
| `--raw` | Print only the command: no colors, no clipboard. Useful in scripts |
| `--no-copy` | Do not copy to the clipboard |
| `--no-sudo` | Generate `… \| bash` instead of `… \| sudo bash`, for clients without `sudo` that you log into as root |

### On a client

| Command | What it does |
|---|---|
| `swanlink up` | Bring the tunnel up |
| `swanlink down` | Bring the tunnel down. Traffic goes out directly |
| `swanlink enable` / `disable` | Turn reconnect on boot on or off (on by default) |
| `swanlink remove [-y]` | Remove the tunnel and its keys from this machine |

The client commands also work on machines set up by the older version of this script, where the connection is named `cgvpn`.

You don't need swanlink on a client. Without it, you can manage the tunnel with strongSwan directly:

```bash
sudo ipsec status swanlink
sudo ipsec down swanlink
sudo ipsec up swanlink
```

### On a relay

| Command | What it does |
|---|---|
| `swanlink relay <vpn-server> [--iptables]` | Forward UDP 500 and 4500 to the VPN server. Uses nginx by default, or iptables if this host is also a client |
| `swanlink relay status` | Show the relay's mode, target and listening ports |
| `swanlink relay remove` | Remove the relay |

### Both sides

| Command | What it does |
|---|---|
| `swanlink status` | Show server status and connected clients, or client tunnel state and public IP |
| `swanlink update` | Update swanlink to the latest version |
| `swanlink uninstall [--vpn]` | Remove swanlink. `--vpn` also uninstalls the VPN server and **all** client certificates |
| `swanlink menu` | Interactive menu |

## Connecting through a relay

Clients can connect to a relay instead of the VPN server's IP. The relay only forwards encrypted IKEv2 packets (UDP 500 and 4500), so clients still leave the internet with the VPN server's IP.

```text
client ──UDP 500/4500──▶ relay (198.51.100.7) ──▶ VPN server (203.0.113.10) ──▶ internet
```

**1. On the relay box** (any Debian or Ubuntu machine that is not the VPN server, client or not):

```bash
curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash -s -- relay 203.0.113.10
```

This installs nginx with its `stream` module and forwards both ports. Open UDP 500 and 4500 on the relay's firewall. To use kernel forwarding instead of nginx, add `--iptables`. It's lighter, and a systemd unit (`swanlink-relay`) restores the rules on boot.

The relay box can also be a swanlink client. Its strongSwan holds UDP 500 and 4500, so nginx can't listen there, and `relay` switches to `--iptables` on its own. The relay runs in its own unit, so it keeps forwarding while the local tunnel is down. The reverse order needs `--iptables` too: the client command refuses to run on an nginx relay.

If your nginx already has a `stream {}` block, swanlink stops and asks you to add `include /etc/nginx/swanlink/*.conf;` inside it, because nginx allows only one `stream` block.

**2. On the VPN server**, create clients that use the relay:

```bash
sudo swanlink add office-box --via 198.51.100.7
```

The client connects to `198.51.100.7` (`right=`) but still checks the VPN server's certificate identity (`rightid=203.0.113.10`).

The relay only changes the IP that clients connect to. IKEv2 traffic still looks like IKEv2, so a relay won't help on a network that blocks the protocol itself.

## Copying to the clipboard

`add` and `show` try these methods in order:

1. `wl-copy`, `xclip`, `xsel` or `pbcopy` if you run swanlink on a desktop.
2. **OSC 52**, a terminal escape sequence. Your terminal copies the text even over SSH. It works in iTerm2, kitty, WezTerm, Alacritty, Windows Terminal, foot and recent xterm. In tmux, run `set -g set-clipboard on`.

If neither works, copy the printed line by hand, or use `--out FILE` / `--raw`.

## What the client command does

The command is a gzip+base64 encoded shell script that contains the client certificate, its private key and the CA certificate. On the client it:

1. Refuses to run if Libreswan is running, which means the machine is a VPN server.
2. Moves a leftover, stopped Libreswan `ipsec` binary aside so `ipsec` means strongSwan.
3. Installs `strongswan`, `strongswan-starter`, `libcharon-extra-plugins`, `iptables` and `iproute2`.
4. Backs up `/etc/ipsec.conf` and `/etc/ipsec.secrets` to `*.bak.<timestamp>`.
5. Writes the certificates, the key and a `swanlink` connection that sends `0.0.0.0/0` through the tunnel. The tunnel reconnects automatically (DPD and close restart, retries forever) and starts on boot.
6. Installs an up/down hook that:
   - adds `ip rule … suppress_prefixlength 0`, so LAN and Docker bridge routes stay local and only the default route uses the VPN;
   - SNATs Docker traffic (`172.16.0.0/12`) to the VPN virtual IP, so containers also go through the tunnel;
   - clamps TCP MSS to 1360 to avoid MTU black holes.
7. Starts the tunnel and prints the host's public IP. If Docker is installed, it also prints a container's public IP.

## Requirements

- **Server:** any OS supported by [setup-ipsec-vpn](https://github.com/hwdsl2/setup-ipsec-vpn#requirements): Ubuntu, Debian, CentOS/Rocky/Alma, Amazon Linux, Alpine and others. Open UDP ports 500 and 4500.
- **Client:** Debian or Ubuntu, run as root or with `sudo`.

## Security notes

- **The client command contains a private key.** Treat it like a password. Don't paste it into chats or tickets, and don't commit it.
- Give each client machine its own name. If two machines use the same certificate, they keep disconnecting each other.
- Use `revoke` to cut off a client. `delete` only removes the certificate from the server, and a copy that was already handed out keeps working until it expires. A revoked name can't be used again.
- Before you pipe any script from the internet into `sudo bash`, read it. Both `install.sh` and `swanlink` are short, plain bash.

## Troubleshooting

| Symptom | Check |
|---|---|
| Client tunnel doesn't come up | `sudo journalctl -u strongswan-starter -n 50` on the client and `sudo journalctl -u ipsec -n 50` on the server. Make sure UDP 500 and 4500 are open on the server and its cloud firewall |
| Host IP is right but containers aren't | `sudo iptables -t nat -L POSTROUTING -n \| grep swanlink`. The SNAT rule must be there |
| Some sites hang (large pages, TLS) | MTU problem. Check that the `TCPMSS` rules exist in `iptables -t mangle -L -n` |
| Lost SSH to the client after connecting | Your SSH source is now routed through the VPN. Connect through the VPN server's IP, or add a route for your admin IP through the original gateway |

## Credits

The server side uses [hwdsl2/setup-ipsec-vpn](https://github.com/hwdsl2/setup-ipsec-vpn) by Lin Song. The client side uses [strongSwan](https://www.strongswan.org/).

## License

[MIT](LICENSE)
