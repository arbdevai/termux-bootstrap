# Termux Bootstrap

Disaster-recovery setup for a rooted Android development environment built around **Termux + Ubuntu 24.04 ARM64 chroot**.

## Fresh recovery

```bash
pkg update -y
pkg install git -y
git clone https://github.com/arbdevai/termux-bootstrap
cd termux-bootstrap
bash install.sh
```

## Install modes

```bash
bash install.sh             # full setup
bash install.sh --repair    # repair an existing setup
bash install.sh --ub-only   # reinstall UB Manager + banner only
bash install.sh --dev-tools # install/update development tools inside Ubuntu
```

## What it restores

- Termux prerequisites
- Ubuntu 24.04 ARM64 rootfs at `/data/local/ubuntu-chroot`
- `coder` user with passwordless sudo
- Git, GitHub CLI, curl, wget, build tools, Node.js/npm
- Claude Code
- 9router
- UB Manager with stale-session/orphan cleanup
- Termux startup command reminder

## UB Manager

```text
ub          enter Ubuntu
ub status   fast process + RAM status
ub stop     stop Ubuntu + Claude + Node + 9router + dev servers
ub reset    cleanup then enter a fresh Ubuntu session
ub scan     force a real process scan
ub help     show commands
```

If Android kills Termux under RAM pressure, root/chroot processes may survive. UB Manager tracks the launcher session and cleans stale Ubuntu processes before creating a fresh session, preventing duplicate chroots and forgotten Claude/Node/9router processes from piling up.

## Secrets

This repo intentionally contains **no live API keys, GitHub tokens, Claude credentials, 9router tokens, or other secrets**. Restore authentication manually after recovery.

The repository is safe to keep public only as long as secrets are never committed.

## Requirements

- ARM64 Android device
- Root access available through `su`
- Termux
- Internet connection
- Several GB of free storage

## Notes

The full installer refuses to overwrite an existing Ubuntu rootfs. Use `--repair` for an existing environment. The Ubuntu base image is resolved from Canonical's official Ubuntu Base 24.04 ARM64 release directory at install time so the script does not depend on one stale point-release filename.
