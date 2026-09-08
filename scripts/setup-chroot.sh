#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOTFS="/data/local/ubuntu-chroot"
CACHE="$HOME/.cache/termux-bootstrap"
BASE_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/"

mkdir -p "$CACHE"

if [ "$(uname -m)" != "aarch64" ]; then
  echo "[setup-chroot] Unsupported architecture: $(uname -m)" >&2
  exit 1
fi

su -c true >/dev/null 2>&1 || { echo "[setup-chroot] Root access required." >&2; exit 1; }

if su -c "test -x '$ROOTFS/bin/bash'"; then
  echo "[setup-chroot] Existing Ubuntu rootfs found at $ROOTFS. Refusing to overwrite."
  exit 0
fi

echo "[setup-chroot] Resolving latest Ubuntu Base 24.04 ARM64 image..."
name="$(curl -fsSL "$BASE_URL" | grep -oE 'ubuntu-base-24\.04[^"<> ]*-base-arm64\.tar\.gz' | sort -Vu | tail -n1)"
[ -n "$name" ] || { echo "[setup-chroot] Could not resolve Ubuntu Base image." >&2; exit 1; }

archive="$CACHE/$name"
if [ ! -f "$archive" ]; then
  echo "[setup-chroot] Downloading $name"
  curl -fL --progress-bar "$BASE_URL$name" -o "$archive"
else
  echo "[setup-chroot] Using cached $archive"
fi

su -c "mkdir -p '$ROOTFS'"
echo "[setup-chroot] Extracting rootfs..."
su -c "tar --numeric-owner -xpf '$archive' -C '$ROOTFS'"

# DNS before apt is available.
su -c "printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > '$ROOTFS/etc/resolv.conf'"
su -c "printf '127.0.0.1 localhost\n::1 localhost ip6-localhost ip6-loopback\n' > '$ROOTFS/etc/hosts'"

# Temporary mounts for initial provisioning.
su -c "mount -o bind '$ROOTFS' '$ROOTFS' 2>/dev/null || true"
su -c "mount -o remount,bind,rw,suid '$ROOTFS' 2>/dev/null || true"
su -c "mkdir -p '$ROOTFS/proc' '$ROOTFS/sys' '$ROOTFS/dev' '$ROOTFS/dev/pts'"
su -c "mount -t proc proc '$ROOTFS/proc' 2>/dev/null || true"
su -c "mount -o bind /sys '$ROOTFS/sys' 2>/dev/null || true"
su -c "mount -o bind /dev '$ROOTFS/dev' 2>/dev/null || true"
su -c "mount -t devpts devpts '$ROOTFS/dev/pts' 2>/dev/null || true"

echo "[setup-chroot] Provisioning Ubuntu..."
su -c "chroot '$ROOTFS' /bin/bash -lc '
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y sudo locales ca-certificates curl wget git gnupg build-essential python3 python3-pip unzip zip jq procps util-linux openssh-client
locale-gen en_US.UTF-8
id coder >/dev/null 2>&1 || useradd -m -s /bin/bash coder
mkdir -p /etc/sudoers.d
echo \"coder ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/coder
chmod 440 /etc/sudoers.d/coder
chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo
mkdir -p /home/coder/.npm-global
chown -R coder:coder /home/coder
'"

echo "[setup-chroot] Ubuntu rootfs ready."
