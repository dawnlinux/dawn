#!/usr/bin/env bash
#
# ==========================================================================
#  DAWN — BOOTSTRAP
# ==========================================================================
#
#      ./install.sh              add the Dawn repository and install Dawn
#      ./install.sh --dry-run    print every action, change nothing
#      ./install.sh --help       this text
#
# ── What this does ────────────────────────────────────────────────────────
#
#   1. imports and locally signs the Dawn package signing key
#   2. adds the [dawn] section to /etc/pacman.conf
#   3. pacman -Sy dawn
#   4. dawn link
#
# That is all it does. Linking, backups and seeding live in the `dawn` CLI
# shipped by dawn-config, so there is exactly one implementation of that
# logic rather than two that drift apart.
#
# ── What this does NOT do ─────────────────────────────────────────────────
#
# It does not touch your display manager. Switching to dawn-greet is a
# separate, reversible step:
#
#     sudo /usr/share/dawn/greetd/install.sh
#
# It does not run as root. It calls sudo for the steps that need it.
#
# ── Uninstalling ──────────────────────────────────────────────────────────
#
#     dawn unlink                        remove links, restore backups
#     sudo pacman -Rns dawn dawn-config  remove the packages
# ==========================================================================

set -euo pipefail

# Set by packaging/release.sh at tag time. Until the first signed release
# exists this is the placeholder, and import_key refuses to continue rather
# than trusting an unknown key.
DAWN_KEY_ID='REPLACE_WITH_FINGERPRINT'
DAWN_KEY_URL='https://dawnlinux.github.io/repo/dawn.gpg'
# $arch is expanded by PACMAN, not by bash — it must reach pacman.conf
# literally, so the single quotes here are deliberate and required.
# shellcheck disable=SC2016
DAWN_REPO_URL='https://dawnlinux.github.io/repo/$arch'

DRY_RUN=0

step() { printf '\n\033[1;37m%s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '   \033[90m·\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '   \033[90mwould:\033[0m %s\n' "$*"
	else
		"$@"
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		-h|--help) sed -n '2,36p' "${BASH_SOURCE[0]}" | sed 's/^#[[:space:]]\?//'; exit 0 ;;
		*)         die "unknown argument: $1 (try --help)" ;;
	esac
	shift
done

preflight() {
	step "Checking this machine"
	[ "$(id -u)" -ne 0 ] || die "do not run this as root — it calls sudo itself"
	command -v pacman >/dev/null 2>&1 \
		|| die "pacman not found. Dawn is an Arch distribution; it does not
       install on other package managers."
	ok "Arch-based system"
}

import_key() {
	step "Importing the Dawn signing key"

	# Validated by SHAPE, not by comparing against the placeholder string.
	# The release step substitutes the fingerprint with sed, which would
	# rewrite a literal comparison here too — leaving a guard that compares
	# the real key against itself and always fires. A format check cannot be
	# broken that way, and it also catches a truncated or malformed key.
	if ! [[ "$DAWN_KEY_ID" =~ ^[0-9A-Fa-f]{40}$ ]]; then
		die "this checkout has no signing key baked in yet.

       Dawn packages are signed, and pacman is configured with
       SigLevel = Required, so an unsigned or unknown-key package is
       refused. Until the first signed release exists there is nothing
       to install from the repository.

       To build and install from this checkout instead:

           cd packaging && DAWN_LOCAL_SOURCE=1 makepkg --syncdeps --install
           dawn link"
	fi

	if sudo pacman-key --list-keys "$DAWN_KEY_ID" >/dev/null 2>&1; then
		skip "already imported"
		return
	fi

	# Fetched over HTTPS and then LOCALLY SIGNED, which is what actually
	# grants it trust on this machine. Without the lsign step pacman still
	# rejects packages signed by it.
	if ! run sudo pacman-key --recv-keys "$DAWN_KEY_ID"; then
		warn "keyserver lookup failed — falling back to the published key file"
		run bash -c "curl -fsSL '$DAWN_KEY_URL' | sudo pacman-key --add -"
	fi
	run sudo pacman-key --lsign-key "$DAWN_KEY_ID"
	ok "key $DAWN_KEY_ID trusted"
}

add_repo() {
	step "Adding the [dawn] repository"

	if grep -q '^\[dawn\]' /etc/pacman.conf; then
		skip "already in /etc/pacman.conf"
		return
	fi

	# Appended, so it sits below the official repositories and cannot shadow
	# a core package by accident.
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '   \033[90mwould:\033[0m append [dawn] section to /etc/pacman.conf\n'
		return
	fi

	sudo tee -a /etc/pacman.conf >/dev/null <<-EOF

		[dawn]
		SigLevel = Required DatabaseOptional
		Server = $DAWN_REPO_URL
	EOF
	ok "added to /etc/pacman.conf"
}

install_dawn() {
	step "Installing Dawn"
	run sudo pacman -Sy --needed dawn
	[ "$DRY_RUN" -eq 1 ] || ok "installed"
}

link_config() {
	step "Linking configuration"
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '   \033[90mwould:\033[0m dawn link\n'
		return
	fi
	command -v dawn >/dev/null 2>&1 || die "dawn-config did not install a /usr/bin/dawn"
	dawn link
}

main() {
	printf '\n\033[1;37m  dawn\033[0m — where your system comes to life\n'
	[ "$DRY_RUN" -eq 1 ] && printf '\033[33m  dry run: nothing will be changed\033[0m\n'

	preflight
	import_key
	add_repo
	install_dawn
	link_config

	cat <<-EOF

	  ─────────────────────────────────────────────────────────────────────

	  Dawn is installed. Log out and back in, or start Hyprland from a TTY.

	    The login screen   sudo /usr/share/dawn/greetd/install.sh
	    Your hardware      ~/.config/dawn/local.lua
	    Keybindings        /usr/share/dawn/config/quickshell/dawn-island/KEYMAP.md
	    What's linked      dawn status

	  From here on, Dawn updates like anything else:

	    sudo pacman -Syu

	  ─────────────────────────────────────────────────────────────────────

	EOF
}

main
