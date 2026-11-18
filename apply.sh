#!/usr/bin/env bash
# Nakłada lokalne zmiany na czysty klon impasto (~/impasto, remote = autor).
# Idempotentny. Użycie: ./apply.sh [--no-packages]
#   hypr-custom/*.lua -> ~/.config/hypr/custom/   (autor tego katalogu nie rusza)
#   packages/*.txt    -> doinstalowane ponad listę autora
#   patches/quickshell/*.patch -> ~/.config/quickshell (autor nie ma tu haka)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QS=${QS_DIR:-$HOME/.config/quickshell}
HYPR=${HYPR_DIR:-$HOME/.config/hypr}
b=$'\e[1m'; y=$'\e[33m'; o=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$b" "$*" "$o"; }
warn() { printf '%s%s%s\n' "$y" "$*" "$o"; }

step "Hyprland: custom/"
mkdir -p "$HYPR/custom"
for f in "$HERE"/hypr-custom/*.lua; do
    install -m 644 "$f" "$HYPR/custom/$(basename "$f")"; echo "ok  $(basename "$f")"
done

if [[ ${1:-} != --no-packages ]]; then
    step "Paczki"
    mapfile -t pac < <(sed 's/#.*//' "$HERE/packages/pacman.txt" | awk 'NF{print $1}')
    mapfile -t aur < <(sed 's/#.*//' "$HERE/packages/aur.txt" | awk 'NF{print $1}')
    (( ${#pac[@]} )) && sudo pacman -S --needed --noconfirm "${pac[@]}"
    (( ${#aur[@]} )) && { command -v yay >/dev/null && yay -S --needed --noconfirm "${aur[@]}" || warn "brak yay, pomijam AUR"; }
fi

step "Quickshell: łatki"
rc=0
for p in "$HERE"/patches/quickshell/*.patch; do
    n=$(basename "$p")
    if patch -p4 -R --dry-run -s -d "$QS" < "$p" >/dev/null 2>&1; then
        echo "już    $n"
    elif patch -p4 --dry-run -s -d "$QS" < "$p" >/dev/null 2>&1; then
        patch -p4 -s -d "$QS" < "$p"; echo "nałożona $n"
    else
        warn "NIE PASUJE $n (autor zmienił ten fragment; popraw łatkę)"; rc=1
    fi
done
exit $rc
