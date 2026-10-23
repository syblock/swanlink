#!/usr/bin/env bash
#
# swanlink installer
#
#   curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash
#
# Install and run a command in one go:
#
#   curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash -s -- setup
#   curl -fsSL https://raw.githubusercontent.com/syblock/swanlink/main/install.sh | sudo bash -s -- add my-box
#
# Environment:
#   SWANLINK_REPO     GitHub repo to install from   (default: syblock/swanlink)
#   SWANLINK_BRANCH   Branch or tag                 (default: main)
#   SWANLINK_PREFIX   Install directory             (default: /usr/local/bin)

# Everything is inside main() so bash parses the whole file before running it.
# That matters when piped from curl: nothing can consume the rest of the script.
main() {
  set -euo pipefail

  local repo=${SWANLINK_REPO:-syblock/swanlink}
  local branch=${SWANLINK_BRANCH:-main}
  local prefix=${SWANLINK_PREFIX:-/usr/local/bin}
  local url="https://raw.githubusercontent.com/${repo}/${branch}/swanlink"
  local dest="$prefix/swanlink"
  local src_dir="" tmp

  if [ "$(id -u)" -ne 0 ]; then
    echo "swanlink installer must run as root. Use: curl -fsSL <url>/install.sh | sudo bash" >&2
    exit 1
  fi

  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  # Running from a cloned repo: install the local copy instead of downloading.
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  fi
  if [ -n "$src_dir" ] && [ -f "$src_dir/swanlink" ]; then
    echo "==> Installing swanlink from $src_dir" >&2
    cp "$src_dir/swanlink" "$tmp"
  else
    echo "==> Downloading swanlink from $url" >&2
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL --retry 3 -o "$tmp" "$url"
    elif command -v wget >/dev/null 2>&1; then
      wget -q -O "$tmp" "$url"
    else
      echo "Need curl or wget." >&2
      exit 1
    fi
  fi

  bash -n "$tmp" || { echo "Downloaded swanlink is not a valid bash script." >&2; exit 1; }
  install -d "$prefix"
  install -m 755 "$tmp" "$dest"
  echo " ✓  Installed $("$dest" version) to $dest" >&2

  if [ $# -eq 0 ]; then
    cat >&2 << 'EOF'

Next steps:
  On the VPN server:      sudo swanlink setup
  Create a client:        sudo swanlink add <client-name>
  Everything else:        swanlink help   (or just: sudo swanlink)
EOF
    return 0
  fi

  # Run the requested command. Our stdin is the curl pipe, so hand the
  # command the terminal if there is one.
  if (exec </dev/tty) 2>/dev/null; then
    exec "$dest" "$@" </dev/tty
  else
    exec "$dest" "$@" </dev/null
  fi
}

main "$@"
