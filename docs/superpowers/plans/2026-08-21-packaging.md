# Dawn Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Dawn as three signed pacman packages served from a GitHub Pages repository, so `pacman -Syu` updates the desktop.

**Architecture:** A split PKGBUILD (`pkgbase=dawn`) installs the config tree to `/usr/share/dawn/config` and a `dawn` CLI to `/usr/bin/dawn`. The CLI symlinks that tree into `~/.config` using three strategies, because some applications write into their own config directory and cannot live under a read-only symlink. User overrides move to `~/.config/dawn/`, outside every symlink, so pacman never touches them.

**Tech Stack:** bash (CLI and installer), bats (tests), makepkg/repo-add (packaging), GitHub Actions (release), GPG (signing), Rust/cargo (typist only).

**Spec:** `docs/superpowers/specs/2026-08-21-packaging-design.md`

## Global Constraints

Every task's requirements implicitly include these. Values are copied verbatim from the spec.

- **No AUR dependencies.** Every runtime dependency must exist in the official Arch repositories. A feature requiring an AUR package does not ship in core.
- **`install/packages.txt` is the single source of truth** for what Dawn depends on. The PKGBUILD carries an explicit `depends=()`; a check script fails the build on drift.
- **Nothing is ever deleted.** A real file or directory occupying a link target is moved to `~/.dawn-backup/<timestamp>/`, never removed.
- **The CLI never touches a link it did not create.** It verifies a symlink resolves under the expected source root before modifying it.
- **Shipped config is read-only.** User overrides live only in `~/.config/dawn/`.
- **Missing override is normal; broken override is loud.** A fresh install has no `~/.config/dawn/local.lua` and must still boot to a desktop.
- **All three packages share one `pkgver`**, derived from the git tag. A split PKGBUILD cannot version its packages independently.
- **`arch=('x86_64')`** only. `dawn` and `dawn-config` are `any`; `dawn-typist` is `x86_64`.
- **`license=('MIT')`**, installed to `/usr/share/licenses/<pkgname>/LICENSE`.
- **`SigLevel = Required DatabaseOptional`.** Every package is GPG-signed.
- **The CLI must be interpreted, not compiled.** `dawn-config` is `arch=any`; a compiled binary would forbid that.
- **`DAWN_SHARE` must be overridable by environment variable** in the CLI. This is what makes it testable without touching the real `/usr/share`.

---

## File Structure

| File | Responsibility |
|---|---|
| `LICENSE` | MIT text; required by `license=()` |
| `examples/local.lua` | seed source for `~/.config/dawn/local.lua` |
| `examples/local.fish` | seed source for `~/.config/dawn/local.fish` |
| `packaging/dawn` | the CLI — owns all linking |
| `packaging/PKGBUILD` | builds the three packages |
| `packaging/check-depends.sh` | fails the build if PKGBUILD drifts from the manifest |
| `packaging/test-install.sh` | end-to-end install in a systemd-nspawn container |
| `tests/dawn.bats` | CLI behaviour tests against a fake `$HOME` |
| `.github/workflows/release.yml` | build, sign, publish on tag |
| `install.sh` | reduced to a bootstrap |
| `config/hypr/hyprland.lua` | loads override by absolute path |
| `config/fish/config.fish` | sources override from new location |

---

### Task 1: MIT license

**Files:**
- Create: `LICENSE`

**Interfaces:**
- Consumes: nothing
- Produces: `LICENSE` at repo root, referenced by all three `package_*()` functions in Task 8

- [ ] **Step 1: Write the license**

```bash
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 jhayonline

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

- [ ] **Step 2: Verify it is exactly 21 lines and names the right year and holder**

Run: `wc -l LICENSE && head -3 LICENSE`
Expected: `21 LICENSE` and `Copyright (c) 2026 jhayonline`

- [ ] **Step 3: Add a license line to the README**

Append to `README.md`, immediately before the final `<div align="center">` footer block:

```markdown
## License

MIT. See [LICENSE](LICENSE).
```

- [ ] **Step 4: Commit**

```bash
git add LICENSE README.md
git commit -m "docs: add MIT license"
```

---

### Task 2: Relocate local overrides to `~/.config/dawn/`

Shipped config becomes root-owned in Task 8, so `local.lua` cannot stay in `config/hypr/modules/`. This task moves it before anything depends on the old location.

**Files:**
- Create: `examples/local.lua` (moved from `config/hypr/modules/local.lua.example`)
- Create: `examples/local.fish` (moved from `config/fish/local.fish.example`)
- Modify: `config/hypr/hyprland.lua`
- Modify: `config/fish/config.fish`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: `examples/local.lua` and `examples/local.fish`, consumed as SEED sources by Task 5; `~/.config/dawn/` as the override directory read by `hyprland.lua` and `config.fish`

- [ ] **Step 1: Move the example files**

```bash
mkdir -p examples
git mv config/hypr/modules/local.lua.example examples/local.lua
git mv config/fish/local.fish.example examples/local.fish
```

- [ ] **Step 2: Fix the copy instructions inside both examples**

In `examples/local.lua`, replace the copy instruction block:

```lua
--  Copy this file to `~/.config/dawn/local.lua` and edit it:
--
--      mkdir -p ~/.config/dawn
--      cp /usr/share/dawn/examples/local.lua ~/.config/dawn/local.lua
--
--  `dawn link` does this for you on a fresh install, and never overwrites an
--  existing file. ~/.config/dawn/ sits outside every symlink Dawn creates, so
--  pacman never touches it and `git pull` can never conflict with it.
```

In `examples/local.fish`, replace the corresponding block:

```fish
# Copy this file to `~/.config/dawn/local.fish` and edit it:
#
#     mkdir -p ~/.config/dawn
#     cp /usr/share/dawn/examples/local.fish ~/.config/dawn/local.fish
#
# `dawn link` does this for you on a fresh install, and never overwrites an
# existing file. Sourced at the very end of config.fish, so anything here wins.
```

- [ ] **Step 3: Change `hyprland.lua` to load by absolute path**

Replace the entire `-- ── Machine-local overrides ──` block at the end of `config/hypr/hyprland.lua` with:

```lua
-- ── Machine-local overrides ──────────────────────────────────────────────
--
-- `~/.config/dawn/local.lua` is where anything true of YOUR hardware and no
-- one else's belongs: monitor modes, GPU driver hints, vendor-specific device
-- names, per-host keybinds.
--
-- It lives outside ~/.config/hypr on purpose. Dawn's shipped config is owned
-- by pacman and read-only, so an override cannot sit beside the files it
-- overrides. ~/.config/dawn/ is the one directory Dawn never writes to after
-- seeding it.
--
-- Loaded last so it can override every module above. loadfile() rather than
-- require() because the file is outside package.path and stretching that to
-- reach an absolute home directory is worse than just reading the file.
--
-- Start from /usr/share/dawn/examples/local.lua.
local override = os.getenv("HOME") .. "/.config/dawn/local.lua"
local chunk, load_err = loadfile(override)

if chunk then
	-- The file exists and parsed. If it THROWS, say so — a desktop that
	-- quietly ignores your config has no visible cause.
	local ok, run_err = pcall(chunk)
	if not ok then
		print("dawn: ~/.config/dawn/local.lua failed -- " .. tostring(run_err))
	end
elseif load_err and not tostring(load_err):find("No such file", 1, true) then
	-- Exists but could not be read or parsed — a syntax error, or bad
	-- permissions. Missing is the normal case and stays silent.
	print("dawn: ~/.config/dawn/local.lua could not be read -- " .. tostring(load_err))
end
```

- [ ] **Step 4: Change `config.fish` to source the new path**

Replace the `# ── Machine-local ──` block at the end of `config/fish/config.fish` with:

```fish
# ── Machine-local ─────────────────────────────────────────────────────────
#
# Sourced last so it can override anything above. Lives in ~/.config/dawn/
# rather than beside this file because Dawn's shipped config is owned by
# pacman and read-only. See /usr/share/dawn/examples/local.fish.
if test -f $HOME/.config/dawn/local.fish
    source $HOME/.config/dawn/local.fish
end
```

- [ ] **Step 5: Update `.gitignore`**

Replace the machine-local overrides block with:

```gitignore
# ── Machine-local overrides ───────────────────────────────────────────────
#
# Overrides now live in ~/.config/dawn/, outside this repository entirely, so
# there is nothing here to ignore. Templates are committed under examples/.

# fish rewrites this at runtime to store universal variables, and it bakes in
# absolute paths. Tracking it means churn on every `set -U` and a broken PATH
# on anyone else's machine. PATH is set explicitly in config.fish instead.
/config/fish/fish_variables
```

- [ ] **Step 6: Migrate your own overrides to the new location**

```bash
mkdir -p ~/.config/dawn
[ -f config/hypr/modules/local.lua ] && mv config/hypr/modules/local.lua ~/.config/dawn/local.lua
[ -f config/fish/local.fish ]        && mv config/fish/local.fish        ~/.config/dawn/local.fish
ls -la ~/.config/dawn/
```
Expected: both `local.lua` and `local.fish` present.

- [ ] **Step 7: Verify the desktop still loads both overrides**

```bash
luac -p config/hypr/hyprland.lua
fish -n config/fish/config.fish
hyprctl reload
hyprctl binds | grep -c XF86KbdBrightness
hyprctl rollinglog | grep '^dawn:' || echo "no override errors"
```
Expected: `luac`/`fish -n` silent, `hyprctl reload` prints `ok`, the bind count is `2` (proving `~/.config/dawn/local.lua` was loaded), and no `dawn:` lines.

- [ ] **Step 8: Verify a BROKEN override is reported**

Hyprland's Lua config has no `hl.notify`, and `print()` from it reaches
neither `hyprland.log` nor `hyprctl rollinglog` — both verified by probe. So
the loader records failures to `~/.config/dawn/last-error` and additionally
fires `notify-send`. The file is the reliable channel; the notification is
best-effort, because at boot no notification daemon is running yet.

```bash
# syntax error branch
cp ~/.config/dawn/local.lua /tmp/local.lua.bak
echo 'this is not valid lua ===' >> ~/.config/dawn/local.lua
hyprctl reload >/dev/null
cat ~/.config/dawn/last-error

# runtime error branch
mv /tmp/local.lua.bak ~/.config/dawn/local.lua
cp ~/.config/dawn/local.lua /tmp/local.lua.bak
echo 'error("deliberate runtime failure")' >> ~/.config/dawn/local.lua
hyprctl reload >/dev/null
cat ~/.config/dawn/last-error

# restore; the error file must self-clear
mv /tmp/local.lua.bak ~/.config/dawn/local.lua
hyprctl reload >/dev/null
ls ~/.config/dawn/last-error
```
Expected: `... could not be read: <file>:N: syntax error near 'is'`, then
`... failed: <file>:N: deliberate runtime failure`, then `No such file` once
the healthy config is restored.

- [ ] **Step 9: Commit**

```bash
git add -A examples config/hypr/hyprland.lua config/fish/config.fish .gitignore
git commit -m "feat: move local overrides to ~/.config/dawn"
```

---

### Task 3: CLI skeleton, test harness and the DIR strategy

**Files:**
- Create: `packaging/dawn`
- Create: `tests/dawn.bats`

**Interfaces:**
- Consumes: `examples/` from Task 2
- Produces: `packaging/dawn` exposing `DAWN_SHARE` (env-overridable, default `/usr/share/dawn`), and the internal functions `link_entry <src> <dst>`, `back_up <path>`, `is_ours <path>`, `strategy_dir <app>`. Tasks 4–6 add `strategy_link` and `strategy_seed` alongside them.

- [ ] **Step 1: Install the dev tooling**

```bash
sudo pacman -S --needed bats shellcheck namcap
```

- [ ] **Step 2: Write the failing test**

Create `tests/dawn.bats`:

```bash
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats tests/dawn.bats`
Expected: all 5 tests FAIL — `packaging/dawn` does not exist yet.

- [ ] **Step 4: Write the CLI**

Create `packaging/dawn` with mode 755:

```bash
#!/usr/bin/env bash
#
# ==========================================================================
#  dawn — link manager for the Dawn desktop
# ==========================================================================
#
#      dawn link              point ~/.config at /usr/share/dawn/config
#      dawn dev <repo>        point it at a checkout instead
#      dawn status            current mode, source path, stale links
#      dawn unlink            remove Dawn's links, restore backups
#
# ── Why a link manager exists at all ──────────────────────────────────────
#
# Dawn's configuration is owned by pacman and installed read-only under
# /usr/share/dawn/config. Symlinking it into ~/.config is what makes
# `pacman -Syu` update the running desktop with no merge step and no
# migration scripts.
#
# ── Why there are three strategies ────────────────────────────────────────
#
# Some applications WRITE INTO their own configuration directory:
#
#     fish        fish_variables, on every `set -U`
#     nvim        lazy-lock.json, on every :Lazy update
#     quickshell  .qmlls.ini
#
# Symlinking those directories to a read-only location breaks them. So each
# application declares how it is linked:
#
#     DIR   symlink the whole entry (directory or file)
#     LINK  create a real directory; symlink only the entries Dawn owns,
#           leaving the application free to write its own state beside them
#     SEED  copy once if absent, never overwrite
#
# ── Safety ────────────────────────────────────────────────────────────────
#
# Nothing is ever deleted. A real file or directory occupying a link target
# is MOVED to ~/.dawn-backup/<timestamp>/. A symlink that does not resolve
# under the current source root is never touched.
# ==========================================================================

set -euo pipefail

# DAWN_SHARE is overridable so the test suite can run against a throwaway
# tree. Nothing else in this script may assume an absolute location.
DAWN_SHARE="${DAWN_SHARE:-/usr/share/dawn}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OVERRIDES="$CONFIG_HOME/dawn"
STATE="$OVERRIDES/source"
BACKUP_ROOT="$HOME/.dawn-backup"

# Populated by resolve_source() before any linking happens.
SOURCE=""
BACKUP=""

# ── Strategy tables ───────────────────────────────────────────────────────
#
# Every entry Dawn links, and how. An application absent from here is not
# linked at all — greetd, for instance, installs to /etc by its own script
# because the greeter runs as a user that cannot read your home directory.

declare -A STRATEGY=(
	[hypr]=DIR
	[kitty]=DIR
	[rofi]=DIR
	[starship.toml]=DIR
	[fish]=LINK
	[nvim]=LINK
	[quickshell]=LINK
)

# For LINK applications: exactly which entries Dawn owns.
#
# Listed explicitly rather than globbed. Globbing would silently start
# linking any new file added upstream — including one the application expects
# to own — which is the bug this strategy exists to prevent.
declare -A ENTRIES=(
	[fish]="config.fish"
	[nvim]="init.lua lua dap.txt KEYBINDINGS.md README.md showcase"
	[quickshell]="dawn-island dawn-greet"
)

# ── Output ────────────────────────────────────────────────────────────────

ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '   \033[90m·\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*" >&2; }
step() { printf '\n\033[1;37m%s\033[0m\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────

# True if $1 is a symlink resolving under the current $SOURCE. This is the
# guard that stops the CLI from ever removing something it did not create.
is_ours() {
	local path="$1"
	[ -L "$path" ] || return 1
	case "$(readlink -f "$path")" in
		"$(readlink -f "$SOURCE")"/*) return 0 ;;
		"$(readlink -f "$SOURCE")")   return 0 ;;
		*) return 1 ;;
	esac
}

# Move whatever occupies $1 into this run's backup directory. Never deletes.
back_up() {
	local target="$1"
	[ -n "$BACKUP" ] || BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$BACKUP"
	mv "$target" "$BACKUP/$(basename "$target")"
	warn "existing $(basename "$target") moved to $BACKUP/"
}

# Symlink $1 -> $2, backing up whatever is in the way.
link_entry() {
	local src="$1" dst="$2"

	[ -e "$src" ] || { warn "nothing to link at $src"; return; }

	if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
		return 0    # already correct; touch nothing
	fi

	if [ -L "$dst" ]; then
		# A symlink elsewhere. Replacing it loses nothing, so no backup.
		warn "$(basename "$dst") pointed at $(readlink "$dst") — repointing"
		rm "$dst"
	elif [ -e "$dst" ]; then
		back_up "$dst"
	fi

	mkdir -p "$(dirname "$dst")"

	# -n matters: without it, `ln -s src dst` where dst is an existing
	# directory creates dst/src instead of replacing dst. That is the classic
	# dotfile-installer bug that produces ~/.config/fish/fish.
	ln -sfn "$src" "$dst"
}

# ── Strategies ────────────────────────────────────────────────────────────

strategy_dir() {
	local name="$1"
	link_entry "$SOURCE/$name" "$CONFIG_HOME/$name"
	ok "$name"
}

# ── Source resolution ─────────────────────────────────────────────────────

resolve_source() {
	if [ -f "$STATE" ]; then
		SOURCE="$(cat "$STATE")"
	else
		SOURCE="$DAWN_SHARE/config"
	fi
	[ -d "$SOURCE" ] || die "config source does not exist: $SOURCE"
}

record_source() {
	mkdir -p "$OVERRIDES"
	printf '%s\n' "$SOURCE" > "$STATE"
}

# ── Commands ──────────────────────────────────────────────────────────────

cmd_link() {
	SOURCE="$DAWN_SHARE/config"
	[ -d "$SOURCE" ] || die "config source does not exist: $SOURCE"
	record_source
	apply
}

apply() {
	step "Linking $SOURCE into $CONFIG_HOME"
	local name
	for name in "${!STRATEGY[@]}"; do
		case "${STRATEGY[$name]}" in
			DIR)  strategy_dir  "$name" ;;
			LINK) strategy_link "$name" ;;
		esac
	done
	seed_all
}

# Filled in by later tasks; defined here so `apply` is complete from the
# start and adding a strategy never means editing the dispatch loop.
strategy_link() { :; }
seed_all()      { :; }

main() {
	local cmd="${1:-}"
	case "$cmd" in
		link)   cmd_link ;;
		"")     die "usage: dawn {link|dev <repo>|status|unlink}" ;;
		*)      die "unknown command: $cmd" ;;
	esac
}

main "$@"
```

- [ ] **Step 5: Make it executable and run the tests**

```bash
chmod 755 packaging/dawn
bats tests/dawn.bats
```
Expected: all 5 tests PASS.

- [ ] **Step 6: Lint it**

Run: `shellcheck packaging/dawn`
Expected: no errors. Fix anything reported before committing.

- [ ] **Step 7: Commit**

```bash
git add packaging/dawn tests/dawn.bats
git commit -m "feat(cli): add dawn link with DIR strategy"
```

---

### Task 4: LINK strategy

**Files:**
- Modify: `packaging/dawn` (replace the `strategy_link() { :; }` stub)
- Modify: `tests/dawn.bats`

**Interfaces:**
- Consumes: `link_entry`, `SOURCE`, `CONFIG_HOME`, `ENTRIES` from Task 3
- Produces: `strategy_link <app>` — creates `$CONFIG_HOME/<app>` as a real directory and symlinks each entry in `${ENTRIES[<app>]}` into it

- [ ] **Step 1: Write the failing tests**

Append to `tests/dawn.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/dawn.bats`
Expected: the 5 new tests FAIL — `strategy_link` is still a no-op stub.

- [ ] **Step 3: Replace the stub**

In `packaging/dawn`, delete the line `strategy_link() { :; }` and add this next to `strategy_dir`:

```bash
# A real directory containing symlinks to the entries Dawn owns.
#
# Used where the application writes into its own config directory:
# fish writes fish_variables, nvim writes lazy-lock.json, quickshell writes
# .qmlls.ini. Symlinking the directory itself to a read-only location makes
# all three fail, so only the individual entries are linked and the directory
# stays writable.
strategy_link() {
	local name="$1"
	local dir="$CONFIG_HOME/$name"
	local linked=0 entry

	[ -d "$SOURCE/$name" ] || { warn "$name: no source directory"; return; }

	# If a previous run (or another tool) left a symlink here, it has to
	# become a real directory before anything can be written inside it.
	if [ -L "$dir" ]; then
		warn "$name was a symlink — replacing with a real directory"
		rm "$dir"
	fi
	mkdir -p "$dir"

	for entry in ${ENTRIES[$name]}; do
		# Silently skip entries this source does not carry, so the table can
		# list optional files without every install warning about them.
		[ -e "$SOURCE/$name/$entry" ] || continue
		link_entry "$SOURCE/$name/$entry" "$dir/$entry"
		linked=$((linked + 1))
	done

	ok "$name ($linked entries)"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/dawn.bats`
Expected: all 10 tests PASS.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck packaging/dawn
git add packaging/dawn tests/dawn.bats
git commit -m "feat(cli): add LINK strategy for apps that write their own config"
```

---

### Task 5: SEED strategy

**Files:**
- Modify: `packaging/dawn` (replace the `seed_all() { :; }` stub)
- Modify: `tests/dawn.bats`

**Interfaces:**
- Consumes: `DAWN_SHARE`, `OVERRIDES`, `CONFIG_HOME`, `ok`, `skip` from Task 3
- Produces: `seed_all()` — copies `$DAWN_SHARE/examples/local.lua` → `$OVERRIDES/local.lua`, `local.fish` → `$OVERRIDES/local.fish`, and `$SOURCE/nvim/lazy-lock.json` → `$CONFIG_HOME/nvim/lazy-lock.json`, each only when absent

- [ ] **Step 1: Write the failing tests**

Append to `tests/dawn.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/dawn.bats`
Expected: the 3 new tests FAIL — `seed_all` is still a no-op stub.

- [ ] **Step 3: Replace the stub**

In `packaging/dawn`, delete the line `seed_all()      { :; }` and add:

```bash
# Copy $1 to $2 if and only if $2 does not exist.
#
# SEED is for files Dawn ships an initial version of but the user or an
# application then OWNS. Symlinking them would point a writer at a read-only
# path; copying every time would destroy the user's edits. Copy-once is the
# only behaviour that is correct for both.
seed_one() {
	local src="$1" dst="$2" label="$3"

	[ -e "$src" ] || return 0

	if [ -e "$dst" ]; then
		skip "$label (already yours)"
		return 0
	fi

	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	chmod u+w "$dst"    # the source under /usr/share is mode 644 root-owned
	ok "$label (seeded)"
}

seed_all() {
	step "Seeding user-owned files"

	# The machine-local overrides. ~/.config/dawn/ is outside every symlink
	# Dawn creates, so pacman never touches what lands here.
	seed_one "$DAWN_SHARE/examples/local.lua"  "$OVERRIDES/local.lua"  "dawn/local.lua"
	seed_one "$DAWN_SHARE/examples/local.fish" "$OVERRIDES/local.fish" "dawn/local.fish"

	# lazy.nvim rewrites this on every :Lazy update. A symlink into
	# /usr/share would make that fail with a read-only filesystem error.
	seed_one "$SOURCE/nvim/lazy-lock.json" "$CONFIG_HOME/nvim/lazy-lock.json" "nvim/lazy-lock.json"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/dawn.bats`
Expected: all 13 tests PASS.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck packaging/dawn
git add packaging/dawn tests/dawn.bats
git commit -m "feat(cli): add SEED strategy for user-owned files"
```

---

### Task 6: `dev`, `status` and `unlink`

**Files:**
- Modify: `packaging/dawn`
- Modify: `tests/dawn.bats`

**Interfaces:**
- Consumes: `apply`, `is_ours`, `record_source`, `STATE`, `BACKUP_ROOT`, `STRATEGY`, `ENTRIES` from Tasks 3–5
- Produces: `dawn dev <repo>`, `dawn status`, `dawn unlink`, and `--help`

- [ ] **Step 1: Write the failing tests**

Append to `tests/dawn.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/dawn.bats`
Expected: the 8 new tests FAIL — `dev`, `status` and `unlink` are unknown commands.

- [ ] **Step 3: Add the commands**

In `packaging/dawn`, add before `main()`:

```bash
cmd_dev() {
	local repo="${1:-}"
	[ -n "$repo" ] || die "usage: dawn dev <repo>   (the checkout root, not its config/ directory)"

	# The argument is the checkout ROOT — the directory the user cloned —
	# because that is what they have in their head, and because the CLI can
	# read install/packages.txt from the same place.
	repo="$(cd "$repo" 2>/dev/null && pwd)" || die "no such directory: $1"
	[ -d "$repo/config" ] || die "$repo has no config/ directory — is it a Dawn checkout?"

	SOURCE="$repo/config"
	record_source
	apply

	printf '\n  Now in \033[1;37mdev\033[0m mode. Edits in %s take effect immediately.\n' "$repo"
	printf '  Run \033[1;37mdawn link\033[0m to go back to the packaged config.\n\n'
}

cmd_status() {
	resolve_source

	local mode="dev"
	[ "$SOURCE" = "$DAWN_SHARE/config" ] && mode="package"

	printf '\n  mode:   \033[1;37m%s\033[0m\n' "$mode"
	printf '  source: %s\n\n' "$SOURCE"

	# hyprland.lua records a broken local.lua here, because it has no other
	# working channel — no hl.notify, and print() reaches no log. Surfacing
	# it is the whole reason the file exists.
	if [ -s "$OVERRIDES/last-error" ]; then
		printf '   \033[31m✗\033[0m local.lua  %s\n\n' "$(cat "$OVERRIDES/last-error")"
	fi

	# Report every managed entry, so "I edited the repo and nothing changed"
	# always has a visible cause.
	local name
	for name in $(printf '%s\n' "${!STRATEGY[@]}" | sort); do
		local dst="$CONFIG_HOME/$name"
		if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
			printf '   \033[33m!\033[0m %-14s missing\n' "$name"
		elif [ "${STRATEGY[$name]}" = "LINK" ]; then
			printf '   \033[32m✓\033[0m %-14s %s entries\n' "$name" "$(find "$dst" -maxdepth 1 -type l 2>/dev/null | wc -l)"
		elif is_ours "$dst"; then
			printf '   \033[32m✓\033[0m %-14s linked\n' "$name"
		else
			printf '   \033[33m!\033[0m %-14s not ours (%s)\n' "$name" "$(readlink "$dst" 2>/dev/null || echo 'real file')"
		fi
	done
	printf '\n'
}

cmd_unlink() {
	resolve_source
	step "Removing Dawn's links"

	local name entry
	for name in $(printf '%s\n' "${!STRATEGY[@]}" | sort); do
		local dst="$CONFIG_HOME/$name"

		if [ "${STRATEGY[$name]}" = "LINK" ]; then
			# Remove only the entries Dawn linked, then the directory itself
			# if that emptied it. Anything the app wrote there stays.
			[ -d "$dst" ] || continue
			for entry in ${ENTRIES[$name]}; do
				is_ours "$dst/$entry" && rm "$dst/$entry"
			done
			rmdir "$dst" 2>/dev/null && ok "$name (removed, was empty)" \
				|| ok "$name (links removed, app state kept)"
		elif is_ours "$dst"; then
			rm "$dst"
			ok "$name"
		else
			skip "$name (not a Dawn link)"
		fi
	done

	step "Restoring backups"

	local latest
	latest="$(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"

	if [ -z "$latest" ]; then
		skip "no backups in $BACKUP_ROOT"
	else
		local item
		for item in "$latest"/*; do
			[ -e "$item" ] || continue
			local dst="$CONFIG_HOME/$(basename "$item")"
			if [ -e "$dst" ]; then
				warn "$(basename "$item") not restored — something is already at $dst"
			else
				mv "$item" "$dst"
				ok "restored $(basename "$item")"
			fi
		done
		rmdir "$latest" 2>/dev/null || true
	fi

	# ~/.config/dawn is deliberately left alone. Those are the user's own
	# overrides; uninstalling Dawn is not a reason to delete them.
	printf '\n  Your overrides in %s were left untouched.\n\n' "$OVERRIDES"
}

usage() {
	cat <<-EOF

	  dawn — link manager for the Dawn desktop

	      dawn link           point ~/.config at $DAWN_SHARE/config
	      dawn dev <repo>     point it at a checkout instead
	      dawn status         current mode, source path, and every link
	      dawn unlink         remove Dawn's links and restore backups

	  Machine-local overrides live in $OVERRIDES and are never
	  touched by any of these commands.

	EOF
}
```

Then replace `main()` with:

```bash
main() {
	local cmd="${1:-}"
	case "$cmd" in
		link)          cmd_link ;;
		dev)           shift; cmd_dev "$@" ;;
		status)        cmd_status ;;
		unlink)        cmd_unlink ;;
		-h|--help|"")  usage ;;
		*)             die "unknown command: $cmd (try --help)" ;;
	esac
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/dawn.bats`
Expected: all 21 tests PASS.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck packaging/dawn
git add packaging/dawn tests/dawn.bats
git commit -m "feat(cli): add dev, status and unlink commands"
```

---

### Task 7: Manifest drift check

**Files:**
- Create: `packaging/check-depends.sh`
- Create: `tests/depends.bats`

**Interfaces:**
- Consumes: `install/packages.txt`
- Produces: `packaging/check-depends.sh`, exiting non-zero on drift. Task 8's PKGBUILD must define `_dawn_depends=()` at top level for this to read.

- [ ] **Step 1: Write the failing test**

Create `tests/depends.bats`:

```bash
#!/usr/bin/env bats
#
# The package manifest and the PKGBUILD's depends array must agree. They are
# two files that encode the same fact, so something has to enforce it.

setup() {
    REPO="$BATS_TEST_DIRNAME/.."
    CHECK="$REPO/packaging/check-depends.sh"
}

@test "check passes when the PKGBUILD matches the manifest" {
    run "$CHECK"
    [ "$status" -eq 0 ]
}

@test "check fails when the manifest gains a package the PKGBUILD lacks" {
    cp "$REPO/install/packages.txt" "$BATS_TMPDIR/packages.bak"
    echo "cowsay   # deliberately not in the PKGBUILD" >> "$REPO/install/packages.txt"

    run "$CHECK"
    status_saved="$status"
    cp "$BATS_TMPDIR/packages.bak" "$REPO/install/packages.txt"

    [ "$status_saved" -ne 0 ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/depends.bats`
Expected: both FAIL — `packaging/check-depends.sh` does not exist.

- [ ] **Step 3: Write the check script**

Create `packaging/check-depends.sh` with mode 755:

```bash
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

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO/install/packages.txt"
PKGBUILD="$REPO/packaging/PKGBUILD"

[ -r "$MANIFEST" ] || { echo "missing $MANIFEST" >&2; exit 2; }
[ -r "$PKGBUILD" ] || { echo "missing $PKGBUILD" >&2; exit 2; }

manifest="$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$MANIFEST" | sort -u)"

# Source the PKGBUILD in a subshell purely to read _dawn_depends. Sourcing is
# safe here because this runs on our own file in CI, not on untrusted input.
pkgbuild="$(
	# shellcheck disable=SC1090
	source "$PKGBUILD" >/dev/null 2>&1
	printf '%s\n' "${_dawn_depends[@]}" | sort -u
)"

if [ "$manifest" = "$pkgbuild" ]; then
	echo "ok: PKGBUILD dependencies match install/packages.txt ($(echo "$manifest" | wc -l) packages)"
	exit 0
fi

echo "PKGBUILD dependencies have drifted from install/packages.txt" >&2
echo >&2
diff <(echo "$manifest") <(echo "$pkgbuild") \
	--label 'install/packages.txt' --label 'packaging/PKGBUILD' -u >&2 || true
exit 1
```

- [ ] **Step 4: Run to verify it still fails, for the right reason**

Run: `bats tests/depends.bats`
Expected: both FAIL with "missing .../packaging/PKGBUILD". The PKGBUILD arrives in Task 8; this ordering is intentional so the check exists before the thing it checks.

- [ ] **Step 5: Commit**

```bash
chmod 755 packaging/check-depends.sh
shellcheck packaging/check-depends.sh
git add packaging/check-depends.sh tests/depends.bats
git commit -m "feat(packaging): add manifest drift check"
```

---

### Task 8: The split PKGBUILD

**Files:**
- Create: `packaging/PKGBUILD`
- Create: `packaging/.gitignore`

**Interfaces:**
- Consumes: `LICENSE` (Task 1), `examples/` (Task 2), `packaging/dawn` (Tasks 3–6), `packaging/check-depends.sh` (Task 7)
- Produces: `dawn`, `dawn-config`, `dawn-typist` packages; the `_dawn_depends` array read by `check-depends.sh`

- [ ] **Step 1: Write the PKGBUILD**

Create `packaging/PKGBUILD`:

```bash
# Maintainer: jhayonline <jhaycodes999@gmail.com>
#
# Three packages from one build:
#
#   dawn          meta — pulls in the whole desktop
#   dawn-config   the config tree, the CLI, and the greetd integration
#   dawn-typist   the typing test
#
# All three share one pkgver. A split PKGBUILD cannot version its packages
# independently — pkgver belongs to pkgbase — so typist versions with Dawn.
# That is accepted: it ships as part of Dawn, and a separate PKGBUILD purely
# for an independent version number would duplicate the release pipeline.

pkgbase=dawn
pkgname=(dawn dawn-config dawn-typist)
pkgver=1.0.0
pkgrel=1
arch=('x86_64')
url='https://github.com/dawnlinux/dawn'
license=('MIT')
makedepends=('git' 'cargo')
source=("$pkgbase-$pkgver::git+https://github.com/dawnlinux/dawn.git#tag=v$pkgver")
sha256sums=('SKIP')

# The runtime dependency list, kept in lockstep with install/packages.txt by
# packaging/check-depends.sh.
#
# It cannot be generated FROM that file: makepkg parses depends=() to resolve
# dependencies before sources are fetched, so $srcdir does not exist yet.
_dawn_depends=(
	# Compositor and shell
	hyprland
	quickshell
	hyprlock
	xdg-desktop-portal-hyprland

	# Terminal, shell and editor
	kitty
	fish
	starship
	neovim

	# Desktop utilities
	rofi
	awww
	cliphist
	wl-clipboard
	wtype
	flameshot
	nautilus

	# Media pipeline
	pipewire
	pipewire-pulse
	wireplumber
	playerctl
	ffmpeg

	# Hardware control
	brightnessctl
	upower
	bluez
	bluez-utils
	networkmanager

	# Fonts
	inter-font
	ttf-jetbrains-mono-nerd
	ttf-firacode-nerd

	# Login screen
	greetd

	# Everyday
	firefox
	fastfetch
)

prepare() {
	cd "$pkgbase-$pkgver/tools/typist"
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/^host: //p')"
}

build() {
	cd "$pkgbase-$pkgver/tools/typist"
	export RUSTUP_TOOLCHAIN=stable
	export CARGO_TARGET_DIR=target
	cargo build --frozen --release --all-features
}

check() {
	cd "$pkgbase-$pkgver"
	# Fail the build, not the user's install, if the two dependency lists
	# have drifted apart.
	./packaging/check-depends.sh
}

package_dawn() {
	pkgdesc='Where your system comes to life — an Arch desktop on Hyprland and Quickshell'
	arch=('any')
	depends=('dawn-config' "${_dawn_depends[@]}")

	install -Dm644 "$pkgbase-$pkgver/LICENSE" \
		"$pkgdir/usr/share/licenses/dawn/LICENSE"
}

package_dawn-config() {
	pkgdesc='Dawn desktop configuration and the dawn link manager'
	arch=('any')
	depends=('bash')
	optdepends=('greetd: for the dawn-greet login screen')

	cd "$pkgbase-$pkgver"

	# The config tree. greetd is pulled out of it because it is never linked
	# into ~/.config — it installs to /etc by its own script, since the
	# greeter runs as a user that cannot read your home directory.
	install -d "$pkgdir/usr/share/dawn"
	cp -a config "$pkgdir/usr/share/dawn/config"
	rm -rf "$pkgdir/usr/share/dawn/config/greetd"
	cp -a config/greetd "$pkgdir/usr/share/dawn/greetd"

	# Seed sources for ~/.config/dawn.
	cp -a examples "$pkgdir/usr/share/dawn/examples"

	# Everything under /usr/share is read-only to the user by design; the CLI
	# chmods the copies it seeds into their home.
	find "$pkgdir/usr/share/dawn" -type d -exec chmod 755 {} +
	find "$pkgdir/usr/share/dawn" -type f -exec chmod 644 {} +
	chmod 755 "$pkgdir/usr/share/dawn/greetd/install.sh"
	chmod 755 "$pkgdir/usr/share/dawn/config/quickshell/dawn-island/launch.sh"

	install -Dm755 packaging/dawn "$pkgdir/usr/bin/dawn"
	install -Dm644 LICENSE "$pkgdir/usr/share/licenses/dawn-config/LICENSE"
}

package_dawn-typist() {
	pkgdesc='A minimal typing test for Wayland'
	depends=('gcc-libs' 'glibc')

	cd "$pkgbase-$pkgver"
	install -Dm755 tools/typist/target/release/typist "$pkgdir/usr/bin/typist"
	install -Dm644 LICENSE "$pkgdir/usr/share/licenses/dawn-typist/LICENSE"
}
```

- [ ] **Step 2: Ignore build output**

Create `packaging/.gitignore`:

```gitignore
# makepkg working directories and output
src/
pkg/
*.pkg.tar.zst
*.pkg.tar.zst.sig
dawn-*/
```

- [ ] **Step 3: Verify the drift check now passes**

```bash
./packaging/check-depends.sh
bats tests/depends.bats
```
Expected: `ok: PKGBUILD dependencies match install/packages.txt (31 packages)`, and both bats tests PASS.

- [ ] **Step 4: Verify the PKGBUILD parses and reports the right metadata**

```bash
cd packaging && makepkg --printsrcinfo | head -20
```
Expected: `pkgbase = dawn`, `pkgver = 1.0.0`, and three `pkgname =` lines.

- [ ] **Step 5: Lint the PKGBUILD**

```bash
cd packaging && namcap PKGBUILD
```
Expected: no errors. Warnings about the `git+` source are normal.

- [ ] **Step 6: Commit**

```bash
git add packaging/PKGBUILD packaging/.gitignore
git commit -m "feat(packaging): add split PKGBUILD for dawn, dawn-config and dawn-typist"
```

---

### Task 9: Reduce `install.sh` to a bootstrap

**Files:**
- Modify: `install.sh` (full rewrite)

**Interfaces:**
- Consumes: `packaging/dawn` — all linking, backup and seeding logic now lives there
- Produces: `install.sh` that adds the repo, imports the key, installs `dawn`, and calls `dawn link`

- [ ] **Step 1: Rewrite it**

Replace the entire contents of `install.sh`:

```bash
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

DAWN_KEY_ID='REPLACE_WITH_FINGERPRINT_FROM_TASK_10'
DAWN_KEY_URL='https://dawnlinux.github.io/repo/dawn.gpg'
DAWN_REPO_URL='https://dawnlinux.github.io/repo/$arch'

DRY_RUN=0

say()  { printf '\033[32m::\033[0m %s\n' "$*"; }
step() { printf '\n\033[1;37m%s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '   \033[90m·\033[0m %s\n' "$*"; }
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
		-h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^#[[:space:]]\?//'; exit 0 ;;
		*)         die "unknown argument: $1 (try --help)" ;;
	esac
	shift
done

preflight() {
	step "Checking this machine"
	[ "$(id -u)" -ne 0 ] || die "do not run this as root — it calls sudo itself"
	command -v pacman >/dev/null 2>&1 || die "pacman not found. Dawn is an Arch distribution."
	ok "Arch-based system"
}

import_key() {
	step "Importing the Dawn signing key"

	if sudo pacman-key --list-keys "$DAWN_KEY_ID" >/dev/null 2>&1; then
		skip "already imported"
		return
	fi

	# Fetched over HTTPS and then LOCALLY SIGNED, which is what actually
	# grants it trust on this machine. Without the lsign step pacman still
	# rejects packages signed by it.
	run sudo pacman-key --recv-keys "$DAWN_KEY_ID" \
		|| run bash -c "curl -fsSL '$DAWN_KEY_URL' | sudo pacman-key --add -"
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
	run sudo tee -a /etc/pacman.conf >/dev/null <<-EOF

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

	  ─────────────────────────────────────────────────────────────────────

	EOF
}

main
```

- [ ] **Step 2: Verify syntax and the dry-run path**

```bash
bash -n install.sh
shellcheck install.sh
./install.sh --dry-run < /dev/null
```
Expected: syntax clean; the dry run prints `would:` lines for the key import, repo addition, `pacman -Sy` and `dawn link`, and changes nothing. Confirm with `grep -c '^\[dawn\]' /etc/pacman.conf` returning `0`.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "refactor(install): reduce installer to a repository bootstrap"
```

---

### Task 10: Signing key and release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `packaging/README.md`
- Modify: `install.sh` (fill in the real fingerprint)

**Interfaces:**
- Consumes: `packaging/PKGBUILD` (Task 8)
- Produces: a tag-triggered workflow publishing signed packages to `dawnlinux/repo`, and a `packages` workflow artifact for the future ISO build

- [ ] **Step 1: Generate the signing key**

```bash
gpg --batch --full-generate-key <<'EOF'
Key-Type: RSA
Key-Length: 4096
Name-Real: Dawn Linux
Name-Email: themarathondev7@gmail.com
Name-Comment: Dawn package signing key
Expire-Date: 0
%no-protection
%commit
EOF
gpg --list-secret-keys --keyid-format=long "Dawn Linux"
```
Record the long key ID. **Do not commit the private key.**

- [ ] **Step 2: Export the key material**

```bash
mkdir -p /tmp/dawn-key
gpg --armor --export "Dawn Linux" > /tmp/dawn-key/dawn.gpg
gpg --armor --export-secret-keys "Dawn Linux" | base64 -w0 > /tmp/dawn-key/secret.b64
```

Add `secret.b64`'s contents as the repository secret `GPG_PRIVATE_KEY`:

```bash
gh secret set GPG_PRIVATE_KEY < /tmp/dawn-key/secret.b64 --repo dawnlinux/dawn
```

`dawn.gpg` is published to the `dawnlinux/repo` repository root so
`install.sh` can fetch it.

- [ ] **Step 3: Put the real fingerprint into `install.sh`**

```bash
KEYID="$(gpg --list-keys --with-colons 'Dawn Linux' | awk -F: '/^fpr/{print $10; exit}')"
sed -i "s/REPLACE_WITH_FINGERPRINT_FROM_TASK_10/$KEYID/" install.sh
grep DAWN_KEY_ID install.sh
```
Expected: the 40-character fingerprint, not the placeholder.

- [ ] **Step 4: Write the workflow**

Create `.github/workflows/release.yml`:

```yaml
# Build, sign and publish the Dawn packages.
#
# Triggered by pushing a tag, because pkgver derives from the tag — tagging
# is the only release action.
name: release

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: archlinux:base-devel
    steps:
      - name: Install build tooling
        run: pacman -Syu --noconfirm git rust bats shellcheck namcap sudo

      # makepkg refuses to run as root, so the build needs an ordinary user.
      - name: Create build user
        run: |
          useradd -m builder
          echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Test the CLI
        run: |
          chown -R builder:builder .
          sudo -u builder bats tests/dawn.bats
          sudo -u builder shellcheck packaging/dawn install.sh packaging/check-depends.sh

      - name: Build packages
        run: |
          cd packaging
          sudo -u builder makepkg --syncdeps --noconfirm --cleanbuild

      - name: Import the signing key
        env:
          GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
        run: echo "$GPG_PRIVATE_KEY" | base64 -d | gpg --batch --import

      - name: Sign every package
        run: |
          cd packaging
          for pkg in *.pkg.tar.zst; do
            gpg --batch --yes --detach-sign --no-armor "$pkg"
          done
          ls -la *.pkg.tar.zst*

      # Two consumers: the Pages repository below, and the installer ISO,
      # which bakes an OFFLINE pacman repo onto the image so `pacstrap`
      # never touches the network. Publishing the artifact keeps the ISO
      # build from having to rebuild everything itself.
      - name: Publish packages as an artifact
        uses: actions/upload-artifact@v4
        with:
          name: packages
          path: packaging/*.pkg.tar.zst*
          retention-days: 90

      - name: Check out the package repository
        uses: actions/checkout@v4
        with:
          repository: dawnlinux/repo
          token: ${{ secrets.REPO_PUSH_TOKEN }}
          path: pacman-repo

      - name: Update the database
        run: |
          mkdir -p pacman-repo/x86_64
          cp packaging/*.pkg.tar.zst* pacman-repo/x86_64/
          cd pacman-repo/x86_64
          repo-add --sign --key "$(gpg --list-keys --with-colons 'Dawn Linux' | awk -F: '/^fpr/{print $10; exit}')" \
            dawn.db.tar.gz ./*.pkg.tar.zst

      - name: Push
        run: |
          cd pacman-repo
          git config user.name  'dawn-release'
          git config user.email 'themarathondev7@gmail.com'
          git add -A
          git commit -m "release ${GITHUB_REF_NAME}"
          git push
```

- [ ] **Step 5: Document the release process**

Create `packaging/README.md`:

```markdown
# Packaging

Three packages are built from one `PKGBUILD`:

| Package | Arch | Contents |
|---|---|---|
| `dawn` | any | meta; depends on the whole desktop |
| `dawn-config` | any | `/usr/share/dawn/`, `/usr/bin/dawn` |
| `dawn-typist` | x86_64 | `/usr/bin/typist` |

## Releasing

Tagging is the only release action — `pkgver` derives from the tag.

```sh
git tag v1.0.1
git push origin v1.0.1
```

`.github/workflows/release.yml` then runs the tests, builds, signs, and
pushes to `dawnlinux/repo`, which GitHub Pages serves.

## Building locally

```sh
cd packaging
makepkg --syncdeps --cleanbuild
namcap ./*.pkg.tar.zst
pacman -Qlp ./dawn-config-*.pkg.tar.zst | head
```

Do **not** `pacman -U` the result on your development machine — installing
`dawn-config` overwrites the desktop you are developing on. Use
`packaging/test-install.sh`, which does it in a container.

## Dependencies

`install/packages.txt` is the single source of truth. `packaging/PKGBUILD`
carries an explicit `_dawn_depends=()` array because `makepkg` parses
`depends=()` before sources are fetched, so the manifest cannot be read at
build time. `packaging/check-depends.sh` runs in the PKGBUILD's `check()`
and fails the build if the two drift apart.
```

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/release.yml packaging/README.md install.sh
git commit -m "feat(packaging): add signed release workflow"
```

---

### Task 11: Container install test and README

**Files:**
- Create: `packaging/test-install.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above
- Produces: an end-to-end verification path that does not touch the development machine

- [ ] **Step 1: Write the container test**

Create `packaging/test-install.sh` with mode 755:

```bash
#!/usr/bin/env bash
#
# End-to-end install test, in a throwaway systemd-nspawn container.
#
# This exists because the one thing that cannot be tested on the development
# machine is installing dawn-config: it would overwrite the desktop being
# developed on. A container gets a real pacman, a real filesystem, and a real
# user, and can be deleted afterwards.
#
#     sudo ./packaging/test-install.sh
#
# Requires: arch-install-scripts, systemd-container

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${DAWN_TEST_ROOT:-/var/lib/machines/dawn-test}"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\033[32m::\033[0m %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || die "run this with sudo — it creates a container root"
command -v pacstrap        >/dev/null || die "need arch-install-scripts"
command -v systemd-nspawn  >/dev/null || die "need systemd-container"

ls "$REPO"/packaging/*.pkg.tar.zst >/dev/null 2>&1 \
	|| die "no packages built — run 'cd packaging && makepkg' first"

say "creating container root at $ROOT"
rm -rf "$ROOT"
mkdir -p "$ROOT"

# base only. The point is to prove the packages pull in what they claim to,
# so nothing the manifest needs may be preinstalled.
pacstrap -c "$ROOT" base

say "copying packages in"
mkdir -p "$ROOT/pkgs"
cp "$REPO"/packaging/*.pkg.tar.zst "$ROOT/pkgs/"

say "installing dawn inside the container"
systemd-nspawn -D "$ROOT" --pipe /bin/bash -euo pipefail <<'INNER'
	useradd -m -s /bin/bash tester
	pacman -Sy --noconfirm
	pacman -U --noconfirm /pkgs/*.pkg.tar.zst

	# The package must place these exactly where the CLI expects them.
	test -d /usr/share/dawn/config    || { echo "FAIL: no /usr/share/dawn/config"; exit 1; }
	test -d /usr/share/dawn/examples  || { echo "FAIL: no /usr/share/dawn/examples"; exit 1; }
	test -x /usr/bin/dawn             || { echo "FAIL: /usr/bin/dawn not executable"; exit 1; }
	test -x /usr/bin/typist           || { echo "FAIL: /usr/bin/typist not executable"; exit 1; }

	# Link as an ordinary user, which is how it is actually used.
	su - tester -c 'dawn link'
	su - tester -c 'dawn status'

	test -L /home/tester/.config/hypr             || { echo "FAIL: hypr not linked"; exit 1; }
	test -d /home/tester/.config/fish             || { echo "FAIL: fish should be a real dir"; exit 1; }
	test ! -L /home/tester/.config/fish           || { echo "FAIL: fish must not be a symlink"; exit 1; }
	test -L /home/tester/.config/fish/config.fish || { echo "FAIL: config.fish not linked"; exit 1; }
	test -f /home/tester/.config/dawn/local.lua   || { echo "FAIL: local.lua not seeded"; exit 1; }
	test ! -L /home/tester/.config/dawn/local.lua || { echo "FAIL: local.lua must be a real file"; exit 1; }

	# fish must be able to write its own state beside the linked config.
	su - tester -c 'echo "SETUVAR x:y" > ~/.config/fish/fish_variables' \
		|| { echo "FAIL: fish dir not writable"; exit 1; }

	su - tester -c 'dawn unlink'
	test ! -e /home/tester/.config/hypr           || { echo "FAIL: hypr still linked"; exit 1; }
	test -f /home/tester/.config/dawn/local.lua   || { echo "FAIL: unlink ate the overrides"; exit 1; }

	echo "ALL CONTAINER CHECKS PASSED"
INNER

say "cleaning up"
rm -rf "$ROOT"
say "done"
```

- [ ] **Step 2: Run it**

```bash
sudo pacman -S --needed arch-install-scripts
cd packaging && makepkg --syncdeps --cleanbuild && cd ..
sudo ./packaging/test-install.sh
```
Expected: `ALL CONTAINER CHECKS PASSED`, then `done`.

- [ ] **Step 3: Update the README install section**

In `README.md`, replace the entire `## Install` section with:

```markdown
## Install

Add the Dawn repository and install:

```sh
git clone https://github.com/dawnlinux/dawn
cd dawn
./install.sh
```

See exactly what it will do first with `./install.sh --dry-run`.

That script adds the `[dawn]` repository to `/etc/pacman.conf`, imports the
signing key, and runs `pacman -Sy dawn`. After that, **Dawn updates like
anything else on the system**:

```sh
sudo pacman -Syu
```

### Doing it by hand

```sh
sudo pacman-key --recv-keys <FINGERPRINT>
sudo pacman-key --lsign-key <FINGERPRINT>
```

```ini
# /etc/pacman.conf
[dawn]
SigLevel = Required DatabaseOptional
Server = https://dawnlinux.github.io/repo/$arch
```

```sh
sudo pacman -Sy dawn && dawn link
```

### The `dawn` command

| Command | Effect |
|---|---|
| `dawn link` | point `~/.config` at the packaged config |
| `dawn dev <repo>` | point it at a checkout instead, for hacking on Dawn |
| `dawn status` | which mode you are in, and every link |
| `dawn unlink` | remove Dawn's links and restore backups |

Nothing is ever deleted — anything occupying a link target is moved to
`~/.dawn-backup/<timestamp>/`.
```

Then in the **Making it yours** section, replace the file paths table with:

```markdown
| File | For |
|---|---|
| `~/.config/dawn/local.lua` | monitor modes, GPU driver hints, vendor keybinds, per-host autostart |
| `~/.config/dawn/local.fish` | personal aliases, extra `PATH` entries, secrets |

Both are seeded from `/usr/share/dawn/examples/` on first `dawn link` and
never overwritten afterwards. They live outside every symlink Dawn creates,
so `pacman -Syu` can never touch them.
```

- [ ] **Step 4: Verify no stale paths remain in the README**

```bash
grep -n "modules/local.lua\|config/fish/local.fish\|install/packages.txt" README.md
```
Expected: no hits for the first two. A reference to `install/packages.txt` is fine.

- [ ] **Step 5: Commit**

```bash
git add packaging/test-install.sh README.md
git commit -m "feat(packaging): add container install test, document pacman install"
```

---

## Self-Review

**Spec coverage**

| Spec section | Task |
|---|---|
| D1 symlink from `/usr/share/dawn/config` | 3, 4, 8 |
| D2 three packages, split PKGBUILD | 8 |
| D3 GitHub Pages hosting | 9, 10 |
| D4 overrides in `~/.config/dawn/` | 2, 5 |
| D5 GPG signing, `SigLevel = Required` | 9, 10 |
| Link strategies DIR / LINK / SEED | 3, 4, 5 |
| `dawn` CLI four commands | 3, 6 |
| Dependency manifest, drift check | 7, 8 |
| Versioning from git tag | 8, 10 |
| Release pipeline + ISO artifact | 10 |
| `install.sh` becomes a bootstrap | 9 |
| Error handling | 2 (loud override), 3 (backup, foreign symlink), 7 (drift) |
| Testing matrix | 3–6 (bats), 8 (namcap), 11 (container) |
| MIT license | 1 |

**Gap found and closed:** the spec's strategy table omits `starship.toml`, which
`install.sh` currently links. It is a file rather than a directory, so it is
handled by `DIR` (which symlinks any entry wholesale) and covered by a test in
Task 3, Step 2. The spec should be amended to list it.

**Placeholder scan:** one intentional placeholder — `DAWN_KEY_ID` in Task 9 is
written as `REPLACE_WITH_FINGERPRINT_FROM_TASK_10` and substituted by an
explicit command in Task 10, Step 3, which verifies the result. The fingerprint
does not exist until the key is generated, so it cannot be written earlier.

**Type consistency:** `link_entry`, `back_up`, `is_ours`, `resolve_source`,
`record_source`, `apply`, `seed_one`, `seed_all`, `strategy_dir`,
`strategy_link` are defined in Task 3 and used with identical names and
argument orders in Tasks 4–6. `_dawn_depends` is defined in Task 8's PKGBUILD
and read by Task 7's `check-depends.sh` under the same name. `DAWN_SHARE`,
`CONFIG_HOME`, `OVERRIDES`, `STATE`, `BACKUP_ROOT`, `SOURCE` and `BACKUP` are
declared once in Task 3 and referenced consistently thereafter.
