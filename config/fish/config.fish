#############################
####  DAWN — FISH SHELL  ####
#############################
#
# Shipped defaults only. Anything specific to YOUR machine — personal aliases,
# project paths, API keys, language version managers — belongs in
# `local.fish` next to this file, which is gitignored and sourced at the end.
#
# Rule of thumb: if it would not make sense on a stranger's fresh Dawn install,
# it goes in local.fish.

if status is-interactive
    # No "Welcome to fish" banner. dawn-greet already introduced itself.
    set fish_greeting
end

# ── Prompt ────────────────────────────────────────────────────────────────
#
# starship, configured by ../starship.toml.
if type -q starship
    starship init fish | source
end

# ── PATH ──────────────────────────────────────────────────────────────────
#
# fish_add_path is idempotent and prepends only if the entry is not already
# there, so re-sourcing this file cannot grow PATH the way repeated
# `set -gx PATH ...` lines do. Each is guarded on the directory existing so a
# machine without cargo or npm does not carry a dead PATH entry.
for dir in \
    $HOME/.local/bin \
    $HOME/.cargo/bin \
    $HOME/.npm-global/bin \
    $HOME/.config/composer/vendor/bin

    test -d $dir; and fish_add_path --path $dir
end

# ── Aliases ───────────────────────────────────────────────────────────────

# System
alias ll "ls -la"
alias ii "sudo pacman -S"
alias yy "yay -S"

# Editor. `nvm .` opens the current directory as the project root.
alias nvm "nvim ."

# Reload this file in place. Note this shadows the `fish` binary; use
# `command fish` if you want an actual subshell.
alias fish "source $HOME/.config/fish/config.fish"

# Media
alias yt "yt-dlp"
alias play "ffplay"

# Fetch
alias ff "fastfetch"

# ── Machine-local ─────────────────────────────────────────────────────────
#
# Sourced last so it can override anything above. See local.fish.example.
if test -f $HOME/.config/fish/local.fish
    source $HOME/.config/fish/local.fish
end
