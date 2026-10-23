# CLAUDE.md

Notes for working on swanlink. User-facing docs live in [README.md](README.md).

## What this is

swanlink is a single bash script that does three jobs, depending on the host:

- **VPN server:** `swanlink setup` runs hwdsl2/setup-ipsec-vpn (`https://get.vpnsetup.net`), which installs Libreswan with IKEv2 and certificate auth. `add`, `show`, `list`, `revoke` and `delete` manage client certificates through hwdsl2's `ikev2.sh` and the NSS database at `sql:/etc/ipsec.d`.
- **Client:** `swanlink add <name>` prints a one-line command, `echo <gzip+base64> | base64 -d | gunzip | sudo bash`. Pasted on a Debian or Ubuntu box, it installs strongSwan and routes all traffic, Docker included, through the VPN. `up`, `down`, `enable`, `disable` and `remove` manage that tunnel afterwards.
- **Relay:** `swanlink relay <vpn-server>` forwards UDP 500 and 4500 to the server, through nginx `stream` (default) or iptables DNAT (`--iptables`). Clients created with `add --via RELAY` get `right=RELAY` and `rightid=<server id>`.

`swanlink status` and the menu detect the role from the filesystem:

| Role | Detected by |
|---|---|
| Server | `/etc/ipsec.d/ikev2.conf` exists |
| Relay | `/etc/swanlink/relay.env` exists |
| Client | `conn swanlink` (or legacy `conn cgvpn`) in `/etc/ipsec.conf` |

## Files

| File | Purpose |
|---|---|
| `swanlink` | The whole tool. Installed to `/usr/local/bin/swanlink` |
| `install.sh` | One-line installer. Downloads `swanlink` from `raw.githubusercontent.com/syblock/swanlink/<branch>` and can run a command right after (`bash -s -- <cmd>`) |
| `README.md` | User docs |
| `CHANGELOG.md` | Release notes, newest first |
| `.github/workflows/ci.yml` | `bash -n`, shellcheck and a smoke test on every push and PR |

## Rules that matter

- **The client payload (`build_payload`) is field-tested on real servers.** Treat changes to it as risky. Inside its unquoted heredoc:
  - plain `$VAR` expands on the **server** when the command is generated;
  - `\$VAR` reaches the **client** literally and expands there.

  Mixing these up silently breaks clients. After any change, decode a generated command and run `bash -n` on it (see Testing).
- **stdout carries only the client command.** Every human-readable message goes to stderr through `info`, `ok`, `warn`, `die` and `hint`, so that `--raw` and `> file` stay clean. Keep it that way.
- **The connection name is `swanlink`** (`CONN`). Clients set up by the original script use `cgvpn`. `LEGACY_CONNS` keeps `up`, `down`, `status` and `remove` working for them, so don't drop it.
- **`install.sh` keeps all its logic inside `main()`,** so bash parses the whole file before running any of it. This matters under `curl | bash`: without it, a child process could read the rest of the script from stdin.
- **Upstream dependency:** swanlink calls hwdsl2's `ikev2.sh` with `--addclient`, `--listclients`, `--revokeclient NAME -y` and `--deleteclient NAME -y`. If upstream changes these flags, swanlink breaks. Server uninstall uses `https://get.vpnsetup.net/unst`.
- **Clients and relays need Debian or Ubuntu** (`apt-get`). The script uses GNU tools (`grep -P`, `base64 -w0`).
- Match the existing style: two-space indent, `cmd_*` functions for subcommands, `local` declared separately from command substitutions so `set -e` still catches failures.
- Every new command needs entries in `usage`, `main`'s dispatch, the README command tables and, if it fits, the menu.

## Testing

Nothing here can be fully tested without root and real machines. Before every release:

1. Static checks (CI runs the same):
   ```bash
   bash -n swanlink && bash -n install.sh
   uvx --from shellcheck-py shellcheck swanlink install.sh
   ```
2. Payload check without a server. Source the script without its last line (`main "$@"`), stub `certutil` and `pk12util` with a throwaway openssl CA, then decode the output:
   ```bash
   sed '$d' swanlink > /tmp/lib.sh
   bash -c 'source /tmp/lib.sh; OPT_SERVER=1.1.1.1 OPT_VIA= OPT_OUT= OPT_RAW=1 OPT_COPY=0 OPT_SUDO=1; emit_client_command box1' \
     | sed -E 's/^echo ([^ ]+) .*/\1/' | base64 -d | gunzip > /tmp/payload.sh
   bash -n /tmp/payload.sh && grep -E '^\s*right(id)?=' /tmp/payload.sh
   ```
   For a payload-only change, `build_payload` can be called directly with dummy strings, no stubs needed.
3. Real test, required whenever you change the payload, the relay or setup: a fresh VPN server, a client, and a relay if relay code changed.
   - Run `setup`, then `add`, then paste the command on the client.
   - Confirm the client prints "Host IP now" and "Container IP now" equal to the server's IP.
   - Run `down`, `up`, `status` and `remove` on the client.
   - For relays, test both `relay X` and `relay X --iptables`, then `add --via`.

## Deploying

No build step. Users install from the `main` branch:

- `install.sh` downloads `swanlink` from `main` by default.
- `swanlink update` also downloads from `main`.
- Anything pushed to `main` reaches users on their next install or update. Keep `main` releasable and do work on branches.

Users can pin a version with `SWANLINK_BRANCH=v1.2.0`. raw.githubusercontent.com accepts tags as well as branches. Note that `swanlink update` respects `SWANLINK_BRANCH` only if it is set when `update` runs.

## Releasing a new version

Versions follow semver:

| Bump | When |
|---|---|
| Patch | Fixes |
| Minor | New commands or options |
| Major | Breaking CLI changes, or payload changes that need existing clients to be re-provisioned |

Steps:

1. On a branch, make the change. Update `README.md` and `usage` if the CLI changed.
2. Bump `VERSION="x.y.z"` near the top of `swanlink`. `swanlink update` reads this line with `grep '^VERSION="'`, so keep the format exactly.
3. Add a section at the top of `CHANGELOG.md`: `## x.y.z — YYYY-MM-DD` followed by bullet points.
4. Run the checks in Testing. Do a real-server test if the payload, setup or relay code changed.
5. Merge to `main`, then tag and push:
   ```bash
   git tag -a vx.y.z -m "swanlink x.y.z"
   git push origin main --tags
   ```
6. Create a GitHub release from the tag, using the changelog section as the notes:
   ```bash
   gh release create vx.y.z --title "swanlink x.y.z" --notes-file <(awk '/^## /{n++} n==1' CHANGELOG.md)
   ```
7. Check that the public one-liner installs the new version on a clean box: `curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash` should print `swanlink x.y.z`. raw.githubusercontent.com can serve a cached copy for a few minutes after a push.
