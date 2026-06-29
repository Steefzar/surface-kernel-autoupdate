#!/usr/bin/env bash
#
# Set up an auto-updating dylandhall/linux-cachyos-surface kernel on a CachyOS
# (or Arch-derivative) Surface device. Idempotent — safe to re-run.
#
# What it does:
#   - installs the updater   -> ~/.local/bin/surface-kernel-update
#   - installs the fish hook  -> ~/.config/fish/functions/yay.fish
#   - creates a local pacman repo at /var/lib/surface-local (+ registers it)
#   - syncs pacman dbs, then optionally builds + installs the kernel
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPODIR=/var/lib/surface-local
DBNAME=surface-local
BIN="$HOME/.local/bin"
FISHFUNC="$HOME/.config/fish/functions"

say()  { printf '\033[1;32m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mEE\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- preflight ----------
command -v pacman  >/dev/null || die "Needs an Arch-based distro ('pacman' not found)."
command -v makepkg >/dev/null || die "'makepkg' not found — run: sudo pacman -S --needed base-devel"
command -v git     >/dev/null || die "'git' not found — run: sudo pacman -S git"
command -v yay     >/dev/null || warn "'yay' not found. The updater still works; install yay for the auto-update-on-upgrade wrapper."

prod="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
[[ $prod == *Surface* ]] || warn "Doesn't look like a Surface device (DMI: '${prod:-unknown}'). Continuing anyway."

# ---------- user files ----------
say "Installing updater -> $BIN/surface-kernel-update"
install -Dm755 "$SRC_DIR/surface-kernel-update" "$BIN/surface-kernel-update"

say "Installing fish wrapper -> $FISHFUNC/yay.fish"
install -Dm644 "$SRC_DIR/yay.fish" "$FISHFUNC/yay.fish"

if command -v fish >/dev/null; then
    fish -c "fish_add_path -g $BIN" 2>/dev/null || true
fi
case ":$PATH:" in *":$BIN:"*) : ;; *) warn "Add $BIN to PATH (fish: fish_add_path $BIN)." ;; esac

# ---------- local pacman repo (outside \$HOME so the alpm download user can read it) ----------
say "Creating local repo -> $REPODIR (sudo)"
sudo install -d -o "$(id -un)" -g "$(id -gn)" -m 755 "$REPODIR"

if [[ ! -e "$REPODIR/$DBNAME.db" ]]; then
    tar -czf "$REPODIR/$DBNAME.db.tar.gz" -T /dev/null
    ln -sf "$DBNAME.db.tar.gz" "$REPODIR/$DBNAME.db"
fi

if grep -q "^\[$DBNAME\]" /etc/pacman.conf; then
    say "[$DBNAME] already present in /etc/pacman.conf"
else
    say "Registering [$DBNAME] in /etc/pacman.conf (sudo)"
    printf '\n[%s]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$DBNAME" "$REPODIR" \
        | sudo tee -a /etc/pacman.conf >/dev/null
fi

say "Syncing pacman databases (sudo)"
sudo pacman -Sy

echo
say "Plumbing installed."
echo

# ---------- optional first build ----------
ans=n
read -r -p "Build & install linux-cachyos-surface now? (long compile; installs rust build deps) [y/N] " ans || ans=n
case "${ans,,}" in
    y|yes)
        "$BIN/surface-kernel-update"
        say "Installing kernel from the local repo (sudo)"
        sudo pacman -Sy
        sudo pacman -S --needed linux-cachyos-surface linux-cachyos-surface-headers
        echo
        say "Done. Reboot, pick the Surface entry in your boot menu, then check: uname -r"
        ;;
    *)
        cat <<EOF

Next steps when you're ready:
  surface-kernel-update                                          # build the kernel (long compile)
  sudo pacman -S linux-cachyos-surface linux-cachyos-surface-headers
  # reboot, pick the Surface entry, verify:  uname -r   (should contain 'cachyos-surface')

After that, just run 'yay' (or 'yay -Syu') normally — it rebuilds + upgrades the
Surface kernel only when dylandhall publishes a new version.
EOF
        ;;
esac
