#!/usr/bin/env bash
#
# ==========================================================================
#  DAWN — INSTALLER
# ==========================================================================
#
#      ./install.sh                 install Dawn
#      ./install.sh --dry-run       print every action, change nothing
#      ./install.sh --no-packages   skip pacman, link config only
#      ./install.sh --uninstall     remove Dawn's symlinks, restore backups
#      ./install.sh --help          this text
#
# ── What this does ────────────────────────────────────────────────────────
#
#   1. installs the packages listed in install/packages.txt
#   2. symlinks config/<name> into ~/.config/<name>
#   3. seeds the gitignored local-override files from their .example
#   4. creates ~/Pictures/Wallpapers
#   5. offers to make fish your login shell
#
# ── What this does NOT do ─────────────────────────────────────────────────
#
# It does not touch your display manager. Switching to dawn-greet is a
# separate, reversible step with its own installer and its own way back:
#
#     sudo ./config/greetd/install.sh
#
# It does not delete anything. A real file or directory already sitting where
# a symlink needs to go is MOVED into a timestamped backup directory, never
# removed, and --uninstall puts it back.
#
# It does not run as root. It calls sudo for pacman and nothing else, so a
# bug in the linking logic can only ever affect your own home directory.
#
# ── Re-running it ─────────────────────────────────────────────────────────
#
# It is idempotent. A link that already points at the right place is left
# alone and reported as "ok", so running it after `git pull` is the supported
# way to pick up changes, and running it twice does nothing the second time.
# ==========================================================================

set -euo pipefail


# ── Where things are ──────────────────────────────────────────────────────

DAWN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DAWN/config"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}"
MANIFEST="$DAWN/install/packages.txt"

# One backup directory per run, so a single --uninstall can undo a single
# install without guessing which of several backups belongs to it.
BACKUP="$HOME/.dawn-backup/$(date +%Y%m%d-%H%M%S)"

# Directories (and one file) under config/ that belong in ~/.config.
#
# greetd is NOT here: it installs to /etc by its own script, because the
# greeter runs as an unprivileged user that cannot read your home directory.
LINKS=(
	fish
	hypr
	kitty
	nvim
	quickshell
	rofi
	starship.toml
)

# Gitignored machine-local override files, and the committed templates they
# are seeded from. See config/hypr/modules/local.lua.example.
declare -A SEEDS=(
	["$CONFIG_SRC/hypr/modules/local.lua"]="$CONFIG_SRC/hypr/modules/local.lua.example"
	["$CONFIG_SRC/fish/local.fish"]="$CONFIG_SRC/fish/local.fish.example"
)


# ── Output ────────────────────────────────────────────────────────────────

DRY_RUN=0
NO_PACKAGES=0

say()  { printf '\033[32m::\033[0m %s\n' "$*"; }
step() { printf '\n\033[1;37m%s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '   \033[90m·\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Every mutating action goes through this, so --dry-run is honest by
# construction rather than by remembering to check a flag at each call site.
run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '   \033[90mwould:\033[0m %s\n' "$*"
	else
		"$@"
	fi
}


# ── Arguments ─────────────────────────────────────────────────────────────

ACTION=install

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run)     DRY_RUN=1 ;;
		--no-packages) NO_PACKAGES=1 ;;
		--uninstall)   ACTION=uninstall ;;
		-h|--help)     sed -n '2,45p' "${BASH_SOURCE[0]}" | sed 's/^#[[:space:]]\?//'; exit 0 ;;
		*)             die "unknown argument: $1 (try --help)" ;;
	esac
	shift
done


# ── Preflight ─────────────────────────────────────────────────────────────

preflight() {
	step "Checking this machine"

	[ "$(id -u)" -ne 0 ] || die "do not run this as root — it installs into your home directory.
       It calls sudo itself for the one step that needs it."

	command -v pacman >/dev/null 2>&1 \
		|| die "pacman not found. Dawn is an Arch distribution; it does not
       install on other package managers."

	[ -d "$CONFIG_SRC" ] \
		|| die "no config/ directory next to this script — run it from inside a
       Dawn checkout, not from a copy of install.sh on its own."

	[ -r "$MANIFEST" ] || die "package manifest missing: $MANIFEST"

	ok "Arch-based system"
	ok "Dawn checkout at $DAWN"
}


# ── 1. Packages ───────────────────────────────────────────────────────────

install_packages() {
	step "Installing packages"

	if [ "$NO_PACKAGES" -eq 1 ]; then
		skip "--no-packages given"
		return
	fi

	# Strip comments and blank lines. The manifest is the only source of
	# truth for what Dawn depends on.
	local pkgs=()
	while read -r pkg; do
		[ -n "$pkg" ] && pkgs+=("$pkg")
	done < <(awk '!/^[[:space:]]*#/ && NF {print $1}' "$MANIFEST")

	[ ${#pkgs[@]} -gt 0 ] || die "package manifest parsed to nothing: $MANIFEST"

	# Report what is actually going to change before asking for a password.
	local wanted=()
	for pkg in "${pkgs[@]}"; do
		pacman -Qq "$pkg" >/dev/null 2>&1 || wanted+=("$pkg")
	done

	if [ ${#wanted[@]} -eq 0 ]; then
		ok "all ${#pkgs[@]} packages already installed"
		return
	fi

	say "${#wanted[@]} of ${#pkgs[@]} packages need installing: ${wanted[*]}"

	# --needed so re-runs are free; every package here is in the official
	# repositories, so no AUR helper is involved.
	run sudo pacman -S --needed "${pkgs[@]}"
	[ "$DRY_RUN" -eq 1 ] || ok "packages installed"
}


# ── 2. Config symlinks ────────────────────────────────────────────────────

# Move whatever currently occupies $1 into the run's backup directory,
# preserving its path so --uninstall can put it back exactly.
back_up() {
	local target="$1"
	run mkdir -p "$BACKUP"
	run mv "$target" "$BACKUP/$(basename "$target")"
	warn "existing $(basename "$target") moved to $BACKUP/"
}

link_one() {
	local name="$1"
	local src="$CONFIG_SRC/$name"
	local dst="$CONFIG_DST/$name"

	[ -e "$src" ] || { warn "$name: nothing to link at $src"; return; }

	# Already ours and pointing at the right place. This is the common case on
	# a re-run, and it must not touch the filesystem at all.
	if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
		skip "$name (already linked)"
		return
	fi

	# A symlink somewhere else — another dotfile manager, or an older Dawn
	# checkout. Replacing a symlink loses nothing, so no backup is taken.
	if [ -L "$dst" ]; then
		warn "$name pointed at $(readlink "$dst") — repointing"
		run rm "$dst"
	elif [ -e "$dst" ]; then
		# A real file or directory. Never destroyed.
		back_up "$dst"
	fi

	run mkdir -p "$(dirname "$dst")"

	# -n matters: without it, `ln -s src dst` where dst is an existing
	# directory silently creates dst/src instead of replacing dst. That is the
	# classic dotfile-installer bug that produces ~/.config/fish/fish.
	run ln -sfn "$src" "$dst"
	ok "$name -> $src"
}

link_configs() {
	step "Linking configuration into $CONFIG_DST"
	for name in "${LINKS[@]}"; do
		link_one "$name"
	done
}


# ── 3. Local overrides ────────────────────────────────────────────────────

seed_locals() {
	step "Seeding machine-local overrides"

	for target in "${!SEEDS[@]}"; do
		local example="${SEEDS[$target]}"
		local shown="${target#$DAWN/}"

		if [ -e "$target" ]; then
			skip "$shown (already yours)"
		elif [ -r "$example" ]; then
			run cp "$example" "$target"
			ok "$shown (from $(basename "$example"))"
		else
			warn "no template for $shown at $example"
		fi
	done
}


# ── 4. Wallpapers ─────────────────────────────────────────────────────────

setup_wallpapers() {
	step "Setting up wallpapers"

	# The island's wallpaper carousel reads this directory; see
	# `wallpaperDir` in config/quickshell/dawn-island/Config.qml.
	local dir="$HOME/Pictures/Wallpapers"

	if [ -d "$dir" ]; then
		skip "$dir (exists, $(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l) files)"
	else
		run mkdir -p "$dir"
		ok "created $dir"
	fi

	# Copy any images shipped in the repo. Extension-matched on purpose: the
	# directory also holds a README, and a README is not a wallpaper.
	# Extensions mirror `wallpaperExtensions` in the island's Config.qml.
	local seeded=0
	if [ -d "$DAWN/assets/wallpapers" ]; then
		while IFS= read -r wp; do
			[ -e "$dir/$(basename "$wp")" ] && continue
			run cp "$wp" "$dir/"
			seeded=$((seeded + 1))
		done < <(find "$DAWN/assets/wallpapers" -maxdepth 1 -type f \
			\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
			   -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \))
	fi
	[ "$seeded" -gt 0 ] && ok "copied $seeded wallpaper(s)" || skip "no new wallpapers to copy"
}


# ── 5. Login shell ────────────────────────────────────────────────────────

set_login_shell() {
	step "Login shell"

	local fish_bin
	fish_bin="$(command -v fish || true)"

	if [ -z "$fish_bin" ]; then
		skip "fish not installed yet — re-run without --no-packages"
		return
	fi

	if [ "${SHELL:-}" = "$fish_bin" ]; then
		skip "already fish"
		return
	fi

	# No terminal to ask on — piped, CI, or `bash install.sh < /dev/null`.
	# Never change a login shell without being able to ask.
	if ! { true < /dev/tty; } 2>/dev/null; then
		skip "not an interactive terminal — leaving ${SHELL:-unknown} alone"
		return
	fi

	# Asked rather than assumed: changing someone's login shell without
	# telling them is a good way to make them think their machine is broken.
	printf '   Make fish (%s) your login shell? [y/N] ' "$fish_bin"
	read -r reply < /dev/tty || reply=n

	case "$reply" in
		[Yy]*)
			run chsh -s "$fish_bin"
			ok "login shell set to fish (takes effect at next login)"
			;;
		*)
			skip "left as ${SHELL:-unknown}"
			;;
	esac
}


# ── Uninstall ─────────────────────────────────────────────────────────────

uninstall() {
	step "Removing Dawn's symlinks"

	for name in "${LINKS[@]}"; do
		local dst="$CONFIG_DST/$name"

		# Only ever remove a link this installer could have made. A real
		# directory at that path is someone else's config, not ours.
		if [ -L "$dst" ] && [[ "$(readlink -f "$dst")" == "$CONFIG_SRC"/* ]]; then
			run rm "$dst"
			ok "unlinked $name"
		else
			skip "$name (not a Dawn link)"
		fi
	done

	step "Restoring backups"

	local latest
	latest="$(find "$HOME/.dawn-backup" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"

	if [ -z "$latest" ]; then
		skip "no backups found in ~/.dawn-backup"
	else
		say "restoring from $latest"
		for item in "$latest"/*; do
			[ -e "$item" ] || continue
			local dst="$CONFIG_DST/$(basename "$item")"
			if [ -e "$dst" ]; then
				warn "$(basename "$item") not restored — something is already at $dst"
			else
				run mv "$item" "$dst"
				ok "restored $(basename "$item")"
			fi
		done
	fi

	cat <<-EOF

	  Dawn's config links are gone. Packages were NOT removed — they are
	  ordinary Arch packages and removing them is your call:

	      sudo pacman -Rns \$(awk '!/^[[:space:]]*#/ && NF {print \$1}' $MANIFEST)

	  If you switched to dawn-greet, switch back separately:

	      sudo $DAWN/config/greetd/install.sh --revert

	EOF
}


# ── Main ──────────────────────────────────────────────────────────────────

main() {
	printf '\n\033[1;37m  dawn\033[0m — where your system comes to life\n'
	[ "$DRY_RUN" -eq 1 ] && printf '\033[33m  dry run: nothing will be changed\033[0m\n'

	preflight

	if [ "$ACTION" = "uninstall" ]; then
		uninstall
		return
	fi

	install_packages
	link_configs
	seed_locals
	setup_wallpapers
	set_login_shell

	cat <<-EOF

	  ─────────────────────────────────────────────────────────────────────

	  Dawn is installed. Log out and back in, or start Hyprland from a TTY.

	  Two things are deliberately left to you:

	    The login screen.  dawn-greet replaces your display manager. It has
	                       its own installer, which never stops your current
	                       session and can be reverted in one command:

	                           sudo $DAWN/config/greetd/install.sh

	    Your hardware.     Monitor modes, GPU driver hints and keyboard
	                       backlight belong in the gitignored override files,
	                       already seeded for you:

	                           ~/.config/hypr/modules/local.lua
	                           ~/.config/fish/local.fish

	  Keybindings:  ~/.config/quickshell/dawn-island/KEYMAP.md

	  ─────────────────────────────────────────────────────────────────────

	EOF
}

main
