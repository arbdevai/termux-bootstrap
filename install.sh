#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

MODE="${1:-full}"
ROOTFS="/data/local/ubuntu-chroot"
PREFIX="/data/data/com.termux/files/usr"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

say(){ printf '\033[1;34m[BOOTSTRAP]\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
fail(){ printf '\033[1;31m[×]\033[0m %s\n' "$*" >&2; exit 1; }

case "$MODE" in
  full|--full) MODE=full ;;
  --repair|repair) MODE=repair ;;
  --ub-only|ub-only) MODE=ub-only ;;
  --dev-tools|dev-tools) MODE=dev-tools ;;
  -h|--help|help)
    cat <<'HELP'
Usage:
  bash install.sh             full setup
  bash install.sh --repair    repair existing setup
  bash install.sh --ub-only   reinstall UB Manager + banner
  bash install.sh --dev-tools install/update Ubuntu dev tools
HELP
    exit 0
    ;;
  *) fail "Unknown mode: $MODE" ;;
esac

[ "$(uname -m)" = "aarch64" ] || fail "This bootstrap currently supports aarch64 only."

install_termux_packages(){
  say "Installing Termux prerequisites..."
  pkg update -y
  pkg install -y git curl wget tar coreutils procps util-linux
  ok "Termux prerequisites ready"
}

install_ub(){
  say "Installing UB Manager..."
  install -m 755 "$SELF_DIR/scripts/ub" "$PREFIX/bin/ub"
  install -m 755 "$SELF_DIR/scripts/ub-banner" "$HOME/.ub-banner"

  touch "$HOME/.bashrc"
  sed -i '/# >>> UB MANAGER >>>/,/# <<< UB MANAGER <<</d' "$HOME/.bashrc"
  cat >> "$HOME/.bashrc" <<'BASHRC'

# >>> UB MANAGER >>>
if [ -f "$HOME/.ub-banner" ] && [ -z "${UB_CHROOT:-}" ]; then
    . "$HOME/.ub-banner"
fi
# <<< UB MANAGER <<<
BASHRC

  if [ -f "$HOME/.zshrc" ]; then
    sed -i '/# >>> UB MANAGER >>>/,/# <<< UB MANAGER <<</d' "$HOME/.zshrc"
    cat >> "$HOME/.zshrc" <<'ZSHRC'

# >>> UB MANAGER >>>
if [ -f "$HOME/.ub-banner" ] && [ -z "${UB_CHROOT:-}" ]; then
    . "$HOME/.ub-banner"
fi
# <<< UB MANAGER <<<
ZSHRC
  fi

  bash -n "$PREFIX/bin/ub" || fail "UB Manager syntax check failed"
  ok "UB Manager installed"
}

repair_chroot(){
  su -c true >/dev/null 2>&1 || fail "Root access unavailable"
  su -c "test -x '$ROOTFS/bin/bash'" || fail "Ubuntu rootfs not found; run full setup first"

  say "Repairing coder user + sudo..."
  su -c "chroot '$ROOTFS' /bin/bash -lc '
set -e
apt-get update
apt-get install -y sudo locales ca-certificates curl wget git procps util-linux
id coder >/dev/null 2>&1 || useradd -m -s /bin/bash coder
mkdir -p /etc/sudoers.d
echo \"coder ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/coder
chmod 440 /etc/sudoers.d/coder
chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo
mkdir -p /home/coder/.npm-global
chown -R coder:coder /home/coder
locale-gen en_US.UTF-8 || true
'"
  ok "Ubuntu user/sudo repaired"
}

install_termux_packages

case "$MODE" in
  ub-only)
    install_ub
    ;;
  dev-tools)
    bash "$SELF_DIR/scripts/dev-tools.sh"
    ;;
  repair)
    repair_chroot
    install_ub
    bash "$SELF_DIR/scripts/dev-tools.sh"
    ;;
  full)
    if su -c "test -x '$ROOTFS/bin/bash'" >/dev/null 2>&1; then
      warn "Existing Ubuntu rootfs detected. Preserving it and switching to repair mode."
      repair_chroot
    else
      bash "$SELF_DIR/scripts/setup-chroot.sh"
    fi
    install_ub
    bash "$SELF_DIR/scripts/dev-tools.sh"
    ;;
esac

echo
printf '\033[1;34m┌────────────────────────────────────────────┐\033[0m\n'
printf '\033[1;34m│ TERMUX BOOTSTRAP COMPLETE                  │\033[0m\n'
printf '\033[1;34m└────────────────────────────────────────────┘\033[0m\n'
printf '  ub          enter Ubuntu\n'
printf '  ub status   process + RAM status\n'
printf '  ub stop     stop all Ubuntu processes\n'
printf '  ub reset    cleanup + fresh session\n'
printf '  ub scan     force process scan\n'
printf '\nRe-authenticate GitHub CLI, Claude Code and 9router manually.\n'
