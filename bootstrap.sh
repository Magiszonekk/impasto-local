#!/usr/bin/env bash
# Phase 1: the system. Run from a TTY on a fresh Arch (archinstall: btrfs +
# Limine with ESP=/boot), as a regular user with sudo:
#   git clone https://github.com/andreumassanet/impasto ~/impasto
#   git clone https://github.com/Magiszonekk/impasto-local ~/impasto-local
#   ~/impasto-local/bootstrap.sh
# Then start Hyprland and run ~/impasto-local/finish.sh.
# The author's repo (~/impasto) stays a clean clone; my changes are in this repo.
#
# Sets up: snapper + snap-pac, limine-snapper-sync, btrfs-overlayfs,
# /etc/default/limine, Windows/Ubuntu entries from another ESP partition
# (bin/limine-dualboot), multilib, the NVIDIA driver with early KMS, a Polish
# keyboard (TTY and SDDM), /mnt/win and /mnt/ubuntu, a pinned mirrorlist
# (Arch Linux Archive), the sudo window, and finally hyprland and kitty.
# The script is idempotent: steps that are already done are skipped.
# PIN_DATE=YYYY/MM/DD ./bootstrap.sh  -> a date other than "yesterday".
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PIN_DATE=${PIN_DATE:-$(date -d yesterday +%Y/%m/%d)}
ARCHIVE=https://archive.archlinux.org/repos
USER_NAME=$(id -un)
# Keyboard layout: console (vconsole) and X11 (SDDM login screen).
# Hyprland has its own in hypr-custom/input.lua.
KEYMAP=${KEYMAP:-pl}
# Partitions of other systems to mount (an empty value = skip).
WIN_UUID=${WIN_UUID-}
UBUNTU_UUID=${UBUNTU_UUID-}
# An NVIDIA card (vendor 0x10de, class 0x03xxxx = display controller)?
NVIDIA=no
for d in /sys/bus/pci/devices/*; do
    [[ $(<"$d/vendor") == 0x10de && $(<"$d/class") == 0x03* ]] && NVIDIA=yes && break
done

b=$'\e[1m'; y=$'\e[33m'; r=$'\e[31m'; o=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$b" "$*" "$o"; }
warn() { printf '%s%s%s\n' "$y" "$*" "$o"; }
die()  { printf '%sERROR:%s %s\n' "$r" "$o" "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as a regular user (the script calls sudo itself)"
[[ $(findmnt -no FSTYPE /) == btrfs ]] || die "root is not on btrfs, snapshots will not work"
command -v limine >/dev/null || die "limine is missing. This script expects the Limine bootloader from archinstall"
mountpoint -q /boot || die "/boot is not a separate mount (ESP). Expected ESP=/boot"
sudo -v

step "multilib"
if ! grep -qE '^\[multilib\]' /etc/pacman.conf; then
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo sed -i -E '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
fi
grep -qE '^\[multilib\]' /etc/pacman.conf || die "could not enable multilib in /etc/pacman.conf"

step "Keyboard: $KEYMAP (console and login screen)"
# before mkinitcpio: the keymap/sd-vconsole hook puts this layout into the initramfs
sudo localectl set-keymap "$KEYMAP"
sudo localectl set-x11-keymap --no-convert "$KEYMAP"
localectl status | grep -E 'VC Keymap|X11 Layout'

step "Pinning the repositories to $PIN_DATE"
code=$(curl -s -o /dev/null -w '%{http_code}' "$ARCHIVE/$PIN_DATE/core/os/x86_64/core.db" || true)
[[ $code == 200 ]] || die "snapshot $PIN_DATE does not exist in the archive (HTTP $code); set PIN_DATE"
[[ -e /etc/pacman.d/mirrorlist.rolling ]] || sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.rolling
echo "Server = $ARCHIVE/$PIN_DATE/\$repo/os/\$arch" | sudo tee /etc/pacman.d/mirrorlist >/dev/null
sudo systemctl disable --now reflector.timer 2>/dev/null || true
sudo pacman -Sy --noconfirm
hv=$(pacman -Si hyprland 2>/dev/null | awk '/^Version/{print $3}')
echo "hyprland in this snapshot: ${hv:-none}"
case ${hv:-0} in 0.5[6-9]*|0.[6-9]*|[1-9]*) ;; *) warn "impasto needs hyprland >= 0.56; pick a later PIN_DATE" ;; esac

step "Base packages"
sudo pacman -S --needed --noconfirm git base-devel btrfs-progs snapper snap-pac \
    efibootmgr zram-generator inotify-tools \
    speedtest-cli tmux openssh nodejs npm ttf-dejavu
if [[ $NVIDIA == yes ]]; then
    step "Sterownik NVIDIA (open kernel modules)"
    sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils lib32-nvidia-utils libva-nvidia-driver
fi

step "yay and the Limine tools from the AUR"
if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
yay -S --needed --noconfirm limine-mkinitcpio-hook limine-snapper-sync

step "Snapper"
if ! sudo test -e /etc/snapper/configs/root; then
    if mountpoint -q /.snapshots; then sudo umount /.snapshots; fi
    sudo rmdir /.snapshots 2>/dev/null || true
    [[ ! -e /.snapshots ]] || die "/.snapshots is not empty, check by hand"
    sudo snapper -c root create-config /
    sudo btrfs subvolume delete /.snapshots
    sudo mkdir /.snapshots
    if ! grep -qE '[[:space:]]/\.snapshots[[:space:]]' /etc/fstab; then
        # a separate top-level @snapshots subvolume, so a rollback of @ does not take it along
        src=$(findmnt -no SOURCE / | sed 's/\[.*//')
        uuid=$(sudo blkid -s UUID -o value "$src")
        top=$(mktemp -d)
        sudo mount -o subvolid=5 "$src" "$top"
        sudo btrfs subvolume list "$top" | grep -q ' path @snapshots$' \
            || sudo btrfs subvolume create "$top/@snapshots"
        sudo umount "$top"; rmdir "$top"
        sudo cp /etc/fstab /etc/fstab.bak
        printf 'UUID=%s\t/.snapshots\tbtrfs\trw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots\t0 0\n' \
            "$uuid" | sudo tee -a /etc/fstab >/dev/null
    fi
    sudo systemctl daemon-reload
    sudo mount -a
    mountpoint -q /.snapshots || die "/.snapshots did not mount"
    sudo chmod 750 /.snapshots
fi
sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_CLEANUP=yes \
    NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 SYNC_ACL=yes "ALLOW_USERS=$USER_NAME"
sudo systemctl enable --now snapper-cleanup.timer

step "mkinitcpio: btrfs-overlayfs, no fallback (the ESP has little space)"
if ! grep -qE '^HOOKS=.*btrfs-overlayfs' /etc/mkinitcpio.conf; then
    sudo cp /etc/mkinitcpio.conf /root/mkinitcpio.conf.bak
    if grep -qE '^HOOKS=.*[( ]fsck' /etc/mkinitcpio.conf; then
        sudo sed -i -E '/^HOOKS=/ s/ fsck/ btrfs-overlayfs fsck/' /etc/mkinitcpio.conf
    else
        sudo sed -i -E '/^HOOKS=/ s/\)$/ btrfs-overlayfs)/' /etc/mkinitcpio.conf
    fi
fi
grep -E '^HOOKS=' /etc/mkinitcpio.conf
sudo sed -i -E "s/^PRESETS=.*/PRESETS=('default')/" /etc/mkinitcpio.d/linux.preset
sudo rm -f /boot/initramfs-linux-fallback.img
if [[ $NVIDIA == yes ]]; then
    # early KMS: splash and Hyprland on nvidia_drm from the first frame;
    # the kms hook would pull nouveau into the initramfs
    sudo install -m 644 /dev/stdin /etc/mkinitcpio.conf.d/nvidia.conf \
        <<< 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)'
    sudo sed -i -E '/^HOOKS=/ s/ kms( |\))/\1/' /etc/mkinitcpio.conf
fi

step "/etc/default/limine"
src=$(findmnt -no SOURCE / | sed 's/\[.*//')
partuuid=$(lsblk -no PARTUUID "$src")
extra=""
[[ $NVIDIA == yes ]] && extra=" nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
[[ -n $partuuid ]] || die "no PARTUUID for $src"
[[ ! -e /etc/default/limine ]] || sudo cp -n /etc/default/limine /root/limine.default.bak
sudo tee /etc/default/limine >/dev/null <<EOF
ESP_PATH="/boot"
TARGET_OS_NAME="Arch Linux"
UEFI_BOOT_ORDER=first
FIND_BOOTLOADERS=no
ENABLE_UKI=no
MKINITCPIO_FALLBACK=no
KERNEL_CMDLINE[default]="root=PARTUUID=$partuuid rootflags=subvol=@ rootfstype=btrfs rw zswap.enabled=0$extra quiet splash"
EOF
sudo limine-update
sudo systemctl enable --now limine-snapper-sync.service
sudo rm -f /boot/vmlinuz-linux /boot/initramfs-linux.img

# FIND_BOOTLOADERS only searches ESP_PATH (/boot), while Windows and Ubuntu
# have their bootloaders on another ESP partition; it only found Limine's own
# fallback. The chainload entries are made by limine-dualboot from NVRAM.
step "Limine: Windows and Ubuntu (chainload from another ESP partition)"
sudo "$HERE/bin/limine-dualboot" || warn "limine-dualboot failed; add the entries by hand in /boot/limine.conf"

step "Windows and Ubuntu partitions"
add_mount() { # uuid directory type options
    [[ -n $1 ]] || return 0
    if ! sudo blkid -U "$1" >/dev/null; then warn "no partition with UUID=$1, skipping $2"; return 0; fi
    grep -q "UUID=$1" /etc/fstab && return 0
    sudo mkdir -p "$2"
    [[ -e /etc/fstab.bak ]] || sudo cp /etc/fstab /etc/fstab.bak
    printf 'UUID=%s\t%s\t%s\t%s\t0 0\n' "$1" "$2" "$3" "$4" | sudo tee -a /etc/fstab >/dev/null
}
# Windows is read-only: writing to NTFS is only safe once Fast Startup is
# turned off in Windows (then change ro to rw in /etc/fstab).
add_mount "$WIN_UUID" /mnt/win ntfs3 "ro,nofail,x-systemd.device-timeout=5s,uid=$(id -u),gid=$(id -g),iocharset=utf8"
add_mount "$UBUNTU_UUID" /mnt/ubuntu ext4 "rw,nofail,noatime,x-systemd.device-timeout=5s"
sudo systemctl daemon-reload
sudo mount -a || warn "mount -a reported an error, check /etc/fstab"

step "Phone over adb (Wireless debugging, mDNS via avahi)"
sudo pacman -S --needed --noconfirm avahi
sudo systemctl enable --now avahi-daemon

step "zram"
if [[ ! -e /etc/systemd/zram-generator.conf ]]; then
    printf '[zram0]\nzram-size = 4096\ncompression-algorithm = zstd\n' \
        | sudo tee /etc/systemd/zram-generator.conf >/dev/null
fi

step "Passwordless sudo window and user scripts"
# apply.sh installs bin/, systemd/ and ~/sw.sh (the same files as on update)
"$HERE/apply.sh" --scripts-only
sudo install -m 440 /dev/stdin /etc/sudoers.d/98-sudo-window-include <<< '@includedir /run/sudo-window'
sudo visudo -c >/dev/null && echo "sudoers OK"

# Starting Hyprland (start-hyprland, kitty) needs these before ./setup install.
step "Hyprland and kitty"
sudo pacman -S --needed --noconfirm hyprland kitty

step "Baseline snapshot"
sudo snapper -c root create -d "clean install (bootstrap)" --print-number

cat <<EOF

${b}Done.${o} Next:
  1. sudo reboot, check the Limine menu for the "Arch Linux" entry, its Snapshots
     submenu and the Windows Boot Manager and Ubuntu entries,
  2. check the boot order: efibootmgr (firmware may reorder it),
  3. start Hyprland (start-hyprland), then in kitty: ~/impasto-local/finish.sh
EOF
