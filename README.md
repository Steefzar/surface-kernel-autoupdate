# Surface kernel auto-update (CachyOS)

Installs and keeps updated **two** CachyOS kernels with Microsoft Surface
hardware support — **as part of your normal `yay` run**, building +
installing a new version only when one is actually needed, with full build
output, like an AUR `-git` package:

- **[linux-cachyos-surface](https://github.com/Steefzar/linux-cachyos-surface)**
  — tracks whatever kernel version linux-surface currently has official
  patches for.
- **[linux-cachyos-surface-latest](https://github.com/Steefzar/linux-cachyos-surface-latest)**
  — tracks the *newest* CachyOS kernel release. When linux-surface's official
  patches already cover it, builds identically to the package above; when
  there's a version gap, it falls back to a hand-rebased patch set bundled in
  that repo. If that stops applying cleanly, the build aborts loudly instead
  of shipping something broken.

They can be installed side by side, like `linux-cachyos`/`linux-cachyos-lts`.

Neither repo is in the AUR, so plain `yay -Syu` can't track them. This sets up
a tiny **local pacman repo** (`[surface-local]`): a small updater builds new
versions into it and `repo-add`s them; pacman/yay then install them like any
repo package. A fish wrapper runs the updater automatically whenever you do a
full upgrade.

## Just want precompiled packages?

You don't need this installer (or a local kernel build) at all: the packages
built by this setup are also published as a **signed pacman repository**
served from GitHub Releases. One-time setup — trust the signing key:

```sh
curl -s https://raw.githubusercontent.com/Steefzar/surface-kernel-autoupdate/main/surface-cachyos.asc \
    | sudo pacman-key --add -
sudo pacman-key --finger F43A86B2BAA715242965C241222C2A1B58F14BA7
sudo pacman-key --lsign-key F43A86B2BAA715242965C241222C2A1B58F14BA7
```

Add the repository to `/etc/pacman.conf`:

```ini
[surface-cachyos]
Server = https://github.com/Steefzar/surface-kernel-autoupdate/releases/download/repo
```

Then install (either or both):

```sh
sudo pacman -Syu linux-cachyos-surface-latest linux-cachyos-surface-latest-headers
# or: sudo pacman -Syu linux-cachyos-surface linux-cachyos-surface-headers
```

Updates then arrive through plain `pacman -Syu` like any other repo package.
The packages are x86_64, thin-LTO builds, published on the maintainer's
build schedule — if you want builds the moment a version lands, or different
build options, use the full setup below instead.

## Requirements

- CachyOS (or another Arch derivative) on a Surface device.
- `base-devel`, `git`, and **`yay`** (for the auto-update-on-upgrade wrapper).
- A bootloader setup that auto-creates entries on kernel install — CachyOS's
  Limine / systemd-boot / GRUB hooks all do this out of the box.
- A long first compile per kernel — from ~20 min to a couple of hours
  depending on hardware (thin LTO, multi-threaded) — and a few GB free.

## Install

```bash
tar xzf surface-kernel-autoupdate.tar.gz
cd surface-kernel-autoupdate
./install.sh
```

`install.sh` is idempotent. It will:

1. install `surface-kernel-update` → `~/.local/bin/`
2. install the fish wrapper → `~/.config/fish/functions/yay.fish`
3. create the local repo `/var/lib/surface-local` and register `[surface-local]`
   in `/etc/pacman.conf` (`SigLevel = Optional TrustAll`)
4. `sudo pacman -Sy`
5. optionally build both packages + install `linux-cachyos-surface` right
   away (it asks).

You'll be prompted for `sudo` (repo dir, pacman.conf, db sync, install); on the
first build, `makepkg` installs the kernel build dependencies (rust, clang/LLVM, …).

If you skipped the build during install, do it when ready:

```bash
surface-kernel-update                                       # builds both (long compile)
sudo pacman -S linux-cachyos-surface linux-cachyos-surface-headers
# or: sudo pacman -S linux-cachyos-surface-latest linux-cachyos-surface-latest-headers
# reboot, choose the Surface entry, then:
uname -r                                                    # -> ...-cachyos-surface[-latest]
```

## How updates work

Run **`yay`** (or `yay -Syu`) as usual. The fish wrapper first runs
`surface-kernel-update`, which for each package:

- syncs its repo,
- compares its PKGBUILD's pinned version against what's already built,
- **only if newer**, builds it and adds it to `[surface-local]`,

then your normal `yay` upgrade installs whichever one(s) you have in the same
transaction. When nothing is new you just get a one-line `... already built`
per package and it moves on — no rebuild.

For `linux-cachyos-surface-latest` specifically, a build can also stop with
`... needs a manual rebase` — that means linux-surface's patches no longer
apply against the newer kernel even with fuzz tolerance, and the bundled
hand-rebase needs refreshing. The previous package stays installed; nothing
breaks, it just won't have a newer version until that's done.

> Using `sudo pacman -Syu` instead of `yay` will still *install* an
> already-built newer Surface kernel, but won't *build* one. Use `yay`, or run
> `surface-kernel-update` manually, to pick up brand-new releases.

### Not using fish?
Skip `yay.fish` and add an alias/function to your shell rc, e.g. bash:

```bash
yay() { surface-kernel-update; command yay "$@"; }
```

…or just run `surface-kernel-update` yourself before upgrading.

## Tuning

- **LTO:** defaults to `thin` (fast, low RAM). For maximum-perf full LTO:
  `SURFACE_LTO=full surface-kernel-update`.
- **Local repo path:** override `SURFACE_REPODIR` in the environment.
- **Build clone locations:** `~/.local/share/linux-cachyos-surface` and
  `~/.local/share/linux-cachyos-surface-latest` — disposable, safe to delete
  if you ever want a clean re-clone.

## Notes & caveats

- **The repo lives in `/var/lib/surface-local`, not your home**, on purpose:
  modern pacman downloads (even `file://`) as the unprivileged `alpm` user, which
  can't traverse a `700` home directory. A home-dir repo fails with
  "Could not open file".
- **Keep a fallback kernel** (e.g. `linux-cachyos` or `linux-cachyos-lts`) so a bad
  build never leaves you unbootable.
- Old package files accumulate in `/var/lib/surface-local` on version bumps; prune
  occasionally if you care about the disk.
- After a new build the updater tries to upload it to the precompiled
  `[surface-cachyos]` repo — on machines without the signing key that step
  skips itself with a note. Harmless; `SURFACE_NO_PUBLISH=1` silences it.

## Uninstall

```bash
./uninstall.sh
```

Removes the updater, the fish wrapper, the `[surface-local]` repo and its
`pacman.conf` entry. It leaves installed kernels in place (so you stay bootable) and
prints the commands to remove those + the build caches if you want.

## Files in this package

| file | purpose |
|------|---------|
| `install.sh` | automated setup (this is what you run) |
| `surface-kernel-update` | the version-gated builder → local repo (both packages) |
| `surface-kernel-publish` | signs + uploads builds to the precompiled repo (skips itself without the signing key) |
| `surface-cachyos.asc` | public signing key for the precompiled repo |
| `yay.fish` | fish wrapper that runs the updater on `yay -Syu` |
| `uninstall.sh` | undo the setup |
| `README.md` | this file |

## Authorship & credits

The bulk of this project was generated by **Claude (Anthropic's Claude Code)**
at my direction. I configured, tested, and maintain it, but I don't claim to
have hand-written the scripts. Commits are co-authored accordingly
(`Co-Authored-By: Claude <noreply@anthropic.com>`).

This repo is just the **installer/automation** — it bundles no kernel source.
The actual kernel packaging lives in, and credit for the patches goes to:

- [linux-surface/linux-surface](https://github.com/linux-surface/linux-surface)
  — the Microsoft Surface kernel patches (full credits in the two package
  repos' READMEs).
- [CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos) and
  [CachyOS/linux](https://github.com/CachyOS/linux) — the CachyOS kernel base
  and packaging conventions.
- [dylandhall/linux-cachyos-surface](https://github.com/dylandhall/linux-cachyos-surface)
  and [jonpetersathan/linux-cachyos-surface](https://github.com/jonpetersathan/linux-cachyos-surface)
  — the prior packaging this setup originally built on. Prior art and thanks.
