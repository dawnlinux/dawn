#!/usr/bin/env bats
#
# Tests for the `dawn` CLI.
#
# Everything runs against a throwaway $HOME and a throwaway $DAWN_SHARE, so no
# test can touch the real desktop. That is the whole reason DAWN_SHARE is an
# environment variable rather than a constant.

setup() {
    TESTDIR="$(mktemp -d)"
    export HOME="$TESTDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export DAWN_SHARE="$TESTDIR/share"

    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$DAWN_SHARE/config/hypr/modules"
    mkdir -p "$DAWN_SHARE/config/kitty"
    mkdir -p "$DAWN_SHARE/config/rofi"
    mkdir -p "$DAWN_SHARE/examples"

    echo 'require("modules.binds")' > "$DAWN_SHARE/config/hypr/hyprland.lua"
    echo 'font_size 11.0'           > "$DAWN_SHARE/config/kitty/kitty.conf"
    echo '* { background: #000; }'  > "$DAWN_SHARE/config/rofi/config.rasi"
    echo 'add_newline = false'      > "$DAWN_SHARE/config/starship.toml"

    DAWN="$BATS_TEST_DIRNAME/../packaging/dawn"
}

teardown() {
    rm -rf "$TESTDIR"
}

# ── DIR strategy ──────────────────────────────────────────────────────────

@test "link creates a directory symlink for a DIR app" {
    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -L "$XDG_CONFIG_HOME/hypr" ]
    [ "$(readlink -f "$XDG_CONFIG_HOME/hypr")" = "$(readlink -f "$DAWN_SHARE/config/hypr")" ]
}

@test "link symlinks starship.toml, which is a file not a directory" {
    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -L "$XDG_CONFIG_HOME/starship.toml" ]
    [ "$(cat "$XDG_CONFIG_HOME/starship.toml")" = "add_newline = false" ]
}

@test "link is idempotent" {
    "$DAWN" link
    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -L "$XDG_CONFIG_HOME/hypr" ]
}

@test "link backs up a real directory instead of deleting it" {
    mkdir -p "$XDG_CONFIG_HOME/kitty"
    echo "mine" > "$XDG_CONFIG_HOME/kitty/kitty.conf"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -L "$XDG_CONFIG_HOME/kitty" ]

    # The original survives somewhere under ~/.dawn-backup
    found="$(find "$HOME/.dawn-backup" -name kitty.conf -type f | head -1)"
    [ -n "$found" ]
    [ "$(cat "$found")" = "mine" ]
}

@test "link replaces a foreign symlink without backing it up" {
    mkdir -p "$TESTDIR/elsewhere"
    ln -s "$TESTDIR/elsewhere" "$XDG_CONFIG_HOME/rofi"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$XDG_CONFIG_HOME/rofi")" = "$(readlink -f "$DAWN_SHARE/config/rofi")" ]
    [ ! -d "$HOME/.dawn-backup" ]
}

# ── LINK strategy ─────────────────────────────────────────────────────────

@test "LINK app gets a real directory, not a symlink" {
    mkdir -p "$DAWN_SHARE/config/fish"
    echo 'set fish_greeting' > "$DAWN_SHARE/config/fish/config.fish"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -d "$XDG_CONFIG_HOME/fish" ]
    [ ! -L "$XDG_CONFIG_HOME/fish" ]
}

@test "LINK app symlinks only the listed entries" {
    mkdir -p "$DAWN_SHARE/config/fish"
    echo 'set fish_greeting' > "$DAWN_SHARE/config/fish/config.fish"
    echo 'not ours'          > "$DAWN_SHARE/config/fish/stray.fish"

    run "$DAWN" link
    [ -L "$XDG_CONFIG_HOME/fish/config.fish" ]
    [ ! -e "$XDG_CONFIG_HOME/fish/stray.fish" ]
}

@test "LINK app leaves the directory writable for app state" {
    mkdir -p "$DAWN_SHARE/config/fish"
    echo 'set fish_greeting' > "$DAWN_SHARE/config/fish/config.fish"

    "$DAWN" link
    echo 'SETUVAR foo:bar' > "$XDG_CONFIG_HOME/fish/fish_variables"
    [ -f "$XDG_CONFIG_HOME/fish/fish_variables" ]
    [ ! -L "$XDG_CONFIG_HOME/fish/fish_variables" ]
}

@test "LINK app links subdirectories as well as files" {
    mkdir -p "$DAWN_SHARE/config/nvim/lua"
    echo 'return {}' > "$DAWN_SHARE/config/nvim/init.lua"
    echo 'return {}' > "$DAWN_SHARE/config/nvim/lua/x.lua"

    run "$DAWN" link
    [ -L "$XDG_CONFIG_HOME/nvim/init.lua" ]
    [ -L "$XDG_CONFIG_HOME/nvim/lua" ]
    [ "$(cat "$XDG_CONFIG_HOME/nvim/lua/x.lua")" = "return {}" ]
}

@test "LINK skips entries the source does not have" {
    mkdir -p "$DAWN_SHARE/config/quickshell/dawn-island"
    echo '// shell' > "$DAWN_SHARE/config/quickshell/dawn-island/shell.qml"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -L "$XDG_CONFIG_HOME/quickshell/dawn-island" ]
    [ ! -e "$XDG_CONFIG_HOME/quickshell/dawn-greet" ]
}
