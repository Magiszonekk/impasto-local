#!/usr/bin/env bash
# Aktualizacja od autora impasto + ponowne nałożenie lokalnych zmian.
# setup trzyma pliki edytowane w miejscu (nowa wersja ląduje obok jako .new),
# więc łatane pliki najpierw wracają do wersji z repo, potem update, potem łatki.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMPASTO=${IMPASTO_DIR:-$HOME/impasto}
cd "$IMPASTO"
git remote get-url origin | grep -q andreumassanet || { echo "origin klona nie wskazuje na autora" >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo "klon impasto ma lokalne zmiany; nakładka ma być osobno" >&2; exit 1; }

paths=$(grep -h '^+++ b/' "$HERE"/patches/quickshell/*.patch | sed 's|^+++ b/home/||' | sort -u)
echo "==> przywracam łatane pliki do wersji z repo"
# shellcheck disable=SC2086
./setup files reset $paths || true
echo "==> ./setup update"
./setup update "$@"
echo "==> nakładka"
"$HERE/apply.sh" --no-packages
