#!/usr/bin/env bash
#
# ==========================================================================
#  DAWN — BUILD, SIGN, AND ASSEMBLE THE PACMAN REPOSITORY
# ==========================================================================
#
#      ./packaging/release.sh <outdir>
#
# Produces a complete, signed pacman repository in <outdir>/x86_64, ready to
# be committed to dawnlinux/repo and served by GitHub Pages.
#
# Run by .github/workflows/release.yml on a tag, and runnable by hand to
# reproduce or debug a release locally.
#
# ── Environment ───────────────────────────────────────────────────────────
#
#   DAWN_SIGNING_KEY   fingerprint to sign with (default: the Dawn key)
#   DAWN_LOCAL_SOURCE  build from this checkout instead of the published tag
#
# ── Why symlinks are dereferenced ─────────────────────────────────────────
#
# `repo-add` creates dawn.db as a SYMLINK to dawn.db.tar.gz, and pacman
# fetches the plain `dawn.db` name. GitHub Pages does not follow symlinks —
# committing them yields a 404 or a file containing the link text, and the
# repository looks broken to every user while appearing fine in git. So every
# link is materialised into a real file here.
# ==========================================================================

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${DAWN_SIGNING_KEY:-C36BACF174290B6ED5456879BCB1F6ACA2DD7A59}"

OUT="${1:-}"
[ -n "$OUT" ] || { echo "usage: release.sh <outdir>" >&2; exit 2; }

step() { printf '\n\033[1;37m%s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v makepkg  >/dev/null || die "makepkg not found"
command -v repo-add >/dev/null || die "repo-add not found (pacman)"
command -v gpg      >/dev/null || die "gpg not found"

gpg --list-keys "$KEY" >/dev/null 2>&1 \
	|| die "signing key not in this keyring: $KEY"

ARCHDIR="$OUT/x86_64"
mkdir -p "$ARCHDIR"

# ── Build ─────────────────────────────────────────────────────────────────

step "Building packages"
cd "$REPO/packaging"
rm -f ./*.pkg.tar.zst ./*.sig
makepkg --force --cleanbuild --syncdeps --noconfirm
ok "$(find . -maxdepth 1 -name '*.pkg.tar.zst' | wc -l) packages built"

# ── Sign ──────────────────────────────────────────────────────────────────

step "Signing"
for pkg in ./*.pkg.tar.zst; do
	gpg --batch --yes --detach-sign --no-armor -u "$KEY" "$pkg"
	gpg --verify "$pkg.sig" "$pkg" >/dev/null 2>&1 \
		|| die "signature failed to verify immediately after signing: $pkg"
	ok "$(basename "$pkg")"
done

# ── Assemble ──────────────────────────────────────────────────────────────

step "Assembling the repository"
cp ./*.pkg.tar.zst ./*.sig "$ARCHDIR/"
cd "$ARCHDIR"
repo-add --sign --key "$KEY" dawn.db.tar.gz ./*.pkg.tar.zst

# Materialise repo-add's symlinks. See the header for why this matters.
for link in dawn.db dawn.db.sig dawn.files dawn.files.sig; do
	if [ -L "$link" ]; then
		target="$(readlink "$link")"
		rm "$link"
		cp "$target" "$link"
		ok "$link materialised from $target"
	fi
done

# ── Publish the public key ────────────────────────────────────────────────

step "Exporting the public key"
gpg --armor --export "$KEY" > "$OUT/dawn.gpg"
[ -s "$OUT/dawn.gpg" ] || die "public key export is empty"
ok "dawn.gpg ($(wc -c < "$OUT/dawn.gpg") bytes)"

# ── Verify what we produced ───────────────────────────────────────────────

step "Verifying the assembled repository"
for sig in ./*.sig; do
	gpg --verify "$sig" "${sig%.sig}" >/dev/null 2>&1 \
		|| die "bad signature in the output tree: $sig"
done
ok "every signature verifies"

for f in dawn.db dawn.db.sig; do
	[ -f "$f" ] && [ ! -L "$f" ] || die "$f is missing or still a symlink"
done
ok "database files are real files, not symlinks"

printf '\n  Repository ready in %s\n\n' "$OUT"
