#!/usr/bin/env bash
# Restart Quickshell and check that the new config really loaded.
# Why: qs reloads on file changes, but a reload that lands mid-update fails
# ("Failed to load configuration") and silently leaves the OLD code running.
# Exit codes: 0 = loaded (or nothing to do), 1 = the config did not load.
# NO_QS_RESTART=1 skips the whole thing.
set -u

[[ -z ${NO_QS_RESTART:-} ]] || { echo "qs restart skipped (NO_QS_RESTART)"; exit 0; }
command -v qs >/dev/null || { echo "qs not installed, skipping"; exit 0; }
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo "not in a Hyprland session, skipping the qs restart"; exit 0; }

noise='textinput|qt\.qpa'

pkill -x quickshell 2>/dev/null
pkill -x qs 2>/dev/null
sleep 1
qs -d >/dev/null 2>&1

for _ in $(seq 1 20); do
    sleep 1
    log=$(qs log 2>&1 | grep -viE "$noise")
    if grep -q 'Configuration Loaded' <<<"$log"; then
        echo "quickshell: config loaded"
        exit 0
    fi
    grep -q 'Failed to load configuration' <<<"$log" && break
done

echo "quickshell: the config did NOT load. Errors:" >&2
grep -E 'ERROR' <<<"$log" | head -8 >&2
echo "(full log: qs log)" >&2
exit 1
