#!/usr/bin/env bash
# Phase 2: from inside a running Hyprland session (impasto builds its plugins
# against the running compositor). Does: ./setup install in ~/impasto (a clean
# clone of the author's repo), then apply.sh (the overlay), the user's tools
# (Claude Code, Hermes, herdr), default apps and the bar layout.
# Idempotent: running it again is safe.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=${IMPASTO_DIR:-$HOME/impasto}
[[ -x $REPO/setup ]] || { echo "$REPO/setup is missing: git clone https://github.com/andreumassanet/impasto $REPO" >&2; exit 1; }

b=$'\e[1m'; y=$'\e[33m'; o=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$b" "$*" "$o"; }
warn() { printf '%s%s%s\n' "$y" "$*" "$o"; }

[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo "Run this from a Hyprland session (not from a TTY)." >&2; exit 1; }
export PATH="$HOME/.local/bin:$PATH"

step "Snapshot before impasto"
sudo snapper -c root create -d "before impasto (finish.sh)" --print-number

step "impasto: ./setup install"
(cd "$REPO" && ./setup install --noconfirm)

step "Overlay: apply.sh (hypr custom/, quickshell patches, packages)"
"$HERE/apply.sh" || warn "apply.sh reported a problem (e.g. a patch does not apply); fix it and run ./apply.sh again"

# Splash: ./setup splash edits the generated /boot/limine.conf, so we do it
# through /etc/default/limine and block that step with a stamp.
step "Splash (Plymouth)"
mkdir -p ~/.local/state/impasto/applied
if [[ ! -e ~/.local/state/impasto/applied/splash ]]; then
    if command -v plymouth-set-default-theme >/dev/null && sudo plymouth-set-default-theme -l | grep -qx impasto; then
        sudo plymouth-set-default-theme impasto
        grep -q 'splash' /etc/default/limine || sudo sed -i -E '/^KERNEL_CMDLINE\[default\]=/ s/"$/ quiet splash"/' /etc/default/limine
        sudo limine-update
        : > ~/.local/state/impasto/applied/splash
    else
        warn "plymouth theme 'impasto' is not available, skipping the splash"
    fi
fi

step "Claude Code"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

step "Hermes Agent"
command -v hermes >/dev/null || curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive

step "herdr"
command -v herdr >/dev/null || curl -fsSL https://releases.herdr.dev/app/install.sh | sh

step "herdr integrations (Claude Code, Hermes)"
for t in claude hermes; do
    herdr integration install "$t" || warn "herdr/$t integration failed"
done

step "Discordrive (AppImage + menu entry)"
mkdir -p ~/Applications ~/.local/share/applications ~/.local/share/icons
if [[ ! -x ~/Applications/discordrive.AppImage ]]; then
    url=$(curl -fsSL https://api.github.com/repos/Magiszonekk/discordrive/releases/tags/main-build \
        | grep -o 'https://[^"]*linux-x86_64\.AppImage' | head -1)
    if [[ -n $url ]]; then
        curl -fL "$url" -o ~/Applications/discordrive.AppImage && chmod +x ~/Applications/discordrive.AppImage
    else
        warn "no Discordrive AppImage found in the main-build release, skipping"
    fi
fi
cp "$HERE/icons/discordrive.png" ~/.local/share/icons/discordrive.png
sed "s|@HOME@|$HOME|g" "$HERE/applications/discordrive.desktop" > ~/.local/share/applications/discordrive.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true

step "Default applications and bar layout"
[[ -e ~/.config/mimeapps.list ]] && cp -n ~/.config/mimeapps.list ~/.config/mimeapps.list.pre-local
cp "$HERE/config/mimeapps.list" ~/.config/mimeapps.list
mkdir -p ~/.local/state/quickshell
[[ -e ~/.local/state/quickshell/settings.json ]] && cp -n ~/.local/state/quickshell/settings.json ~/.local/state/quickshell/settings.json.pre-local
cp "$HERE/config/quickshell-settings.json" ~/.local/state/quickshell/settings.json

cat <<EOF

${b}Done.${o} Left to do by hand:
  - log in: claude (account), hermes setup (API keys/provider), Spotify (run it once, then ./setup spotify)
  - Brave/Zed/FileZilla are installed by apply.sh from the overlay's packages/
  - updates from the author: ~/impasto-local/update.sh (not ./setup update or the button in Settings)
  - log out and back in so the bar loads the layout; run sys-update to check for system updates
EOF
