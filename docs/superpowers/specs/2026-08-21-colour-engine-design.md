# Dawn colour engine — design

**Date:** 2026-08-21
**Status:** approved, not yet implemented
**Scope:** sub-project A of theming. The island switcher (B) and Firefox (C) are separate specs.

## Problem

Dawn currently has one hardcoded palette. `dawn-island/theme/Theme.qml` defines
sixteen colour roles as literals; kitty, rofi and Hyprland each carry their own
copy of roughly the same greys, kept in sync by hand. `services/Accent.qml`
derives a single accent hue from the wallpaper and nothing else follows it.

An earlier attempt at theming — three palettes under `themes/` driven by a C
switcher — was deleted on 2026-08-21 because all twenty-four of its files were
empty. It was replaced by nothing.

The goal is one engine that colours the entire desktop from one source, with no
hand-maintained palette files.

## Decisions

### D1 — matugen is the engine

`extra/matugen 4.1.0`. Written in Rust, in the official Arch repositories, so
it satisfies Dawn's no-AUR rule. It implements Google's Material Color
Utilities: a source colour in, a full Material You tonal palette out, rendered
through templates.

*Rejected:* writing our own extractor. Dawn already has one — the ffmpeg-based
hue sampler in `Accent.qml` — and it produces a single hue, not a palette. The
gap between that and a tonal system is the entire Material Color Utilities
library.

*Rejected:* `pywalfox` / `pywal`. AUR-only, Python, and superseded.

### D2 — Two sources: a wallpaper, or a seed colour

```sh
matugen image <path>       # from the wallpaper
matugen color hex <#RRGGBB>  # from a named preset
```

Both feed the same templates. Preset seeds are what make a switcher possible
without requiring a matching wallpaper for every mood.

### D3 — The default is `scheme-monochrome` on `dawn-black.png`

Verified behaviour on Dawn's shipped monochrome wallpapers:

| Scheme | `surface` | `primary` | |
|---|---|---|---|
| `scheme-tonal-spot` | `#111318` | `#adc6ff` | matugen's built-in fallback, **not** from the image |
| `scheme-monochrome` | `#131313` | `#ffffff` | true neutral |

A monochrome image yields no source colour, so `tonal-spot` falls back to the
same built-in blue for *both* shipped wallpapers — they produce byte-identical
palettes. `--fallback-color` does not help: seeding grey `#f2f2f2` returns a
cyan `#82d3e0`, because Material You's tonal generation always pushes a seed
toward some hue.

`scheme-monochrome` on `dawn-black.png` lands on a near-black surface with a
white accent, which is Dawn's original hand-tuned identity — generated rather
than hardcoded.

So Dawn ships looking like Dawn, and becomes Material You the moment the user
picks a photograph. All nine schemes remain selectable at runtime.

### D4 — `Theme.qml` becomes generated

The island's sixteen roles map onto Material You's fifty. This is the change
that makes the desktop actually themed rather than merely accented.

| Dawn role | MD3 role |
|---|---|
| `background` | `surface` |
| `surface` | `surface_container` |
| `surfaceHigh` | `surface_container_high` |
| `surfaceHighest` | `surface_container_highest` |
| `border` | `outline_variant` |
| `highlight` | `surface_container_high` |
| `shadow` | `shadow` |
| `text` | `on_surface` |
| `textSecondary` | `on_surface_variant` |
| `textTertiary` | `outline` |
| `textQuaternary` | `outline_variant` |
| `accentBase` | `primary` |
| `accentContainer` | `primary_container` |
| `onAccent` | `on_primary` |
| `danger` | `error` |
| `weekend` | `tertiary` |

**Validated across every combination.** Ten wallpapers × nine schemes = ninety
palettes, five text-on-background pairs each: 450 contrast measurements, zero
below WCAG AA 4.5, worst case 5.81. Material You's tonal system guarantees this
by construction; it was measured rather than assumed.

### D5 — `positive` and `warning` stay fixed

Material You defines `error` but has no success or warning role.

These two keep Dawn's existing `#7ec699` and `#e8c07d`. A low-battery warning
that turns blue because the wallpaper is blue has stopped communicating
urgency. Semantic colour is the one place where theming everything actively
hurts, and it is a deliberate deviation from the reference implementation.

`danger` maps to `error` because MD3's `error` is always reddish regardless of
source colour, so it stays semantically legible.

### D6 — `dawn-theme` owns reloads, not `post_hook`

matugen supports a `post_hook` per template, which is how the reference
implementation reloads applications.

**A failing `post_hook` does not fail matugen.** Verified: a hook of `exit 3`
prints `Failed executing command` and matugen still exits `0`. So a caller
cannot use matugen's exit status to learn whether the desktop actually picked
up the new colours.

Therefore `post_hook` is used only for pure file placement — symlinking a
generated file into the location an application reads. Every *reload* is
issued by `dawn-theme` after matugen returns, so failures are attributable and
reportable.

---

## Architecture

```
                   ┌──────────────┐
 wallpaper ───────►│              │
                   │  dawn-theme  │──► matugen ──► templates ──► generated
 seed colour ─────►│    (Rust)    │                                  │
                   │              │◄─────────── reload ──────────────┘
                   └──────┬───────┘
                          │
                    state: ~/.config/dawn/theme.toml
```

### Files

| Path | Role |
|---|---|
| `config/matugen/config.toml` | template declarations |
| `config/matugen/templates/*` | one per target |
| `tools/dawn-theme/` | the Rust CLI |
| `~/.config/dawn/theme.toml` | current source, scheme, mode, contrast |
| `~/.config/dawn/generated/` | rendered output |

Generated output lives under `~/.config/dawn/` — the one directory that is
writable, outside every symlink, and never touched by pacman. Writing into
`~/.config/matugen/generated` (the reference layout) would not work: that path
is inside a directory Dawn symlinks read-only from `/usr/share`.

### The CLI

```
dawn-theme wallpaper <path>        derive from an image
dawn-theme color <#RRGGBB>         derive from a seed
dawn-theme scheme <name>           one of matugen's nine
dawn-theme mode <dark|light>
dawn-theme contrast <-1.0..1.0>
dawn-theme status                  current state as JSON, for the island
dawn-theme apply                   re-render from stored state
```

Every mutating subcommand updates `theme.toml`, re-renders, and reloads. `apply`
exists so the shell can restore the palette at login without knowing how it was
chosen.

**`--prefer` is mandatory.** matugen 4.1 refuses to run on an image with
multiple candidate colours when no terminal is detected:

```
Multiple source colors found, no preference was inputted,
and a terminal was not detected.
```

`dawn-theme` always runs headless — from the island, from a hook, from a login
service — so it always passes `--prefer saturation`.

Note the reference implementation uses `--source-color-index`, which **does not
exist in matugen 4.1**. Its invocation cannot be copied.

### Templates

Confirmed rendering syntax:

| Expression | Yields |
|---|---|
| `{{colors.primary.default.hex}}` | `#ffffff` |
| `{{colors.primary.default.hex_stripped}}` | `ffffff` |
| `{{colors.primary.default.rgb}}` | `rgb(255, 255, 255)` |
| `{{mode}}` | `dark` |
| `{{image}}` | source path |

`hex_stripped` is what Hyprland's `rgb(aaacac)` form needs.

The JSON dump keys values as `.color`, not `.hex` — relevant when reading
`matugen -j hex` output, which the island does, and a real source of confusion
when writing templates against a JSON sample.

| Template | Target | Reload |
|---|---|---|
| `quickshell.qml` | island `Theme.qml` | none — Quickshell hot-reloads on file change |
| `kitty-colors.conf` | `kitty/colors/colors.conf` | `kill -USR1` on kitty |
| `rofi-colors.rasi` | `rofi/colors.rasi` | none — read at launch |
| `hyprland-colors.lua` | Hyprland border colours | `hyprctl reload` |
| `hyprlock-colors.conf` | lock screen | none — read at launch |
| `starship-colors.toml` | prompt | none — read per prompt |
| `nvim-colors.lua` | editor | none — read at launch |
| `gtk3.css`, `gtk4.css` | GTK apps | `gsettings` theme poke |
| `qtct-colors.conf` | Qt5/Qt6 apps | none — read at launch |

New runtime dependencies, all in official repositories: `matugen`,
`adw-gtk-theme`, `qt5ct`, `qt6ct`. One departs — see below. Still no AUR, and
the manifest stays the single source of truth with `check-depends.sh`
enforcing it.

### Interaction with the existing accent pipeline

`services/Accent.qml` currently derives a hue with ffmpeg and applies it to
`accentBase` alone. Once `Theme.qml` is generated, that job belongs to matugen,
and keeping both would mean two things competing to set the same colour.

`Accent.qml` is removed, along with `Config.deriveAccentFromWallpaper`,
`Config.wallpaperPath` if it has no other reader, and the accent section of the
island README. Five files reference it and all must be updated: `shell.qml`,
`theme/Theme.qml`, `Config.qml`, `modules/LauncherView.qml`, `README.md`.

**`ffmpeg` leaves `install/packages.txt` with it.** It was added solely to
sample the wallpaper for `Accent.qml`, and grep confirms no other consumer.
Dawn's manifest rule is that a package nobody can point at is how a distro gets
fat — so it is removed rather than re-justified, and the PKGBUILD's
`_dawn_depends` follows. This drops the dependency count from 31 to 30.

That trade is worth stating plainly: Dawn loses a carefully-built hue sampler,
documented at length in its own commit, in exchange for a full tonal palette
instead of a single hue. The sampler solved a smaller problem well; matugen
solves the larger one.

### Interaction with packaging

`~/.config/matugen/` would hold read-only templates *and* written-to output,
which is the case the `LINK` strategy exists for. Avoided entirely by keeping
generated output in `~/.config/dawn/generated/` and pointing matugen at it with
an explicit `--config`, so no new link strategy is needed and `matugen` never
becomes a linked application.

---

## Error handling

- **No source colour in the image** — matugen falls back. Expected for
  monochrome wallpapers; `scheme-monochrome` is the documented answer.
- **`--prefer` omitted** — matugen refuses without a TTY. Always passed.
- **A reload fails** — reported by name and the run continues. A terminal that
  will not accept `USR1` must not prevent GTK from updating.
- **matugen exits non-zero** — nothing is written, previous state stands,
  `theme.toml` is not updated.
- **A `post_hook` fails** — matugen still exits 0, so hooks are used only for
  file placement and every reload is verified by `dawn-theme` itself.
- **`theme.toml` missing or unparseable** — fall back to the shipped default
  (`scheme-monochrome`, `dawn-black.png`, dark) rather than refusing to start.

## Testing

| Layer | How |
|---|---|
| Role mapping | assert every one of the sixteen roles resolves for all nine schemes |
| Contrast | recompute the 450-pair sweep; fail if any pair drops below 4.5 |
| Template rendering | render against a fixed palette, compare to golden files |
| Monochrome fallback | assert `scheme-monochrome` on `dawn-black.png` yields a neutral `primary` |
| CLI state | `theme.toml` round-trips; `apply` reproduces a prior render byte-for-byte |
| Reload attribution | a deliberately failing reload is reported and does not abort the rest |

The contrast sweep is the important one: it is the check that stops a future
scheme or mapping change from quietly making the desktop unreadable.

## Scope

**In scope**

- `config/matugen/config.toml` and the nine templates above
- `tools/dawn-theme/` — the Rust CLI
- generating `Theme.qml`; removing `Accent.qml` and its config flag
- replacing the hardcoded colours in `decorations.lua`, `kitty/colors/`,
  `rofi/colors.rasi`
- new dependencies in `install/packages.txt` and the PKGBUILD
- packaging `dawn-theme` into `dawn-config`
- the test suite above

**Out of scope**

- the island's theme switcher UI — sub-project B
- Firefox theming — sub-project C
- light mode as a first-class experience; the templates emit it, but Dawn's
  design is dark and light is untested
- per-application opt-out

## Open questions

None blocking. One to revisit once B exists: whether `dawn-theme apply` should
run at login from a systemd user unit, or whether the island calling it on
startup is sufficient.
