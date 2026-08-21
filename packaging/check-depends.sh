#!/usr/bin/env bash
#
# Fail if packaging/PKGBUILD's dependency list has drifted from
# install/packages.txt.
#
# Two files encode the same fact and neither can generate the other:
# `makepkg` parses depends=() to resolve dependencies BEFORE sources are
# fetched, so the PKGBUILD cannot read the manifest at build time — $srcdir
# does not exist yet. The manifest stays canonical, the PKGBUILD stays
# readable, and this script catches the gap in CI rather than in a user's
# install.
#
# Exit codes are distinct on purpose:
#
#     0   the two agree
#     1   they have drifted — the diff says how
#     2   the check could not run at all (a file is missing)
#
# CI needs to tell "your dependency lists disagree" apart from "the check
# itself is broken"; a single non-zero exit conflates them.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${DAWN_MANIFEST:-$REPO/install/packages.txt}"
PKGBUILD="${DAWN_PKGBUILD:-$REPO/packaging/PKGBUILD}"

[ -r "$MANIFEST" ] || { echo "missing manifest: $MANIFEST" >&2; exit 2; }
[ -r "$PKGBUILD" ] || { echo "missing PKGBUILD: $PKGBUILD" >&2; exit 2; }

manifest="$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$MANIFEST" | sort -u)"

# Source the PKGBUILD in a subshell purely to read _dawn_depends. Sourcing is
# safe here because this runs on our own file in CI, not on untrusted input.
# SC1090: the path is a variable, so shellcheck cannot follow it.
# SC2154: _dawn_depends is defined by the PKGBUILD being sourced, not here.
#         Bash 4.4+ expands an unset array under `set -u` to nothing rather
#         than erroring, so a PKGBUILD without it yields an empty string and
#         is caught by the guard below instead of dying mid-script.
# `if !` rather than a bare assignment: under `set -e` a failing command
# substitution kills the script instantly, with no message and exit 1 — which
# is indistinguishable from "the lists differ". Catching it here turns a
# PKGBUILD that cannot even be sourced into exit 2 and a sentence saying so.
# shellcheck disable=SC1090,SC2154
if ! pkgbuild="$(
	source "$PKGBUILD" >/dev/null 2>&1
	printf '%s\n' "${_dawn_depends[@]}" | sort -u
)"; then
	echo "could not source $PKGBUILD to read _dawn_depends" >&2
	exit 2
fi

if [ -z "$pkgbuild" ]; then
	echo "PKGBUILD defines no _dawn_depends array: $PKGBUILD" >&2
	exit 2
fi

if [ "$manifest" = "$pkgbuild" ]; then
	echo "ok: PKGBUILD dependencies match install/packages.txt ($(echo "$manifest" | wc -l) packages)"
	exit 0
fi

echo "PKGBUILD dependencies have drifted from install/packages.txt" >&2
echo >&2
diff -u --label 'install/packages.txt' --label 'packaging/PKGBUILD' \
	<(echo "$manifest") <(echo "$pkgbuild") >&2 || true
exit 1
