#!/usr/bin/env bash
# Update from the impasto author + re-apply the local changes.
# setup keeps files edited in place (the new version lands beside them as .new),
# so the patched files first go back to the repo's version, then update, then the patches.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMPASTO=${IMPASTO_DIR:-$HOME/impasto}
cd "$IMPASTO"
git remote get-url origin | grep -q andreumassanet || { echo "the clone's origin does not point at the author" >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo "the impasto clone has local changes; the overlay is meant to live separately" >&2; exit 1; }

paths=$(grep -h '^+++ b/' "$HERE"/patches/quickshell/*.patch | sed 's|^+++ b/home/||' | sort -u)
echo "==> restoring the patched files to the repo's version"
# shellcheck disable=SC2086
./setup files reset $paths || true
echo "==> ./setup update"
./setup update "$@"
echo "==> overlay"
rc=0
"$HERE/apply.sh" --no-packages || rc=1
echo "==> restarting quickshell"
"$HERE/restart-shell.sh" || rc=1
exit $rc
