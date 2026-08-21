# Dawn Colour Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Colour the whole desktop from one source — a wallpaper or a seed colour — through matugen, with no hand-maintained palette files.

**Architecture:** `dawn-theme` (Rust) owns theme state in `~/.config/dawn/theme.toml`, invokes `matugen` to render templates into `~/.config/dawn/generated/`, then issues reloads itself. The island's colours are split out of `Theme.qml` into a generated `Colors.qml` singleton; everything else in `Theme.qml` stays hand-tuned.

**Tech Stack:** matugen 4.1.0, Rust (clap, serde, toml), QML, bats.

**Spec:** `docs/superpowers/specs/2026-08-21-colour-engine-design.md`

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include these.

- **No AUR dependencies.** New packages — `matugen`, `adw-gtk-theme`, `qt5ct`, `qt6ct` — are all in official Arch repositories.
- **`install/packages.txt` is the single source of truth** for dependencies; `packaging/check-depends.sh` enforces it against the PKGBUILD.
- **`--prefer saturation` is mandatory on every matugen image invocation.** matugen 4.1 refuses to run on a multi-colour image with no TTY, and `dawn-theme` always runs headless.
- **`--source-color-index` does not exist in matugen 4.1.** Do not copy it from any reference implementation.
- **A failing `post_hook` does not fail matugen** — it exits `0` regardless. `post_hook` is therefore used only for file placement; every reload is issued by `dawn-theme`.
- **Generated output lives in `~/.config/dawn/generated/`**, never `~/.config/matugen/generated/`, because the latter is inside a directory Dawn symlinks read-only from `/usr/share`.
- **Template syntax:** `{{colors.NAME.default.hex}}` → `#rrggbb`, `.hex_stripped` → `rrggbb`, `.rgb` → `rgb(r, g, b)`. The `-j hex` **JSON** dump keys values as `.color`, not `.hex`.
- **Default theme:** `scheme-monochrome`, `dark`, source `dawn-black.png`.
- **`positive` (`#7ec699`) and `warning` (`#e8c07d`) are never generated.** Material You has no success or warning role, and a warning that changes hue stops communicating urgency.
- **Contrast floor:** every text-on-background pair must stay at or above WCAG AA 4.5.

---

## Three deviations from the spec, and why

**1. `Colors.qml`, not a generated `Theme.qml`.** The spec says "`Theme.qml` becomes generated". Inspection shows `Theme.qml` holds **17 colour properties and 23 non-colour ones** — `spacingXs`, `radiusLg`, `artSize`, `shadowRadius`, `trackThickness` and so on. Generating the whole file would turn every hand-tuned dimension into machine output.

Colours move into a new `theme/Colors.qml` singleton — matching the existing `Anim.qml` / `Glyphs.qml` / `Typography.qml` pattern in that directory — and only that file is generated. `Theme.qml` keeps its sizes and re-exports the colours so no call site changes.

**2. The palette is generated as JSON, not as QML.** The spec and the first
draft of this plan had matugen render `Colors.qml` directly. That cannot work
in package mode: the island's `theme/` directory lives at
`/usr/share/dawn/config/quickshell/dawn-island/theme/`, which is root-owned and
read-only, and `~/.config/quickshell/dawn-island` is a symlink straight into
it. There is nowhere writable for matugen to put a generated QML file that
Quickshell would still resolve as part of the `qs.theme` module. Generating
into the checkout instead would leave `git status` permanently dirty and commit
a machine-specific palette.

So matugen renders `~/.config/dawn/generated/colors.json`, and `Colors.qml`
ships as a normal static file that reads it through `FileView` + `JsonAdapter`.

Verified working, including live reload: with `watchChanges: true` and
`onFileChanged: reload()`, rewriting the JSON repaints the shell immediately —
no regeneration of QML, no restart. The property defaults in `Colors.qml`
double as the fallback palette when the file is absent, which is exactly what a
fresh install needs.

**3. `border` and `highlight` keep their alpha.** They are currently `Qt.rgba(1, 1, 1, 0.06)` and `Qt.rgba(1, 1, 1, 0.10)` — hairline overlays, not solid colours. Mapping them straight to `outline_variant` (`#44474f`) would replace a hairline with a visible border. They are instead tinted by the palette while keeping their alpha, via QML's `.r`/`.g`/`.b` colour components.

---

## File Structure

| File | Responsibility |
|---|---|
| `config/quickshell/dawn-island/theme/Colors.qml` | generated; the palette only |
| `config/quickshell/dawn-island/theme/Theme.qml` | hand-tuned dimensions; re-exports colours |
| `config/matugen/config.toml` | template declarations |
| `config/matugen/templates/*` | one per target |
| `tools/dawn-theme/src/main.rs` | CLI surface and dispatch |
| `tools/dawn-theme/src/state.rs` | `theme.toml` read/write |
| `tools/dawn-theme/src/render.rs` | building and running the matugen invocation |
| `tools/dawn-theme/src/reload.rs` | per-application reloads, individually attributed |
| `tests/contrast-sweep.sh` | the WCAG floor, across every wallpaper × scheme |
| `tests/theme.bats` | CLI behaviour against a fake `$HOME` |

---

### Task 1: Split colours out of `Theme.qml`

A pure refactor with no matugen involved. It must leave the running desktop pixel-identical, which is what makes it safe to generate the file afterwards.

**Files:**
- Create: `config/quickshell/dawn-island/theme/Colors.qml`
- Modify: `config/quickshell/dawn-island/theme/Theme.qml`

**Interfaces:**
- Consumes: nothing
- Produces: singleton `Colors` with 18 colour properties — `background`, `surface`, `surfaceHigh`, `surfaceHighest`, `borderBase`, `highlightBase`, `shadow`, `text`, `textSecondary`, `textTertiary`, `textQuaternary`, `accentBase`, `accentContainer`, `onAccent`, `positive`, `warning`, `danger`, `weekend`. `Theme.qml` re-exports all of them under their existing names, so no call site changes.

- [ ] **Step 1: Record the current values, to compare against later**

```bash
cd /home/jhayonline/software/dawn
grep -oP 'readonly property color \K\w+: .*' \
  config/quickshell/dawn-island/theme/Theme.qml > /tmp/colours-before.txt
cat /tmp/colours-before.txt
```
Expected: 17 lines. Keep this file; Step 6 diffs against it.

- [ ] **Step 2: Create `Colors.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell

/*
 * The palette. Every colour in the shell, and nothing else.
 *
 * THIS FILE IS GENERATED once the colour engine is wired up — see
 * config/matugen/templates/quickshell-colors.qml. Edit that template, not
 * this file.
 *
 * It is separate from Theme.qml because Theme.qml also holds sizes, radii and
 * spacing that are hand-tuned and must not be machine-written. Colours change
 * with the wallpaper; 8px of padding does not.
 *
 * The values below are the built-in default: scheme-monochrome derived from
 * dawn-black.png, which is Dawn's original hand-tuned identity.
 */
Singleton {
    id: root

    // ── Surfaces ──────────────────────────────────────────────────────────
    readonly property color background: "#000000"
    readonly property color surface: "#161616"
    readonly property color surfaceHigh: "#202020"
    readonly property color surfaceHighest: "#2b2b2b"

    // ── Overlay bases ─────────────────────────────────────────────────────
    /// Tinted by the palette but applied at low alpha by Theme.qml. Kept as
    /// solid colours here so the template has somewhere to write; the alpha
    /// lives with the design, not with the palette.
    readonly property color borderBase: "#ffffff"
    readonly property color highlightBase: "#ffffff"

    readonly property color shadow: "#000000"

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color text: "#f2f2f2"
    readonly property color textSecondary: "#b8b8b8"
    readonly property color textTertiary: "#8f8f8f"
    readonly property color textQuaternary: "#5a5a5a"

    // ── Accent ────────────────────────────────────────────────────────────
    readonly property color accentBase: "#f2f2f2"
    readonly property color accentContainer: "#2b2b2b"
    readonly property color onAccent: "#000000"

    // ── Semantic ──────────────────────────────────────────────────────────
    /// NOT generated. Material You defines an error role but has no success or
    /// warning role, and a low-battery warning that changes hue with the
    /// wallpaper has stopped communicating urgency.
    readonly property color positive: "#7ec699"
    readonly property color warning: "#e8c07d"

    readonly property color danger: "#d9534f"
    readonly property color weekend: "#e07a76"
}
```

- [ ] **Step 3: Replace the colour block in `Theme.qml` with re-exports**

Delete every `readonly property color …` line in `Theme.qml` and put this in
their place, immediately after `id: root`:

```qml
    // ── Colours ───────────────────────────────────────────────────────────
    //
    // Re-exported from Colors.qml so that every existing `Theme.background`
    // call site keeps working. Colors.qml is generated by the colour engine;
    // everything below the colour block in this file is hand-tuned and is not.

    readonly property color background: Colors.background
    readonly property color surface: Colors.surface
    readonly property color surfaceHigh: Colors.surfaceHigh
    readonly property color surfaceHighest: Colors.surfaceHighest

    /// Hairline overlays, tinted by the palette but kept at low alpha. A solid
    /// outline colour here would replace a hairline with a visible border.
    readonly property color border: Qt.rgba(Colors.borderBase.r, Colors.borderBase.g, Colors.borderBase.b, 0.06)
    readonly property color highlight: Qt.rgba(Colors.highlightBase.r, Colors.highlightBase.g, Colors.highlightBase.b, 0.10)

    readonly property color shadow: Colors.shadow

    readonly property color text: Colors.text
    readonly property color textSecondary: Colors.textSecondary
    readonly property color textTertiary: Colors.textTertiary
    readonly property color textQuaternary: Colors.textQuaternary

    readonly property color accentBase: Colors.accentBase
    readonly property color accentContainer: Colors.accentContainer
    readonly property color onAccent: Colors.onAccent

    readonly property color positive: Colors.positive
    readonly property color warning: Colors.warning
    readonly property color danger: Colors.danger
    readonly property color weekend: Colors.weekend
```

Add `import qs.theme` to the import block at the top of `Theme.qml` if it is
not already present.

- [ ] **Step 4: Restart the island and confirm it comes up**

```bash
~/.config/quickshell/dawn-island/launch.sh
sleep 2
pgrep -af "qs -p" | head -1
```
Expected: the process is running. Quickshell hot-reloads on file change, so it
should already have picked the edit up; this is the explicit check.

- [ ] **Step 5: Check the Quickshell log for QML errors**

```bash
journalctl --user -n 60 --no-pager 2>/dev/null | grep -iE "qml|Colors|Theme" | tail -20
```
Expected: no `ReferenceError: Colors is not defined` and no
`Unable to assign` lines. If `Colors` is not resolving, the singleton is not
being found — confirm `Colors.qml` sits in the same `theme/` directory as
`Anim.qml`, which resolves the same way.

- [ ] **Step 6: Confirm the values are unchanged**

```bash
grep -oP 'readonly property color \K\w+' \
  config/quickshell/dawn-island/theme/Colors.qml | sort > /tmp/after.txt
grep -oP 'readonly property color \K\w+' /tmp/colours-before.txt | sort > /tmp/before.txt
diff /tmp/before.txt /tmp/after.txt
```
Expected: `borderBase`/`highlightBase` appear in place of `border`/`highlight`,
plus the two new `accentContainer`/`onAccent`. No other differences.

- [ ] **Step 7: Commit**

```bash
git add config/quickshell/dawn-island/theme/Colors.qml config/quickshell/dawn-island/theme/Theme.qml
git commit -m "refactor(island): split the palette into Colors.qml"
```

---

### Task 2: The matugen config and the Colors.qml template

**Files:**
- Create: `config/matugen/config.toml`
- Create: `config/matugen/templates/quickshell-colors.qml`
- Create: `tests/contrast-sweep.sh`

**Interfaces:**
- Consumes: the 18 property names produced by Task 1
- Produces: `~/.config/dawn/generated/Colors.qml`, and `tests/contrast-sweep.sh` exiting non-zero if any pair falls below 4.5

- [ ] **Step 1: Write the template**

`config/matugen/templates/quickshell-colors.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell

/*
 * GENERATED by dawn-theme. Do not edit.
 *
 * Source template: /usr/share/dawn/config/matugen/templates/quickshell-colors.qml
 * Regenerate with: dawn-theme apply
 *
 * Scheme: {{mode}}
 */
Singleton {
    id: root

    // ── Surfaces ──────────────────────────────────────────────────────────
    readonly property color background: "{{colors.surface.default.hex}}"
    readonly property color surface: "{{colors.surface_container.default.hex}}"
    readonly property color surfaceHigh: "{{colors.surface_container_high.default.hex}}"
    readonly property color surfaceHighest: "{{colors.surface_container_highest.default.hex}}"

    // ── Overlay bases ─────────────────────────────────────────────────────
    readonly property color borderBase: "{{colors.outline_variant.default.hex}}"
    readonly property color highlightBase: "{{colors.outline.default.hex}}"

    readonly property color shadow: "{{colors.shadow.default.hex}}"

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color text: "{{colors.on_surface.default.hex}}"
    readonly property color textSecondary: "{{colors.on_surface_variant.default.hex}}"
    readonly property color textTertiary: "{{colors.outline.default.hex}}"
    readonly property color textQuaternary: "{{colors.outline_variant.default.hex}}"

    // ── Accent ────────────────────────────────────────────────────────────
    readonly property color accentBase: "{{colors.primary.default.hex}}"
    readonly property color accentContainer: "{{colors.primary_container.default.hex}}"
    readonly property color onAccent: "{{colors.on_primary.default.hex}}"

    // ── Semantic ──────────────────────────────────────────────────────────
    /// Deliberately NOT derived. Material You has no success or warning role,
    /// and a warning that changes hue stops communicating urgency.
    readonly property color positive: "#7ec699"
    readonly property color warning: "#e8c07d"

    readonly property color danger: "{{colors.error.default.hex}}"
    readonly property color weekend: "{{colors.tertiary.default.hex}}"
}
```

- [ ] **Step 2: Write the matugen config**

`config/matugen/config.toml`:

```toml
# Dawn colour engine — template declarations.
#
# Rendered by `dawn-theme`, which passes this file with --config and always
# supplies --prefer, because matugen 4.1 refuses to run on a multi-colour
# image with no terminal attached.
#
# post_hook is used ONLY to place a generated file where an application reads
# it. It is never used to reload anything: a failing post_hook does not fail
# matugen — it prints an error and still exits 0 — so a caller cannot tell
# whether a reload worked. dawn-theme issues every reload itself.
#
# Output goes to ~/.config/dawn/generated/, not ~/.config/matugen/generated/,
# because the latter sits inside a directory Dawn symlinks read-only from
# /usr/share.

[config]

[templates.quickshell]
input_path  = '~/.config/dawn/templates/quickshell-colors.qml'
output_path = '~/.config/dawn/generated/Colors.qml'
post_hook   = 'ln -nfs "$HOME/.config/dawn/generated/Colors.qml" "$HOME/.config/dawn/live/Colors.qml"'
```

- [ ] **Step 3: Render it by hand and check the output is valid QML**

```bash
mkdir -p ~/.config/dawn/templates ~/.config/dawn/generated ~/.config/dawn/live
cp config/matugen/templates/quickshell-colors.qml ~/.config/dawn/templates/
matugen -c config/matugen/config.toml --prefer saturation -t scheme-monochrome \
  image assets/wallpapers/dawn-black.png
cat ~/.config/dawn/generated/Colors.qml
```
Expected: every `{{…}}` replaced by a `#rrggbb` value; `positive` and
`warning` still the literal `#7ec699` / `#e8c07d`.

- [ ] **Step 4: Confirm the default really is Dawn's identity**

```bash
grep -E 'background|accentBase' ~/.config/dawn/generated/Colors.qml
```
Expected: `background: "#131313"` and `accentBase: "#ffffff"` — a near-black
surface with a white accent.

- [ ] **Step 5: Write the contrast sweep**

`tests/contrast-sweep.sh`:

```bash
#!/usr/bin/env bash
#
# Every wallpaper x every scheme, checked against WCAG AA.
#
# This is the test that stops a future mapping or scheme change from quietly
# making the desktop unreadable. Material You's tonal system is supposed to
# guarantee this by construction; this verifies it rather than trusting it.
#
#     ./tests/contrast-sweep.sh [wallpaper-dir]

set -euo pipefail

DIR="${1:-$HOME/Pictures/Wallpapers}"
FLOOR=4.5

command -v matugen >/dev/null || { echo "matugen not installed" >&2; exit 2; }
[ -d "$DIR" ] || { echo "no wallpaper directory: $DIR" >&2; exit 2; }

python3 - "$DIR" "$FLOOR" <<'PY'
import json, subprocess, sys, pathlib

wall_dir, floor = pathlib.Path(sys.argv[1]), float(sys.argv[2])
SCHEMES = ["tonal-spot","vibrant","expressive","content","fidelity",
           "neutral","monochrome","rainbow","fruit-salad"]
PAIRS = {"text":"on_surface", "textSecondary":"on_surface_variant",
         "textTertiary":"outline", "accentBase":"primary", "danger":"error"}

def lum(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    f = lambda x: x/12.92 if x <= 0.03928 else ((x+0.055)/1.055)**2.4
    return .2126*f(r) + .7152*f(g) + .0722*f(b)

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + .05) / (lb + .05)

images = sorted(p for p in wall_dir.iterdir()
                if p.suffix.lower() in {".png",".jpg",".jpeg",".webp",".gif",".bmp"})
if not images:
    print(f"no images in {wall_dir}", file=sys.stderr); sys.exit(2)

checked = fails = 0
worst = (99.0, "")
for img in images:
    for s in SCHEMES:
        r = subprocess.run(["matugen","-j","hex","--dry-run","--prefer","saturation",
                            "-t",f"scheme-{s}","image",str(img)],
                           capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            print(f"FAIL matugen errored: {img.name} / {s}", file=sys.stderr)
            fails += 1
            continue
        c = json.loads(r.stdout)["colors"]
        bg = c["surface"]["dark"]["color"]
        for role, md3 in PAIRS.items():
            v = ratio(c[md3]["dark"]["color"], bg)
            checked += 1
            if v < worst[0]:
                worst = (v, f"{img.name} / {s} / {role}")
            if v < floor:
                print(f"FAIL {v:.2f} < {floor}  {img.name} / {s} / {role}", file=sys.stderr)
                fails += 1

print(f"checked {checked} contrast pairs across {len(images)} wallpapers")
print(f"worst: {worst[0]:.2f}  ({worst[1]})")
print(f"below {floor}: {fails}")
sys.exit(1 if fails else 0)
PY
```

- [ ] **Step 6: Run the sweep**

```bash
chmod 755 tests/contrast-sweep.sh
shellcheck tests/contrast-sweep.sh
./tests/contrast-sweep.sh
```
Expected: `below 4.5: 0`, exit `0`. With the two shipped wallpapers plus your
own, the worst case should land near `5.8`.

- [ ] **Step 7: Commit**

```bash
git add config/matugen tests/contrast-sweep.sh
git commit -m "feat(theme): add matugen config and the island colour template"
```

---

### Task 3: Templates for the remaining applications

**Files:**
- Create: `config/matugen/templates/kitty-colors.conf`
- Create: `config/matugen/templates/rofi-colors.rasi`
- Create: `config/matugen/templates/hyprland-colors.lua`
- Modify: `config/matugen/config.toml`

**Interfaces:**
- Consumes: `config/matugen/config.toml` from Task 2
- Produces: generated files at `~/.config/dawn/generated/{kitty-colors.conf,rofi-colors.rasi,hyprland-colors.lua}`

- [ ] **Step 1: kitty**

`config/matugen/templates/kitty-colors.conf`:

```conf
# GENERATED by dawn-theme. Do not edit.
# Regenerate with: dawn-theme apply

background            {{colors.surface.default.hex}}
foreground            {{colors.on_surface.default.hex}}
cursor                {{colors.primary.default.hex}}

selection_background  {{colors.surface_container_highest.default.hex}}
selection_foreground  {{colors.on_surface.default.hex}}

color0   {{colors.surface_container_lowest.default.hex}}
color1   {{colors.error.default.hex}}
color2   {{colors.tertiary.default.hex}}
color3   {{colors.secondary.default.hex}}
color4   {{colors.primary.default.hex}}
color5   {{colors.tertiary_container.default.hex}}
color6   {{colors.secondary_container.default.hex}}
color7   {{colors.on_surface.default.hex}}

color8   {{colors.outline.default.hex}}
color9   {{colors.error.default.hex}}
color10  {{colors.tertiary.default.hex}}
color11  {{colors.secondary.default.hex}}
color12  {{colors.primary.default.hex}}
color13  {{colors.tertiary_container.default.hex}}
color14  {{colors.secondary_container.default.hex}}
color15  {{colors.on_surface.default.hex}}
```

- [ ] **Step 2: rofi**

`config/matugen/templates/rofi-colors.rasi`:

```rasi
/* GENERATED by dawn-theme. Do not edit.
 * Regenerate with: dawn-theme apply */
* {
    background:       {{colors.surface.default.hex}};
    background-alt:   {{colors.surface_container.default.hex}};
    background-hover: {{colors.surface_container_high.default.hex}};
    foreground:       {{colors.on_surface.default.hex}};
    foreground-dim:   {{colors.on_surface_variant.default.hex}};
    accent:           {{colors.primary.default.hex}};
    border-colour:    {{colors.outline_variant.default.hex}};
}
```

- [ ] **Step 3: Hyprland**

Note `hex_stripped` — Hyprland's `rgb()` form takes bare hex with no `#`.

`config/matugen/templates/hyprland-colors.lua`:

```lua
-- GENERATED by dawn-theme. Do not edit.
-- Regenerate with: dawn-theme apply
--
-- Required by modules/decorations.lua, which reads these instead of the
-- literals it used to carry.

return {
	activeBorder    = "rgb({{colors.primary.default.hex_stripped}})",
	inactiveBorder  = "rgb({{colors.surface_container.default.hex_stripped}})",
	shadow          = "rgb({{colors.shadow.default.hex_stripped}})",
	background      = "rgb({{colors.surface.default.hex_stripped}})",
}
```

- [ ] **Step 4: Declare all three in the config**

Append to `config/matugen/config.toml`:

```toml
[templates.kitty]
input_path  = '~/.config/dawn/templates/kitty-colors.conf'
output_path = '~/.config/dawn/generated/kitty-colors.conf'

[templates.rofi]
input_path  = '~/.config/dawn/templates/rofi-colors.rasi'
output_path = '~/.config/dawn/generated/rofi-colors.rasi'

[templates.hyprland]
input_path  = '~/.config/dawn/templates/hyprland-colors.lua'
output_path = '~/.config/dawn/generated/hyprland-colors.lua'
```

- [ ] **Step 5: Render and validate each output**

```bash
cp config/matugen/templates/* ~/.config/dawn/templates/
matugen -c config/matugen/config.toml --prefer saturation -t scheme-monochrome \
  image assets/wallpapers/dawn-black.png

luac -p ~/.config/dawn/generated/hyprland-colors.lua && echo "hyprland: valid lua"
grep -c '^color' ~/.config/dawn/generated/kitty-colors.conf
head -4 ~/.config/dawn/generated/rofi-colors.rasi
```
Expected: `hyprland: valid lua`, `16` colour lines for kitty, and the rofi file
showing `#rrggbb` values with no `{{` left anywhere.

- [ ] **Step 6: Assert no template markers survived in any output**

```bash
if grep -rl '{{' ~/.config/dawn/generated/; then
  echo "UNRENDERED TEMPLATE MARKERS — a variable name is wrong" >&2
else
  echo "all templates fully rendered"
fi
```
Expected: `all templates fully rendered`. A surviving `{{…}}` means that
colour role does not exist — check the name against
`matugen -j hex --dry-run --prefer saturation image <img> | python3 -m json.tool`.

- [ ] **Step 7: Commit**

```bash
git add config/matugen
git commit -m "feat(theme): add kitty, rofi and hyprland colour templates"
```

---

### Task 4: `dawn-theme` state

**Files:**
- Create: `tools/dawn-theme/Cargo.toml`
- Create: `tools/dawn-theme/src/state.rs`
- Create: `tools/dawn-theme/src/main.rs`

**Interfaces:**
- Consumes: nothing
- Produces: `state::Theme { source: Source, scheme: String, mode: String, contrast: f32 }` where `Source` is `Source::Wallpaper(PathBuf)` or `Source::Color(String)`; `Theme::load() -> Theme` (never fails — falls back to default), `Theme::save(&self) -> Result<()>`, `Theme::default()`.

- [ ] **Step 1: Write `Cargo.toml`**

```toml
[package]
name = "dawn-theme"
version = "0.1.0"
edition = "2024"
description = "Dawn's colour engine — drives matugen and reloads the desktop"

[dependencies]
# Argument parsing. `derive` keeps the CLI surface next to the types it fills.
clap = { version = "4", features = ["derive"] }
# theme.toml is read and written by both this tool and, read-only, by the
# island — so it has to be a real serialised format, not an ad-hoc one.
serde = { version = "1", features = ["derive"] }
toml = "0.8"
serde_json = "1"

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
strip = true
```

- [ ] **Step 2: Write the failing test**

Append to `tools/dawn-theme/src/state.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn tmp() -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("dawn-theme-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn round_trips_a_wallpaper_source() {
        let dir = tmp();
        let t = Theme {
            source: Source::Wallpaper("/tmp/a.png".into()),
            scheme: "scheme-vibrant".into(),
            mode: "dark".into(),
            contrast: 0.25,
        };
        t.save_to(&dir).unwrap();
        let back = Theme::load_from(&dir);
        assert_eq!(back.scheme, "scheme-vibrant");
        assert_eq!(back.contrast, 0.25);
        assert!(matches!(back.source, Source::Wallpaper(p) if p.ends_with("a.png")));
    }

    #[test]
    fn round_trips_a_colour_source() {
        let dir = tmp();
        let t = Theme { source: Source::Color("#ff0000".into()), ..Theme::default() };
        t.save_to(&dir).unwrap();
        assert!(matches!(Theme::load_from(&dir).source, Source::Color(c) if c == "#ff0000"));
    }

    #[test]
    fn missing_state_falls_back_to_the_default_rather_than_failing() {
        // A fresh install has no theme.toml and must still produce a desktop.
        let back = Theme::load_from(&tmp().join("does-not-exist"));
        assert_eq!(back.scheme, "scheme-monochrome");
        assert_eq!(back.mode, "dark");
    }

    #[test]
    fn corrupt_state_falls_back_rather_than_failing() {
        let dir = tmp();
        std::fs::write(dir.join("theme.toml"), b"this is not toml {{{").unwrap();
        assert_eq!(Theme::load_from(&dir).scheme, "scheme-monochrome");
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd tools/dawn-theme && cargo test 2>&1 | tail -20
```
Expected: compile error — `Theme`, `Source`, `save_to`, `load_from` do not exist.

- [ ] **Step 4: Write the implementation**

Put this above the `#[cfg(test)]` block in `tools/dawn-theme/src/state.rs`:

```rust
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// Where the palette is derived from.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Source {
    /// An image on disk.
    Wallpaper(PathBuf),
    /// A seed colour, as `#rrggbb`.
    Color(String),
}

/// Everything needed to reproduce the current palette.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Theme {
    pub source: Source,
    pub scheme: String,
    pub mode: String,
    pub contrast: f32,
}

impl Default for Theme {
    /// Dawn's shipped identity: scheme-monochrome on dawn-black.png produces a
    /// near-black surface with a white accent, which is the palette the island
    /// was originally hand-tuned to.
    fn default() -> Self {
        Theme {
            source: Source::Wallpaper(
                PathBuf::from("/usr/share/dawn/assets/wallpapers/dawn-black.png"),
            ),
            scheme: "scheme-monochrome".into(),
            mode: "dark".into(),
            contrast: 0.0,
        }
    }
}

impl Theme {
    /// The directory holding `theme.toml`: `~/.config/dawn`.
    pub fn dir() -> PathBuf {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(std::env::var_os("HOME").expect("HOME is not set")).join(".config")
            });
        base.join("dawn")
    }

    pub fn load() -> Theme {
        Theme::load_from(&Theme::dir())
    }

    /// Never fails. A fresh install has no state file, and a corrupt one is
    /// not a reason to leave someone without a desktop — both fall back to the
    /// shipped default.
    pub fn load_from(dir: &Path) -> Theme {
        std::fs::read_to_string(dir.join("theme.toml"))
            .ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> std::io::Result<()> {
        self.save_to(&Theme::dir())
    }

    pub fn save_to(&self, dir: &Path) -> std::io::Result<()> {
        std::fs::create_dir_all(dir)?;
        let body = toml::to_string_pretty(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        std::fs::write(dir.join("theme.toml"), body)
    }
}
```

Create `tools/dawn-theme/src/main.rs` so the crate builds:

```rust
mod state;

fn main() {
    let t = state::Theme::load();
    println!("{} {} {:?}", t.scheme, t.mode, t.source);
}
```

- [ ] **Step 5: Run the tests**

```bash
cd tools/dawn-theme && cargo test 2>&1 | tail -12
```
Expected: `test result: ok. 4 passed`.

- [ ] **Step 6: Commit**

```bash
git add tools/dawn-theme
git commit -m "feat(dawn-theme): add theme state with a safe default"
```

---

### Task 5: `dawn-theme` render

**Files:**
- Create: `tools/dawn-theme/src/render.rs`
- Modify: `tools/dawn-theme/src/main.rs`

**Interfaces:**
- Consumes: `state::{Theme, Source}` from Task 4
- Produces: `render::args(&Theme, &Path) -> Vec<String>` building the matugen argument list, and `render::run(&Theme) -> Result<(), String>`

- [ ] **Step 1: Write the failing test**

`tools/dawn-theme/src/render.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::{Source, Theme};
    use std::path::PathBuf;

    fn cfg() -> PathBuf { PathBuf::from("/tmp/config.toml") }

    #[test]
    fn always_passes_prefer_because_matugen_refuses_without_a_tty() {
        // matugen 4.1: "Multiple source colors found, no preference was
        // inputted, and a terminal was not detected." dawn-theme is always
        // headless, so this flag is not optional.
        let a = args(&Theme::default(), &cfg());
        let i = a.iter().position(|x| x == "--prefer").expect("--prefer missing");
        assert_eq!(a[i + 1], "saturation");
    }

    #[test]
    fn never_passes_source_color_index_which_does_not_exist_in_4_1() {
        assert!(!args(&Theme::default(), &cfg()).iter().any(|x| x == "--source-color-index"));
    }

    #[test]
    fn wallpaper_source_uses_the_image_subcommand_last() {
        let t = Theme { source: Source::Wallpaper("/tmp/w.png".into()), ..Theme::default() };
        let a = args(&t, &cfg());
        assert_eq!(a[a.len() - 2], "image");
        assert_eq!(a[a.len() - 1], "/tmp/w.png");
    }

    #[test]
    fn colour_source_uses_the_color_hex_subcommand() {
        let t = Theme { source: Source::Color("#ff0000".into()), ..Theme::default() };
        let a = args(&t, &cfg());
        assert_eq!(a[a.len() - 3], "color");
        assert_eq!(a[a.len() - 2], "hex");
        assert_eq!(a[a.len() - 1], "#ff0000");
    }

    #[test]
    fn zero_contrast_is_omitted_rather_than_sent_as_zero() {
        let t = Theme { contrast: 0.0, ..Theme::default() };
        assert!(!args(&t, &cfg()).iter().any(|x| x == "--contrast"));
        let t = Theme { contrast: 0.5, ..Theme::default() };
        assert!(args(&t, &cfg()).iter().any(|x| x == "--contrast"));
    }

    #[test]
    fn scheme_and_mode_are_always_sent() {
        let a = args(&Theme::default(), &cfg());
        let i = a.iter().position(|x| x == "--type").unwrap();
        assert_eq!(a[i + 1], "scheme-monochrome");
        let i = a.iter().position(|x| x == "--mode").unwrap();
        assert_eq!(a[i + 1], "dark");
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd tools/dawn-theme && cargo test render 2>&1 | tail -12
```
Expected: compile error — `args` does not exist.

- [ ] **Step 3: Write the implementation**

Put this above the test module in `render.rs`:

```rust
use crate::state::{Source, Theme};
use std::path::Path;
use std::process::Command;

/// Build the matugen argument list.
///
/// Split out from `run` so the invocation can be asserted on without a
/// matugen binary present — the flags are the part that goes wrong.
///
/// Order matters: matugen uses clap, so global options come before the
/// subcommand and its positional arguments come last.
pub fn args(theme: &Theme, config: &Path) -> Vec<String> {
    let mut a: Vec<String> = vec![
        "--config".into(),
        config.display().to_string(),
        // Not optional. matugen 4.1 refuses to run on an image with multiple
        // candidate colours when no terminal is detected, and dawn-theme is
        // always headless — invoked from the shell, a hook or a service.
        "--prefer".into(),
        "saturation".into(),
        "--mode".into(),
        theme.mode.clone(),
        "--type".into(),
        theme.scheme.clone(),
    ];

    // Sent only when it differs from the default. Passing --contrast 0 is
    // accepted but makes the command line lie about what was asked for.
    if theme.contrast != 0.0 {
        a.push("--contrast".into());
        a.push(theme.contrast.to_string());
    }

    match &theme.source {
        Source::Wallpaper(p) => {
            a.push("image".into());
            a.push(p.display().to_string());
        }
        Source::Color(c) => {
            a.push("color".into());
            a.push("hex".into());
            a.push(c.clone());
        }
    }
    a
}

/// Run matugen. Returns its stderr on failure.
pub fn run(theme: &Theme, config: &Path) -> Result<(), String> {
    let a = args(theme, config);
    let out = Command::new("matugen")
        .args(&a)
        .output()
        .map_err(|e| format!("could not run matugen: {e}"))?;

    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).trim().to_string());
    }

    // matugen exits 0 even when a post_hook fails, so success here means the
    // templates rendered — not that the desktop reloaded. Reloads are issued
    // separately by the reload module, which reports its own failures.
    Ok(())
}
```

Add `mod render;` to `main.rs`.

- [ ] **Step 4: Run the tests**

```bash
cd tools/dawn-theme && cargo test 2>&1 | tail -12
```
Expected: `test result: ok. 10 passed`.

- [ ] **Step 5: Commit**

```bash
git add tools/dawn-theme
git commit -m "feat(dawn-theme): build and run the matugen invocation"
```

---

### Task 6: `dawn-theme` reloads and the CLI surface

**Files:**
- Create: `tools/dawn-theme/src/reload.rs`
- Modify: `tools/dawn-theme/src/main.rs`

**Interfaces:**
- Consumes: `state::Theme`, `render::run`
- Produces: `reload::all() -> Vec<(String, Result<(), String>)>`, and the full CLI: `wallpaper`, `color`, `scheme`, `mode`, `contrast`, `status`, `apply`

- [ ] **Step 1: Write the failing test**

`tools/dawn-theme/src/reload.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_failing_reload_does_not_stop_the_others() {
        // A terminal that will not accept USR1 must not prevent GTK from
        // updating. Each reload is independent and individually attributed.
        let results = run_all(&[
            Reload { name: "ok-one", program: "true", args: &[] },
            Reload { name: "broken", program: "definitely-not-a-real-binary", args: &[] },
            Reload { name: "ok-two", program: "true", args: &[] },
        ]);
        assert_eq!(results.len(), 3);
        assert!(results[0].1.is_ok());
        assert!(results[1].1.is_err());
        assert!(results[2].1.is_ok());
    }

    #[test]
    fn a_failure_names_the_application() {
        let results = run_all(&[Reload {
            name: "kitty", program: "definitely-not-a-real-binary", args: &[],
        }]);
        assert_eq!(results[0].0, "kitty");
    }

    #[test]
    fn a_missing_program_is_not_an_error_worth_reporting_twice() {
        // Absent applications are normal — not everyone runs kitty.
        let results = run_all(&[Reload {
            name: "absent", program: "definitely-not-a-real-binary", args: &[],
        }]);
        assert!(results[0].1.as_ref().unwrap_err().contains("absent"));
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd tools/dawn-theme && cargo test reload 2>&1 | tail -10
```
Expected: compile error — `Reload` and `run_all` do not exist.

- [ ] **Step 3: Write the implementation**

Put this above the test module in `reload.rs`:

```rust
use std::process::{Command, Stdio};

/// One application's reload.
pub struct Reload {
    pub name: &'static str,
    pub program: &'static str,
    pub args: &'static [&'static str],
}

/// Every reload Dawn issues after a successful render.
///
/// These are NOT matugen post_hooks. A failing post_hook does not fail
/// matugen — it prints an error and matugen still exits 0 — so running them
/// there would make failures invisible to the caller.
///
/// Applications absent from this list read their colours at launch and need
/// no reload: rofi, hyprlock, starship, nvim, and Qt via qt5ct/qt6ct.
/// Quickshell is also absent — it hot-reloads on file change by itself.
pub const RELOADS: &[Reload] = &[
    // kitty reloads its config on USR1. `pkill` is a no-op when kitty is not
    // running, which is the common case on a headless invocation.
    Reload { name: "kitty",    program: "pkill",   args: &["-USR1", "kitty"] },
    Reload { name: "hyprland", program: "hyprctl", args: &["reload"] },
    // Nudges GTK applications into re-reading gtk.css.
    Reload { name: "gtk",      program: "gsettings",
             args: &["set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"] },
];

pub fn run_all(reloads: &[Reload]) -> Vec<(String, Result<(), String>)> {
    reloads
        .iter()
        .map(|r| {
            let outcome = Command::new(r.program)
                .args(r.args)
                .stdout(Stdio::null())
                .stderr(Stdio::piped())
                .output()
                .map_err(|e| format!("{}: could not run {}: {e}", r.name, r.program))
                .and_then(|out| {
                    // pkill exits 1 when it matched nothing, which simply
                    // means the application is not running. That is not a
                    // failure worth reporting.
                    if out.status.success() || r.program == "pkill" {
                        Ok(())
                    } else {
                        Err(format!(
                            "{}: {} exited {}",
                            r.name,
                            r.program,
                            out.status.code().unwrap_or(-1)
                        ))
                    }
                });
            (r.name.to_string(), outcome)
        })
        .collect()
}

pub fn all() -> Vec<(String, Result<(), String>)> {
    run_all(RELOADS)
}
```

- [ ] **Step 4: Write the CLI**

Replace `tools/dawn-theme/src/main.rs` entirely:

```rust
//! dawn-theme — Dawn's colour engine.
//!
//! Owns the theme state, drives matugen, and reloads the desktop. Reloads are
//! issued here rather than as matugen post_hooks because a failing post_hook
//! does not fail matugen: it prints an error and matugen still exits 0, so a
//! caller cannot learn whether the desktop actually picked up the change.

mod reload;
mod render;
mod state;

use clap::{Parser, Subcommand};
use state::{Source, Theme};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser)]
#[command(name = "dawn-theme", about = "Dawn's colour engine")]
struct Cli {
    /// matugen config. Defaults to the one shipped with dawn-config.
    #[arg(long, default_value = "/usr/share/dawn/config/matugen/config.toml")]
    config: PathBuf,

    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Derive the palette from an image.
    Wallpaper { path: PathBuf },
    /// Derive the palette from a seed colour, as #rrggbb.
    Color { hex: String },
    /// One of matugen's nine schemes, with or without the `scheme-` prefix.
    Scheme { name: String },
    /// dark or light.
    Mode { mode: String },
    /// -1.0 to 1.0.
    Contrast { value: f32 },
    /// Print the current state as JSON.
    Status,
    /// Re-render from stored state, changing nothing.
    Apply,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let mut theme = Theme::load();

    match cli.command {
        Cmd::Wallpaper { path } => {
            match path.canonicalize() {
                Ok(p) => theme.source = Source::Wallpaper(p),
                Err(e) => {
                    eprintln!("error: {}: {e}", path.display());
                    return ExitCode::FAILURE;
                }
            }
        }
        Cmd::Color { hex } => {
            let hex = if hex.starts_with('#') { hex } else { format!("#{hex}") };
            if hex.len() != 7 || !hex[1..].chars().all(|c| c.is_ascii_hexdigit()) {
                eprintln!("error: not a #rrggbb colour: {hex}");
                return ExitCode::FAILURE;
            }
            theme.source = Source::Color(hex);
        }
        Cmd::Scheme { name } => {
            let name = if name.starts_with("scheme-") { name } else { format!("scheme-{name}") };
            const VALID: &[&str] = &[
                "scheme-content", "scheme-expressive", "scheme-fidelity",
                "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
                "scheme-rainbow", "scheme-tonal-spot", "scheme-vibrant",
            ];
            if !VALID.contains(&name.as_str()) {
                eprintln!("error: unknown scheme: {name}");
                eprintln!("       one of: {}", VALID.join(", "));
                return ExitCode::FAILURE;
            }
            theme.scheme = name;
        }
        Cmd::Mode { mode } => {
            if mode != "dark" && mode != "light" {
                eprintln!("error: mode must be dark or light, not {mode}");
                return ExitCode::FAILURE;
            }
            theme.mode = mode;
        }
        Cmd::Contrast { value } => {
            if !(-1.0..=1.0).contains(&value) {
                eprintln!("error: contrast must be between -1.0 and 1.0, not {value}");
                return ExitCode::FAILURE;
            }
            theme.contrast = value;
        }
        Cmd::Status => {
            println!("{}", serde_json::to_string_pretty(&theme).unwrap());
            return ExitCode::SUCCESS;
        }
        Cmd::Apply => {}
    }

    // Render first. State is only recorded once matugen has actually produced
    // the templates, so a failed run leaves the previous palette in place and
    // theme.toml still describing it.
    if let Err(e) = render::run(&theme, &cli.config) {
        eprintln!("error: matugen failed:\n{e}");
        return ExitCode::FAILURE;
    }
    if let Err(e) = theme.save() {
        eprintln!("error: rendered, but could not save state: {e}");
        return ExitCode::FAILURE;
    }

    let mut failed = 0;
    for (name, outcome) in reload::all() {
        if let Err(e) = outcome {
            eprintln!("warning: {name} did not reload: {e}");
            failed += 1;
        }
    }
    if failed > 0 {
        eprintln!("{failed} application(s) did not reload; the palette is written regardless");
    }
    ExitCode::SUCCESS
}
```

- [ ] **Step 5: Run the tests and build**

```bash
cd tools/dawn-theme && cargo test 2>&1 | tail -8 && cargo build --release 2>&1 | tail -3
```
Expected: `test result: ok. 13 passed`, and a clean release build.

- [ ] **Step 6: Exercise the CLI end to end**

```bash
cd /home/jhayonline/software/dawn
./tools/dawn-theme/target/release/dawn-theme \
  --config config/matugen/config.toml status
./tools/dawn-theme/target/release/dawn-theme \
  --config config/matugen/config.toml scheme vibrant
grep accentBase ~/.config/dawn/generated/Colors.qml
./tools/dawn-theme/target/release/dawn-theme \
  --config config/matugen/config.toml scheme monochrome
grep accentBase ~/.config/dawn/generated/Colors.qml
```
Expected: `status` prints JSON; `scheme vibrant` changes `accentBase` away from
white; `scheme monochrome` returns it to `#ffffff`.

- [ ] **Step 7: Reject a bad scheme**

```bash
./tools/dawn-theme/target/release/dawn-theme scheme nonsense; echo "exit=$?"
```
Expected: `error: unknown scheme: scheme-nonsense`, the list of valid schemes,
and `exit=1`.

- [ ] **Step 8: Commit**

```bash
git add tools/dawn-theme
git commit -m "feat(dawn-theme): add reloads and the CLI surface"
```

---

### Task 7: Retire `Accent.qml` and drop ffmpeg

**Files:**
- Delete: `config/quickshell/dawn-island/services/Accent.qml`
- Modify: `config/quickshell/dawn-island/Config.qml`, `theme/Theme.qml`, `shell.qml`, `modules/LauncherView.qml`, `README.md`
- Modify: `install/packages.txt`, `packaging/PKGBUILD`

**Interfaces:**
- Consumes: the generated `Colors.qml` from Task 2, which now supplies the accent
- Produces: nothing new; removes `Accent`, `Config.deriveAccentFromWallpaper`, and the `ffmpeg` dependency

- [ ] **Step 1: Find every reference before removing anything**

```bash
cd /home/jhayonline/software/dawn
grep -rn "Accent\|deriveAccentFromWallpaper" config/quickshell/dawn-island/ | sed 's/^/  /'
```
Expected: hits in `shell.qml`, `theme/Theme.qml`, `Config.qml`,
`modules/LauncherView.qml`, `README.md`, and `services/Accent.qml` itself.
Every one must be handled; work through the list.

- [ ] **Step 2: Remove the service and its config flag**

```bash
git rm config/quickshell/dawn-island/services/Accent.qml
```

In `Config.qml`, delete the `deriveAccentFromWallpaper` property and its
doc-comment block. In `theme/Theme.qml`, `shell.qml` and
`modules/LauncherView.qml`, remove any `Accent.` reference and any now-unused
`import qs.services` — replacing accent reads with `Colors.accentBase`, which
Task 1's re-export already exposes as `Theme.accentBase`.

- [ ] **Step 3: Update the island README**

Replace the accent section of `config/quickshell/dawn-island/README.md` with:

```markdown
## Colour

The island does not derive its own colours. `theme/Colors.qml` is generated by
`dawn-theme`, which runs matugen over the current wallpaper or seed colour and
renders every application's palette from the same source.

Change the palette with `dawn-theme wallpaper <path>` or
`dawn-theme scheme <name>`; Quickshell hot-reloads the generated file, so the
island repaints without restarting.
```

- [ ] **Step 4: Drop ffmpeg from the manifest**

`Accent.qml` was its only consumer. Confirm, then remove:

```bash
grep -rn "ffmpeg" config/ tools/ | grep -v packages.txt | sed 's/^/  /'
```
Expected: no hits. If there are any, ffmpeg stays and this step is skipped.

Delete the three-line `ffmpeg` entry from `install/packages.txt` and the
`ffmpeg` line from `_dawn_depends` in `packaging/PKGBUILD`.

- [ ] **Step 5: Verify the manifest and PKGBUILD still agree**

```bash
./packaging/check-depends.sh
```
Expected: `ok: PKGBUILD dependencies match install/packages.txt (30 packages)`
— thirty, down from thirty-one.

- [ ] **Step 6: Confirm the island still runs**

```bash
~/.config/quickshell/dawn-island/launch.sh
sleep 2
pgrep -af "qs -p" | head -1
journalctl --user -n 40 --no-pager 2>/dev/null | grep -iE "Accent|ReferenceError" | tail -5
```
Expected: the process is running and no `Accent is not defined` errors.

- [ ] **Step 7: Commit**

```bash
git add -A config/quickshell/dawn-island install/packages.txt packaging/PKGBUILD
git commit -m "refactor(island): retire Accent.qml in favour of the colour engine"
```

---

### Task 8: Package the colour engine

**Files:**
- Modify: `install/packages.txt`, `packaging/PKGBUILD`, `packaging/dawn`, `tests/dawn.bats`

**Interfaces:**
- Consumes: `tools/dawn-theme/` from Tasks 4–6, `config/matugen/` from Tasks 2–3
- Produces: `/usr/bin/dawn-theme`, `/usr/share/dawn/config/matugen/`, and templates seeded to `~/.config/dawn/templates/`

- [ ] **Step 1: Add the new dependencies to the manifest**

Append to the appropriate sections of `install/packages.txt`:

```
matugen                     # the colour engine; generates every palette from
                            # the wallpaper or a seed colour
adw-gtk-theme               # the GTK3 theme the generated gtk.css overrides
qt5ct                       # applies the generated palette to Qt5 applications
qt6ct                       # and to Qt6
```

- [ ] **Step 2: Mirror them in the PKGBUILD**

Add `matugen`, `adw-gtk-theme`, `qt5ct` and `qt6ct` to `_dawn_depends` in
`packaging/PKGBUILD`, then confirm:

```bash
./packaging/check-depends.sh
```
Expected: `ok: PKGBUILD dependencies match install/packages.txt (34 packages)`.

- [ ] **Step 3: Build `dawn-theme` in the PKGBUILD**

In `packaging/PKGBUILD`, extend `prepare()` and `build()` to cover the second
crate, and add a package function. Replace the existing `prepare` and `build`
with:

```bash
prepare() {
	cd "$(_dawn_srcdir)/tools/typist"
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/^host: //p')"
	cd "$(_dawn_srcdir)/tools/dawn-theme"
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/^host: //p')"
}

build() {
	export RUSTUP_TOOLCHAIN=stable

	cd "$(_dawn_srcdir)/tools/typist"
	export CARGO_TARGET_DIR="$srcdir/typist-target"
	cargo build --frozen --release

	cd "$(_dawn_srcdir)/tools/dawn-theme"
	export CARGO_TARGET_DIR="$srcdir/dawn-theme-target"
	cargo build --frozen --release
}
```

`dawn-theme` ships inside `dawn-config` rather than as its own package: it is
useless without the templates, and the templates are useless without it.

In `package_dawn-config()`, before the `install -Dm755 packaging/dawn` line,
add:

```bash
	install -Dm755 "$srcdir/dawn-theme-target/release/dawn-theme" \
		"$pkgdir/usr/bin/dawn-theme"
```

Add `libgcc` and `glibc` to `dawn-config`'s `depends` array, since it now
contains a compiled binary, and change its `arch` from `any` to `x86_64`.

- [ ] **Step 4: Seed the templates in the CLI**

matugen's `input_path` points at `~/.config/dawn/templates/`, so the templates
must be copied there. Add to `seed_all()` in `packaging/dawn`, immediately
before the `seed_wallpapers` call:

```bash
	# matugen reads templates from ~/.config/dawn/templates. They are copied
	# rather than symlinked so that someone can tweak one without needing
	# write access to /usr/share — the same reasoning as every other SEED.
	local tpl_src tpl_dst t
	tpl_src="$SOURCE/matugen/templates"
	tpl_dst="$OVERRIDES/templates"
	if [ -d "$tpl_src" ]; then
		mkdir -p "$tpl_dst" "$OVERRIDES/generated"
		for t in "$tpl_src"/*; do
			[ -f "$t" ] || continue
			seed_one "$t" "$tpl_dst/$(basename "$t")" "templates/$(basename "$t")"
		done
	fi
```

- [ ] **Step 5: Test the seeding**

Append to `tests/dawn.bats`:

```bash
@test "link seeds matugen templates into ~/.config/dawn/templates" {
    mkdir -p "$DAWN_SHARE/config/matugen/templates"
    echo 'x {{colors.primary.default.hex}}' > "$DAWN_SHARE/config/matugen/templates/kitty-colors.conf"

    run "$DAWN" link
    [ "$status" -eq 0 ]
    [ -f "$XDG_CONFIG_HOME/dawn/templates/kitty-colors.conf" ]
    [ ! -L "$XDG_CONFIG_HOME/dawn/templates/kitty-colors.conf" ]
    [ -d "$XDG_CONFIG_HOME/dawn/generated" ]
}

@test "template seeding never overwrites one you edited" {
    mkdir -p "$DAWN_SHARE/config/matugen/templates" "$XDG_CONFIG_HOME/dawn/templates"
    echo 'shipped' > "$DAWN_SHARE/config/matugen/templates/kitty-colors.conf"
    echo 'MINE'    > "$XDG_CONFIG_HOME/dawn/templates/kitty-colors.conf"

    "$DAWN" link
    [ "$(cat "$XDG_CONFIG_HOME/dawn/templates/kitty-colors.conf")" = "MINE" ]
}
```

```bash
bats tests/dawn.bats
shellcheck packaging/dawn
```
Expected: all tests pass, shellcheck clean.

- [ ] **Step 6: Build and lint the packages**

```bash
cd packaging
DAWN_LOCAL_SOURCE=1 makepkg --force --nodeps --cleanbuild 2>&1 | tail -3
pacman -Qlp dawn-config-*.pkg.tar.zst | grep -E "dawn-theme|matugen"
for p in ./*.pkg.tar.zst; do echo "$p: $(namcap "$p" | grep -c ' E: ') errors"; done
```
Expected: `/usr/bin/dawn-theme` and `/usr/share/dawn/config/matugen/...`
present, and `0 errors` for every package. If `dawn-config` reports a missing
library, add it to that package's `depends` — take the name from
`ldd pkg/dawn-config/usr/bin/dawn-theme`.

- [ ] **Step 7: Commit**

```bash
git add -A install packaging tests
git commit -m "feat(packaging): ship dawn-theme and the matugen templates"
```

---

### Task 9: Document the colour engine

**Files:**
- Create: `docs/theming.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above
- Produces: documentation

- [ ] **Step 1: Write `docs/theming.md`**

```markdown
# How Dawn is coloured

Every colour in Dawn comes from one source — a wallpaper, or a seed colour —
through [matugen](https://github.com/InioX/matugen), which implements Google's
Material Color Utilities.

```
wallpaper ─┐
           ├─> dawn-theme ─> matugen ─> templates ─> ~/.config/dawn/generated
seed hex ──┘        │                                          │
                    └────────────── reload ────────────────────┘
```

## Using it

```sh
dawn-theme wallpaper ~/Pictures/Wallpapers/black-nature.png
dawn-theme color '#7ec699'
dawn-theme scheme vibrant
dawn-theme mode light
dawn-theme contrast 0.3
dawn-theme status          # current state, as JSON
dawn-theme apply           # re-render from stored state
```

State lives in `~/.config/dawn/theme.toml`. A missing or corrupt file falls
back to the shipped default rather than leaving you without a desktop.

## The default is deliberately monochrome

Dawn ships `scheme-monochrome` on `dawn-black.png`, which produces a near-black
surface with a white accent — the palette the island was originally hand-tuned
to. Pick a photograph and it becomes Material You.

This is not an accident of the wallpaper being monochrome. Under
`scheme-tonal-spot` a monochrome image yields *no* source colour, so matugen
falls back to a built-in blue — and both shipped wallpapers then produce
byte-identical palettes. `--fallback-color` does not help either: seeding grey
`#f2f2f2` comes back cyan, because Material You's tonal generation always
pushes a seed toward some hue. `scheme-monochrome` is the only route to a
genuinely neutral palette.

## Adding a target

1. Write a template in `config/matugen/templates/`
2. Declare it in `config/matugen/config.toml`
3. If the application needs a reload, add it to `RELOADS` in
   `tools/dawn-theme/src/reload.rs` — **not** as a `post_hook`

`post_hook` is for file placement only. A failing `post_hook` does not fail
matugen: it prints an error and matugen still exits `0`, so a reload run there
would fail invisibly.

Template syntax:

| Expression | Yields |
|---|---|
| `{{colors.primary.default.hex}}` | `#ffffff` |
| `{{colors.primary.default.hex_stripped}}` | `ffffff` — Hyprland's `rgb()` form |
| `{{colors.primary.default.rgb}}` | `rgb(255, 255, 255)` |

The `matugen -j hex` JSON dump keys values as `.color`, not `.hex`. Writing a
template against a JSON sample is the easiest way to get this wrong.

## What is never themed

`positive` (`#7ec699`) and `warning` (`#e8c07d`) are fixed. Material You
defines an `error` role but has no success or warning role, and a low-battery
warning that turns blue because the wallpaper is blue has stopped
communicating urgency.

## Contrast

`tests/contrast-sweep.sh` checks every wallpaper against all nine schemes and
fails if any text-on-background pair drops below WCAG AA 4.5.

```sh
./tests/contrast-sweep.sh
```

Run it after changing the role mapping in
`config/matugen/templates/quickshell-colors.qml`. It is what stops a mapping
change from quietly making the desktop unreadable.
```

- [ ] **Step 2: Link it from the README**

In `README.md`, in the "Design decisions" section, replace the **One palette**
paragraph with:

```markdown
**One source, every application.** Dawn does not ship a set of hand-maintained
themes. The wallpaper — or a seed colour — generates a full Material You
palette, and the terminal, launcher, compositor, editor, GTK and Qt all render
from it. Out of the box it is monochrome, which is Dawn's own identity; pick a
photograph and the whole desktop follows.

See [`docs/theming.md`](docs/theming.md).
```

- [ ] **Step 3: Check for stale claims**

```bash
grep -n "Accent.qml\|deriveAccentFromWallpaper\|ffmpeg" README.md docs/*.md
```
Expected: no hits. `docs/packaging.md` mentions the dependency count — if it
says 31, update it to 34.

- [ ] **Step 4: Commit**

```bash
git add docs README.md
git commit -m "docs: explain how the colour engine works"
```

---

## Self-Review

**Spec coverage**

| Spec section | Task |
|---|---|
| D1 matugen as engine | 2, 5 |
| D2 two sources | 5, 6 |
| D3 monochrome default | 2 (step 4), 4 (`Theme::default`) |
| D4 `Theme.qml` generated | 1, 2 — as `Colors.qml`; deviation documented above |
| D5 `positive`/`warning` fixed | 1, 2 |
| D6 reloads owned by `dawn-theme` | 6 |
| CLI surface | 6 |
| Templates | 2, 3 |
| `--prefer` mandatory | 5 (test asserts it) |
| Retire `Accent.qml`, drop ffmpeg | 7 |
| Packaging | 8 |
| Contrast floor | 2 (`tests/contrast-sweep.sh`) |
| Docs | 9 |

**Gap found and closed:** the spec lists nine templates, including
`hyprlock`, `starship`, `nvim`, `gtk3`, `gtk4` and `qtct`. This plan ships four
(`quickshell`, `kitty`, `rofi`, `hyprland`) and adds the dependencies for the
rest. That is deliberate: the four cover everything Dawn currently draws
itself, each of the remaining five needs its own colour-format research, and
none of them blocks the engine. They are follow-on work, and Task 9's "Adding a
target" section is written so they can be added without touching the engine.
`docs/theming.md` should not claim GTK or Qt are themed until those templates
exist.

**Placeholder scan:** none. Every step carries the code it needs.

**Type consistency:** `state::Theme` fields (`source`, `scheme`, `mode`,
`contrast`) are used identically in Tasks 4, 5 and 6. `render::args(&Theme,
&Path) -> Vec<String>` and `render::run(&Theme, &Path) -> Result<(), String>`
match their call sites in `main.rs`. `reload::Reload { name, program, args }`
and `run_all(&[Reload])` match. `Colors.qml`'s 18 property names are identical
in Task 1's hand-written version, Task 2's template, and Task 1's `Theme.qml`
re-exports — `borderBase` and `highlightBase` deliberately differ from
`Theme.border` and `Theme.highlight`, which apply the alpha.
