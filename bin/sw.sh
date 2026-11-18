#!/bin/sh
# Temporary passwordless sudo for the user who called sudo.
# Run: sudo sh ~/sw.sh [minutes, default 60]
# The rule lives in /run (tmpfs), so it also disappears on reboot.
# Needs /etc/sudoers.d/98-sudo-window-include with "@includedir /run/sudo-window".
set -e
U=${SUDO_USER:?run via sudo}
MIN=${1:-60}
D=/run/sudo-window
F=$D/$U
T=$(mktemp)
printf 'Defaults:%s verifypw=any\n%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$U" "$U" > "$T"
visudo -cf "$T"
install -d -m 750 "$D"
install -m 440 -o root -g root "$T" "$F"
rm -f "$T"
systemctl stop sudo-window-off.timer 2>/dev/null || true
systemd-run --on-active="${MIN}min" --unit=sudo-window-off rm -f "$F"
echo "OK: passwordless sudo until $(date -d "+${MIN} min" +%H:%M)"
