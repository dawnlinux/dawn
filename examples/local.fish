###################################
####  DAWN — LOCAL FISH CONFIG  ####
###################################
#
# Copy this file to `~/.config/dawn/local.fish` and edit it:
#
#     mkdir -p ~/.config/dawn
#     cp /usr/share/dawn/examples/local.fish ~/.config/dawn/local.fish
#
# `dawn link` does this for you on a fresh install, and never overwrites an
# existing file. Sourced at the very end of config.fish, so anything here wins.
#
# It lives outside ~/.config/fish because Dawn's shipped config is owned by
# pacman and read-only — an override cannot sit beside what it overrides.

# ── Extra PATH entries ────────────────────────────────────────────────────
#
# fish_add_path is idempotent; the -d guard keeps dead entries out of PATH.
# test -d $HOME/.bun/bin; and fish_add_path --path $HOME/.bun/bin

# ── Personal aliases ──────────────────────────────────────────────────────
#
# alias gs "git status"
# alias dc "docker compose"

# ── Secrets ───────────────────────────────────────────────────────────────
#
# Prefer a secret manager, but if you must, this is the least-bad place —
# it never leaves the machine.
#
# set -gx SOME_API_KEY "..."
