# impasto-local

My overlay on [impasto](https://github.com/andreumassanet/impasto) (Arch + Hyprland + Quickshell).

The rule: `~/impasto` is a **clean clone of the author's repo** (`origin` = `andreumassanet/impasto`, no commits of my own),
and everything of mine lives here and is applied on top. That way updates keep coming from the author.

| What | Where in this repo | Where it goes |
|---|---|---|
| keybinds, window rules, keyboard layout, env (NVIDIA) | `hypr-custom/*.lua` | `~/.config/hypr/custom/` (the author never touches this directory) |
| Quickshell changes (bar buttons, tooltip, dock) | `patches/quickshell/*.patch` | applied to `~/.config/quickshell` |
| extra packages | `packages/pacman.txt`, `aur.txt` | installed on top of the author's list |
| scripts and timers | `bin/`, `systemd/` | `~/.local/bin`, `~/sw.sh`, `~/.config/systemd/user` |
| kitty greeting | `home/zshrc.local` | `~/.zshrc.local` |
| system (snapper, Limine, mkinitcpio, mirrorlist) | `bootstrap.sh` | `/etc`, `/boot` |
| tools and default applications | `finish.sh`, `config/`, `applications/`, `icons/` | `~` |

Scripts: `bootstrap.sh` (system phase), `finish.sh` (in-session phase), `apply.sh` (apply the overlay, idempotent),
`update.sh` (update from the author + the overlay).

---

## New machine

Requirements: Arch installed with `archinstall` using **btrfs**, the **Limine** bootloader (ESP mounted at `/boot`),
NetworkManager and a regular user with sudo. `bootstrap.sh` checks this at startup and aborts if something does not match.

1. Log in on a TTY as a regular user and clone both repos:

   ```sh
   git clone https://github.com/andreumassanet/impasto ~/impasto
   git clone https://github.com/Magiszonekk/impasto-local ~/impasto-local
   ```

2. The system phase (from a TTY, not from a graphical session):

   ```sh
   ~/impasto-local/bootstrap.sh
   ```

   It sets up: multilib, a Polish keyboard (TTY and SDDM), a **pinned mirrorlist** (Arch Linux Archive, "yesterday" by default),
   snapper + snap-pac + limine-snapper-sync, `btrfs-overlayfs`, `/etc/default/limine`, zram, the user scripts
   and timers, the NVIDIA driver only if it detects an NVIDIA card, `hyprland` and `kitty`, and a baseline snapshot.
   It is idempotent, so it can be run again.

   Variables (optional):
   - `PIN_DATE=YYYY/MM/DD` - a different date to pin the repositories to. **Hyprland must be ≥ 0.56** in that snapshot.
   - `KEYMAP=pl` - the keyboard layout of the console and the login screen.
   - `WIN_UUID=… UBUNTU_UUID=…` - partitions of other systems to mount at `/mnt/win` and `/mnt/ubuntu`
     (empty = skipped). Find the UUIDs with `lsblk -o NAME,UUID,MODEL`. The Windows/Ubuntu entries in Limine are made by
     `bin/limine-dualboot` from NVRAM, so this only concerns dual-boot machines.

3. `sudo reboot`. In the Limine menu check the "Arch Linux" entry and its Snapshots submenu, and after boot run `efibootmgr`
   (firmware may reorder the boot order).

4. Start Hyprland (`start-hyprland`), then in kitty:

   ```sh
   ~/impasto-local/finish.sh
   ```

   It does: a snapshot, `./setup install` in `~/impasto`, **then** `apply.sh` (hypr `custom/`, patches, packages),
   the Plymouth splash (by hand through `/etc/default/limine`, because `./setup splash` edits the generated `limine.conf`),
   Claude Code, Hermes Agent, herdr, Discordrive (AppImage), and the default applications and bar layout.
   It takes a few minutes (the Hyprland plugins are compiled).

5. Left to do by hand: logging in (`claude`, `hermes setup`), Spotify (run it once, then `~/impasto/setup spotify`),
   and logging out and back in so the bar loads its layout.

> Run `finish.sh` from a Hyprland session. Outside one it aborts, because the plugins are built against the running compositor.

---

## Migrating from the old version

"The old version" = `~/impasto` is a clone of **my fork** `Magiszonekk/impasto` (with my own commits and edited
files of the author's), rather than a clean clone of the author's repo.

Before anything else:

```sh
sudo snapper -c root create -d "before migrating to impasto-local" --print-number
cd ~/impasto
git status -sb                      # unpushed commits? push them to the fork, they stay there as an archive
git branch backup/pre-split         # a local safety net
git bundle create ~/impasto-pre-split.bundle --all
```

1. **Point `~/impasto` at the author.** `checkout -B` is the one operation here that git alone cannot undo
   (hence the backup above):

   ```sh
   cd ~/impasto
   git remote rename origin fork
   git remote add origin https://github.com/andreumassanet/impasto.git
   git fetch origin
   git checkout -B main origin/main
   git branch -u origin/main
   ```

2. **Put the files you edited back to the author's version.** Otherwise `setup` keeps your edits and puts the new
   version beside them as `.new`, and the quickshell patches will never catch the new files. Your versions go
   to a copy in `~/.local/state/impasto/backups/<date>`.

   ```sh
   cd ~/impasto
   ./setup files list                                   # what is "edited"
   ./setup files list | python3 -c 'import json,sys; print(*[e["path"] for e in json.load(sys.stdin)["edited"]])' \
       | xargs -r ./setup files reset
   ./setup files list                                   # "edited" should now be empty
   ```

   If anything in those files was yours and is not in `hypr-custom/` or `patches/`, take it from the copy
   in `backups/` before going on.

3. **Clone the overlay and update.** `update.sh` runs `setup update` from the author, then `apply.sh`:

   ```sh
   git clone https://github.com/Magiszonekk/impasto-local ~/impasto-local
   ~/impasto-local/update.sh
   ```

   `apply.sh` also installs the scripts from `bin/` and the timers, so old versions on a migrated machine
   get replaced. It ends by reloading Hyprland and checking `hyprctl configerrors`.

4. **Clean up after the old layout** (optional):
   - `vscodium-bin` and `zen-browser-bin` will now be added by the author's `./setup install`. If you do not want them:
     `yay -Rns vscodium-bin zen-browser-bin`. The overlay cannot hide them from `setup`.
   - Old `*.bak*` files in `~/.config`.
   - You can keep the `fork` remote or remove it: `git remote remove fork`.

5. `sudo reboot`, if `setup` said that libraries were replaced.

After the migration, check:

```sh
cd ~/impasto && git remote -v && ./setup files list    # origin = the author; "edited" only the 3 files from patches/
hyprctl configerrors                                   # empty
```

---

## Updates

```sh
~/impasto-local/update.sh
```

Do not use `./setup update` or the Update button in Settings → System. The button runs `~/impasto/setup update`
without the overlay: the three quickshell files from the patches then stay as they were, and the author's new version
lands beside them as `.new`. The Updates tab does correctly show that the author has news, because it compares
`~/impasto` with `origin`.

`update.sh` refuses to work if `~/impasto` has local changes or `origin` does not point at the author.
If `apply.sh` says `DOES NOT APPLY <file>.patch`, the author changed that part of the file: fix the patch
(apply it with `git apply --3way` in a fresh `git worktree` of `origin/main`, then make the new one with `git diff HEAD`).

System package updates go separately through `sys-update` (a pinned mirrorlist, a monthly cycle).

## New changes

Do not edit files in `~/impasto`. Add keybinds, window rules and env to `hypr-custom/` (loaded after the author's
module, so moving someone else's keybind to a different key needs `hl.unbind(...)` before your own `hl.bind`).
Make Quickshell changes as a new patch in `patches/quickshell/`. Detect hardware differences at run time
(`/sys`, `/proc/driver/nvidia`) instead of using separate branches.

## What is not tested

The scripts were checked for syntax (`bash -n`), and `apply.sh` also in two runs on a copy of the author's clean files.
The **new machine** path (`bootstrap.sh` + `finish.sh`) and the **migration** have not been run on a clean system.
