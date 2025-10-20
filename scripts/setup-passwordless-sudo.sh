#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: setup-passwordless-sudo.sh

Configure passwordless sudo for the current user on supported Debian/Ubuntu systems.

Options:
  -h, --help    Show this help message and exit.
EOF
}

case "${1-}" in
-h | --help)
	usage
	exit 0
	;;
"") ;;
*)
	echo "[ERROR] Unexpected argument: $1" >&2
	echo "[INFO] Use -h or --help for usage" >&2
	exit 1
	;;
esac

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "[ERROR] This script is supported only on Linux (detected: $(uname -s))" >&2
	exit 1
fi

if [[ $EUID -eq 0 ]]; then
	echo "[ERROR] Run this script as the target non-root user without sudo" >&2
	exit 1
fi

# 0) Quick check: already passwordless?
if sudo -n true 2>/dev/null; then
	echo "[INFO] Passwordless sudo is already active"
	exit 0
fi

# 1) Preconditions
if ! id -nG "$USER" | tr ' ' '\n' | grep -Fxq -e sudo -e wheel -e admin; then
	echo "[ERROR] You must belong to one of the sudo-privileged groups: sudo, wheel, admin" >&2
	exit 1
fi

echo "[INFO] Authenticating sudo for setup"
sudo -v

# 2) Build and validate a drop-in sudoers file
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf "%s ALL=(ALL) NOPASSWD:ALL\n" "$USER" >"$tmp"

echo "[INFO] Validating syntax via visudo"
sudo visudo -cf "$tmp"

# 3) Install drop-in (backup existing file if present)
target="/etc/sudoers.d/$USER"
if sudo test -f "$target"; then
	echo "[INFO] Backing up existing $target"
	sudo cp -a "$target" "${target}.bak.$(date +%Y%m%d%H%M%S)"
fi

echo "[INFO] Installing $target"
sudo install -m 0440 "$tmp" "$target"

# 4) Test
echo "[INFO] Verifying passwordless sudo"
sudo -k
if sudo -n true 2>/dev/null; then
	echo "[SUCCESS] Passwordless sudo is active for $USER"
else
	echo "[FAIL] Passwordless sudo is NOT active"
	exit 1
fi
