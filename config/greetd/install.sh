#!/usr/bin/env bash
#
# Replace SDDM with greetd running dawn-greet.
#
#     sudo ./install.sh            install and make greetd the default
#     sudo ./install.sh --revert   put SDDM back
#
# ── What this does not do ─────────────────────────────────────────────────
#
# It never stops SDDM. Switching display managers is disabling one unit and
# enabling another; the change lands at the next boot. Stopping SDDM now would
# kill the desktop you are running this from, including the terminal you would
# need to fix anything that went wrong.
#
# It never removes SDDM either. SDDM is the way back, and a way back has to
# still be installed to be one. `--revert` restores it in a single command.
#
# ── Why the wallpaper is copied ───────────────────────────────────────────
#
# The greeter runs as `greeter`, which cannot traverse a 0700 home directory,
# so it cannot read a wallpaper under ~/Pictures no matter what that file's own
# permissions say. The alternative to copying is opening your home directory to
# every local account, which is a much larger change than a login screen is
# worth. So the image is published to /var/lib/dawn instead and your home stays
# shut. dawn-island keeps that copy current every time you pick a wallpaper.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QML_SRC="$SRC/../quickshell/dawn-greet"

DEST=/etc/greetd
QML_DEST="$DEST/dawn-greet"
PUB=/var/lib/dawn

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
say()  { printf '\033[32m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] || die "run this with sudo"

LOGIN_USER="${SUDO_USER:-}"
[ -n "$LOGIN_USER" ] || die "could not tell who you are — run via sudo, not as root directly"
id "$LOGIN_USER" >/dev/null 2>&1 || die "no such user: $LOGIN_USER"

# ── Revert ────────────────────────────────────────────────────────────────

if [ "${1:-}" = "--revert" ]; then
    systemctl disable greetd >/dev/null 2>&1 || true
    systemctl enable sddm
    say "SDDM is the default again. greetd is disabled but still installed."
    say "Nothing has changed in the session you are in; reboot to land on SDDM."
    exit 0
fi

[ "${1:-}" = "" ] || die "unknown argument: $1 (expected nothing, or --revert)"

# ── Install ───────────────────────────────────────────────────────────────

say "installing greetd"
pacman -S --needed --noconfirm greetd

# The Arch package creates this through sysusers.d, but a greeter that cannot
# log in because the account it runs as is missing is a bad thing to discover
# at the login screen.
if ! id greeter >/dev/null 2>&1; then
    warn "the 'greeter' account was not created by the package; creating it"
    systemd-sysusers >/dev/null 2>&1 || useradd -r -M -s /usr/bin/nologin greeter
    id greeter >/dev/null 2>&1 || die "could not create the 'greeter' account"
fi

# ── The shell itself ──────────────────────────────────────────────────────
#
# Copied rather than symlinked: `greeter` cannot read /home/$LOGIN_USER, so a
# symlink into the repo would resolve to something it is not allowed to open.
# Re-run this script after editing the QML to push changes across.

[ -f "$QML_SRC/shell.qml" ] || die "no shell.qml under $QML_SRC"

say "installing dawn-greet to $QML_DEST"
install -d -m 0755 "$DEST" "$QML_DEST"
rm -f "$QML_DEST"/*.qml
install -m 0644 "$QML_SRC"/*.qml "$QML_DEST/"

say "installing greetd and compositor config"
install -m 0644 "$SRC/hyprland.conf" "$DEST/hyprland.conf"
sed "s|@LOGIN_USER@|$LOGIN_USER|g" "$SRC/config.toml" > "$DEST/config.toml"
chmod 0644 "$DEST/config.toml"

grep -q "DAWN_GREET_USER=$LOGIN_USER" "$DEST/config.toml" \
    || die "the @LOGIN_USER@ substitution did not take — refusing to continue"

# ── The wallpaper ─────────────────────────────────────────────────────────

say "creating $PUB"
install -d -o "$LOGIN_USER" -g "$LOGIN_USER" -m 0755 "$PUB"

publish_wallpaper() {
    local src="$1" ext
    [ -n "$src" ] && [ -r "$src" ] || return 1
    case "$src" in *.*) ext="${src##*.}" ;; *) ext=img ;; esac
    rm -f "$PUB"/current.*
    install -o "$LOGIN_USER" -g "$LOGIN_USER" -m 0644 "$src" "$PUB/current.$ext"
    printf '%s\n' "$PUB/current.$ext" > "$PUB/wallpaper"
    chown "$LOGIN_USER:$LOGIN_USER" "$PUB/wallpaper"
    chmod 0644 "$PUB/wallpaper"
    say "published wallpaper: $src → $PUB/current.$ext"
}

# Ask the running awww what is on screen, so the login screen has your
# wallpaper on the very first boot rather than only after you next change it.
# Best-effort by design: falling back to the aurora is not a failed install.
detect_wallpaper() {
    local uid rt sock
    uid="$(id -u "$LOGIN_USER")"
    rt="/run/user/$uid"
    [ -d "$rt" ] || return 1
    for sock in "$rt"/wayland-*; do
        [ -S "$sock" ] || continue
        runuser -u "$LOGIN_USER" -- env XDG_RUNTIME_DIR="$rt" \
            WAYLAND_DISPLAY="${sock##*/}" awww query 2>/dev/null \
            | sed -n 's/.*image: //p' | head -1 | grep . && return 0
    done
    return 1
}

if wp="$(detect_wallpaper)" && publish_wallpaper "$wp"; then
    :
else
    warn "could not work out your current wallpaper — the greeter will draw the"
    warn "aurora until dawn-island next publishes one (restarting it is enough)."
fi

# ── Switch ────────────────────────────────────────────────────────────────

say "making greetd the default"
systemctl disable sddm
systemctl enable greetd

cat <<EOF

  greetd is now the default. Nothing about your current session has changed.

  Test it WITHOUT rebooting — a reboot straight into an untested display
  manager is how people end up at a black screen with no terminal:

      Ctrl+Alt+F2, log in, then:
      sudo systemctl stop sddm && sudo systemctl start greetd

  Stopping SDDM ends this desktop session, so save your work first.

  If it does not come up, you are still at a TTY prompt. The way back:

      sudo $SRC/install.sh --revert
      sudo systemctl start sddm

  Why it failed will be in:  journalctl -u greetd -b

EOF
