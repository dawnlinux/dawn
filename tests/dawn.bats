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
