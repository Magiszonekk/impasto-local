#!/usr/bin/env bash
# Nakłada lokalne zmiany na czysty klon impasto (~/impasto, remote = autor).
# Idempotentny. Użycie: ./apply.sh [--no-packages | --scripts-only]
#   bin/, systemd/      -> ~/.local/bin, ~/sw.sh, ~/.config/systemd/user (+ enable timerów)
#   hypr-custom/*.lua   -> ~/.config/hypr/custom/   (autor tego katalogu nie rusza)
#   home/zshrc.local    -> ~/.zshrc.local
#   packages/*.txt      -> doinstalowane ponad listę autora
#   patches/quickshell/ -> ~/.config/quickshell (autor nie ma tu haka)
# --scripts-only: tylko pierwszy punkt (bootstrap woła tak przed instalacją impasto).
# Zmienne do testów na kopii: QS_DIR, HYPR_DIR, BIN_DIR, SYSTEMD_DIR.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QS=${QS_DIR:-$HOME/.config/quickshell}
HYPR=${HYPR_DIR:-$HOME/.config/hypr}
BIN=${BIN_DIR:-$HOME/.local/bin}
UNITS=${SYSTEMD_DIR:-$HOME/.config/systemd/user}
MODE=${1:-}
case $MODE in ""|--no-packages|--scripts-only) ;; *) echo "użycie: $0 [--no-packages|--scripts-only]" >&2; exit 2 ;; esac
b=$'\e[1m'; y=$'\e[33m'; o=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$b" "$*" "$o"; }
warn() { printf '%s%s%s\n' "$y" "$*" "$o"; }

step "Skrypty i timery użytkownika"
mkdir -p "$BIN" "$UNITS"
for f in "$HERE"/bin/*; do
    n=$(basename "$f")
    case $n in
        limine-dualboot) ;;                                   # woła go bootstrap przez sudo, nie trafia do PATH
        sw.sh) install -m 755 "$f" "${SW_DEST:-$HOME/sw.sh}"; echo "ok  ~/sw.sh" ;;
        *)     install -m 755 "$f" "$BIN/$n";      echo "ok  $n" ;;
    esac
done
install -m 644 "$HERE"/systemd/*.service "$HERE"/systemd/*.timer "$UNITS/"
if [[ -z ${SYSTEMD_DIR:-} ]]; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable sys-update-reminder.timer tools-autoupdate.timer 2>/dev/null \
        || warn "timery: włącz po zalogowaniu do sesji: systemctl --user enable --now sys-update-reminder.timer tools-autoupdate.timer"
fi

[[ $MODE == --scripts-only ]] && exit 0

step "Hyprland: custom/"
mkdir -p "$HYPR/custom"
for f in "$HERE"/hypr-custom/*.lua; do
    install -m 644 "$f" "$HYPR/custom/$(basename "$f")"; echo "ok  $(basename "$f")"
done

step "zsh: ~/.zshrc.local"
install -m 644 "$HERE/home/zshrc.local" "${ZSHRC_LOCAL:-$HOME/.zshrc.local}"; echo "ok  .zshrc.local"

if [[ $MODE != --no-packages ]]; then
    step "Paczki"
    mapfile -t pac < <(sed 's/#.*//' "$HERE/packages/pacman.txt" | awk 'NF{print $1}')
    mapfile -t aur < <(sed 's/#.*//' "$HERE/packages/aur.txt" | awk 'NF{print $1}')
    (( ${#pac[@]} )) && sudo pacman -S --needed --noconfirm "${pac[@]}"
    if (( ${#aur[@]} )); then
        if command -v yay >/dev/null; then yay -S --needed --noconfirm "${aur[@]}"
        else warn "brak yay, pomijam AUR: ${aur[*]}"; fi
    fi
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

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -z ${HYPR_DIR:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    sleep 1; err=$(hyprctl configerrors 2>/dev/null | tr -d '\n ')
    if [[ -z $err ]]; then echo "hyprctl: config bez błędów"; else warn "hyprctl configerrors: $err"; rc=1; fi
fi
exit $rc
