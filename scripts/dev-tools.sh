#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOTFS="/data/local/ubuntu-chroot"

su -c true >/dev/null 2>&1 || { echo "[dev-tools] Root access required." >&2; exit 1; }
su -c "test -x '$ROOTFS/bin/bash'" || { echo "[dev-tools] Ubuntu rootfs missing." >&2; exit 1; }

# Ensure required mounts exist for package installation.
su -c "mount -o bind '$ROOTFS' '$ROOTFS' 2>/dev/null || true"
su -c "mount -o remount,bind,rw,suid '$ROOTFS' 2>/dev/null || true"
su -c "mkdir -p '$ROOTFS/proc' '$ROOTFS/sys' '$ROOTFS/dev' '$ROOTFS/dev/pts'"
su -c "mount -t proc proc '$ROOTFS/proc' 2>/dev/null || true"
su -c "mount -o bind /sys '$ROOTFS/sys' 2>/dev/null || true"
su -c "mount -o bind /dev '$ROOTFS/dev' 2>/dev/null || true"
su -c "mount -t devpts devpts '$ROOTFS/dev/pts' 2>/dev/null || true"

su -c "chroot '$ROOTFS' /bin/bash -lc '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl wget git gh build-essential python3 python3-pip jq unzip zip openssh-client

# Node.js LTS from NodeSource when node is absent or too old.
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

install -d -o coder -g coder /home/coder/.npm-global
runuser -u coder -- /bin/bash -lc \"npm config set prefix /home/coder/.npm-global\"

grep -q '\\.npm-global/bin' /home/coder/.bashrc 2>/dev/null || cat >> /home/coder/.bashrc <<'INNER'
export PATH=\"$HOME/.npm-global/bin:$PATH\"
INNER
chown coder:coder /home/coder/.bashrc

# Install/update user-scoped coding CLIs. Failures are non-fatal so bootstrap
# can still complete if a package is temporarily unavailable.
runuser -u coder -- /bin/bash -lc \"export PATH=/home/coder/.npm-global/bin:\$PATH; npm install -g @anthropic-ai/claude-code || true\"
runuser -u coder -- /bin/bash -lc \"export PATH=/home/coder/.npm-global/bin:\$PATH; npm install -g 9router || true\"
'"

echo "[dev-tools] Development tools installed."
echo "[dev-tools] Re-authenticate gh, Claude Code and 9router manually."
