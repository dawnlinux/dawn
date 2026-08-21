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

# ── SEED strategy ─────────────────────────────────────────────────────────

@test "seed copies the override examples on a fresh install" {
    echo '-- lua example'   > "$DAWN_SHARE/examples/local.lua"
    echo '# fish example'   > "$DAWN_SHARE/examples/local.fish"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -f "$XDG_CONFIG_HOME/dawn/local.lua" ]
    [ -f "$XDG_CONFIG_HOME/dawn/local.fish" ]
    [ ! -L "$XDG_CONFIG_HOME/dawn/local.lua" ]
}

@test "seed never overwrites an existing override" {
    echo '-- lua example' > "$DAWN_SHARE/examples/local.lua"
    mkdir -p "$XDG_CONFIG_HOME/dawn"
    echo '-- MINE' > "$XDG_CONFIG_HOME/dawn/local.lua"

    "$DAWN" link
    [ "$(cat "$XDG_CONFIG_HOME/dawn/local.lua")" = "-- MINE" ]
}

@test "lazy-lock.json is seeded as a real file, not a symlink" {
    mkdir -p "$DAWN_SHARE/config/nvim"
    echo 'return {}'   > "$DAWN_SHARE/config/nvim/init.lua"
    echo '{"a":"b"}'   > "$DAWN_SHARE/config/nvim/lazy-lock.json"

    run "$DAWN" link
    [ -f "$XDG_CONFIG_HOME/nvim/lazy-lock.json" ]
    [ ! -L "$XDG_CONFIG_HOME/nvim/lazy-lock.json" ]

    # It must be writable — this is the entire reason it is seeded.
    echo '{"c":"d"}' > "$XDG_CONFIG_HOME/nvim/lazy-lock.json"
    [ "$(cat "$XDG_CONFIG_HOME/nvim/lazy-lock.json")" = '{"c":"d"}' ]
}

# ── dev / status / unlink ─────────────────────────────────────────────────

@test "dev points the links at a checkout" {
    mkdir -p "$TESTDIR/checkout/config/kitty"
    echo 'font_size 99' > "$TESTDIR/checkout/config/kitty/kitty.conf"

    run "$DAWN" dev "$TESTDIR/checkout"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" = "font_size 99" ]
}

@test "dev rejects a path with no config directory" {
    mkdir -p "$TESTDIR/not-a-checkout"
    run "$DAWN" dev "$TESTDIR/not-a-checkout"
    [ "$status" -ne 0 ]
    [[ "$output" == *"config"* ]]
}

@test "status reports package mode after link" {
    "$DAWN" link
    run "$DAWN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"package"* ]]
    [[ "$output" == *"$DAWN_SHARE/config"* ]]
}

@test "status reports dev mode after dev" {
    mkdir -p "$TESTDIR/checkout/config/kitty"
    echo 'x' > "$TESTDIR/checkout/config/kitty/kitty.conf"
    "$DAWN" dev "$TESTDIR/checkout"

    run "$DAWN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"dev"* ]]
    [[ "$output" == *"$TESTDIR/checkout/config"* ]]
}

@test "status surfaces a recorded local.lua error" {
    "$DAWN" link
    mkdir -p "$XDG_CONFIG_HOME/dawn"
    echo 'local.lua could not be read: boom' > "$XDG_CONFIG_HOME/dawn/last-error"

    run "$DAWN" status
    [[ "$output" == *"boom"* ]]
}

@test "unlink removes Dawn's links" {
    "$DAWN" link
    [ -L "$XDG_CONFIG_HOME/hypr" ]

    run "$DAWN" unlink
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_CONFIG_HOME/hypr" ]
}

@test "unlink restores a backup byte-for-byte" {
    mkdir -p "$XDG_CONFIG_HOME/kitty"
    echo "mine" > "$XDG_CONFIG_HOME/kitty/kitty.conf"

    "$DAWN" link
    "$DAWN" unlink

    [ -d "$XDG_CONFIG_HOME/kitty" ]
    [ ! -L "$XDG_CONFIG_HOME/kitty" ]
    [ "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" = "mine" ]
}

@test "unlink leaves user overrides alone" {
    echo '-- lua example' > "$DAWN_SHARE/examples/local.lua"
    "$DAWN" link
    "$DAWN" unlink
    [ -f "$XDG_CONFIG_HOME/dawn/local.lua" ]
}

@test "unlink does not touch a foreign symlink" {
    mkdir -p "$TESTDIR/elsewhere"
    "$DAWN" link
    rm "$XDG_CONFIG_HOME/rofi"
    ln -s "$TESTDIR/elsewhere" "$XDG_CONFIG_HOME/rofi"

    "$DAWN" unlink
    [ -L "$XDG_CONFIG_HOME/rofi" ]
    [ "$(readlink -f "$XDG_CONFIG_HOME/rofi")" = "$(readlink -f "$TESTDIR/elsewhere")" ]
}
