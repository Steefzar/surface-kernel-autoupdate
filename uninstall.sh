#!/usr/bin/env bash
#
# Undo install.sh. Does NOT remove already-installed kernels (so you stay bootable)
# — those commands are printed at the end for you to run if you want.
#
set -euo pipefail

REPODIR=/var/lib/surface-local
DBNAME=surface-local
BIN="$HOME/.local/bin"
FISHFUNC="$HOME/.config/fish/functions"

echo ":: Removing updater + fish wrapper"
rm -f "$BIN/surface-kernel-update" "$FISHFUNC/yay.fish"

echo ":: Removing [$DBNAME] from /etc/pacman.conf (sudo)"
# custom '#' address delimiters so the file:// path needs no escaping
sudo sed -i '\#^\[surface-local\]#,\#^Server = file:///var/lib/surface-local#d' /etc/pacman.conf

echo ":: Removing local repo $REPODIR (sudo)"
sudo rm -rf "$REPODIR"

echo ":: Refreshing pacman databases (sudo)"
sudo pacman -Sy || true

cat <<EOF

Left in place (intentionally):
  - installed kernel packages (so you keep a bootable kernel)
  - the build caches at ~/.local/share/linux-cachyos-surface{,-latest}

To also remove those:
  sudo pacman -R linux-cachyos-surface linux-cachyos-surface-headers \\
                 linux-cachyos-surface-latest linux-cachyos-surface-latest-headers   # only if you have another kernel!
  rm -rf ~/.local/share/linux-cachyos-surface ~/.local/share/linux-cachyos-surface-latest
EOF
