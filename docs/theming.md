# How Dawn is coloured

Every colour in Dawn comes from one source — a wallpaper, or a seed colour —
through [matugen](https://github.com/InioX/matugen), which implements Google's
Material Color Utilities.

```
wallpaper ─┐
           ├─> dawn-theme ─> matugen ─> templates ─> ~/.config/dawn/generated/
seed hex ──┘        │                                          │
                    └────────────── reload ────────────────────┘
```

## Using it

```sh
dawn-theme wallpaper ~/Pictures/Wallpapers/lantern-line.png
dawn-theme color '#7ec699'
dawn-theme scheme vibrant
dawn-theme mode light
dawn-theme contrast 0.3
dawn-theme status          # current state, as JSON
dawn-theme apply           # re-render from stored state
```

`dawn-theme wallpaper` both **sets** the wallpaper and themes from it. Pass
`--no-set` to derive colours from an image without putting it on screen — but
the default is deliberate: a palette taken from an image you cannot see is
worse than no palette at all.

State lives in `~/.config/dawn/theme.toml`. A missing or corrupt file falls
back to the shipped default rather than leaving you without a desktop.

## What follows the palette, and how quickly

| Surface | Updates | Mechanism |
|---|---|---|
| dawn-island | **live** | `FileView` watches `colors.json` |
| Hyprland | **live** | `dawn-theme` runs `hyprctl reload` |
| kitty | **live** | `dawn-theme` sends `SIGUSR1` |
| Neovim | **live** | `fs_event` watch, while `dawn` is the active scheme |
| rofi | next launch | re-reads its theme every time it is invoked |

Not yet themed: GTK, Qt, hyprlock, starship. See *Adding a target* below —
each needs its own template and none of them blocks the engine.

## The default

`torii-ember.png` under `scheme-tonal-spot`: a warm near-black surface
(`#19120d`) with an amber accent (`#ffb781`). A distribution named Dawn should
open on sunrise colours.

The fallback values compiled into `Colors.qml`, `decorations.lua` and
`colors/dawn.lua` are *exactly* what that combination produces, so a fresh
install looks identical before and after `dawn-theme` first runs.

### Why not monochrome

`scheme-monochrome` was the default while `dawn-black.png` was — a monochrome
image yields no source colour, and monochrome is the only scheme that handles
that cleanly rather than falling back to matugen's built-in blue. It remains
the right choice if you set one of the Arch-mark wallpapers.

It costs the editor, though. Under monochrome, `primary`, `secondary` and
`tertiary` collapse to three near-identical light greys:

```
monochrome    Normal #e2e2e2   String #e2e2e2   ← the same colour
tonal-spot    Function amber / String olive / Keyword sand
```

Strings come out indistinguishable from ordinary text. There are only three
usable greys in the palette, so no mapping fixes it.

## Neovim

`dawn` is the default colourscheme and one entry in the picker beside the other
56. Switch with `:Theme <name>` or `<leader>ts`; a bare `:colorscheme` works
too and is persisted.

It is **minimal on purpose** — about twenty highlight groups, no Treesitter or
LSP semantic groups yet. It was written to answer whether a wallpaper-derived
syntax theme is readable at all before more went into it. If it holds up, the
rest are mechanical from the same palette.

While `dawn` is active it watches the generated palette and re-applies itself,
so the editor tracks the desktop. Selecting another scheme tears the watch
down — a watcher outliving its scheme would drag you back to `dawn` every time
the palette moved.

## Adding a target

1. Write a template in `config/matugen/templates/`
2. Declare it in `config/matugen/config.toml`
3. If the application needs a reload, add it to `RELOADS` in
   `tools/dawn-theme/src/reload.rs` — **not** as a `post_hook`
4. Run `dawn link` so the template is seeded into `~/.config/dawn/templates/`

Template syntax:

| Expression | Yields |
|---|---|
| `{{colors.primary.default.hex}}` | `#ffb781` |
| `{{colors.primary.default.hex_stripped}}` | `ffb781` — Hyprland's `rgb()` form |
| `{{colors.primary.default.rgb}}` | `rgb(255, 183, 129)` |

The `matugen -j hex` JSON dump keys values as `.color`, not `.hex`. Writing a
template against a JSON sample is the easiest way to get this wrong.

## Constraints worth knowing before you extend it

**`post_hook` is for file placement only.** A failing `post_hook` does not fail
matugen — it prints an error and matugen still exits `0` — so a reload issued
there fails invisibly. Every reload is run by `dawn-theme` and reported by name.

**`--prefer` is mandatory.** matugen 4.1 refuses to run on a multi-colour image
with no terminal attached. `dawn-theme` always passes `--prefer saturation`
because it is always headless.

**Generated files cannot live beside the config they colour.** In a packaged
install `/usr/share/dawn/config/...` is root-owned and read-only, and
`~/.config/kitty` is a symlink straight into it. So the island reads *data*
(`colors.json`) rather than generated QML, and kitty and rofi include the
generated file by absolute path from `~/.config/dawn/generated/`.

**Include order matters.** kitty and rofi both let the *last* definition win,
so the shipped fallback is included first and the generated palette second.
Reversing them silently disables theming entirely.

**Avoid matugen's `base16` output.** It looks purpose-built for syntax, but it
is identical across all nine schemes and has no contrast guarantee — on
`dawn-black.png` it yields `base0b #080808` and `base0d #000000`, invisible on
the background. The Material You roles are contrast-safe by construction.

## What is never themed

`positive` (`#7ec699`) and `warning` (`#e8c07d`) are fixed everywhere — the
island, the editor, diagnostics. Material You defines an `error` role but has
no success or warning role, and a low-battery warning that turns blue because
the wallpaper is blue has stopped communicating urgency.

`danger` maps to `error`, which Material You keeps reddish in every scheme, so
it stays semantically legible.

## Contrast

```sh
./tests/contrast-sweep.sh
```

Every wallpaper against all nine schemes, five text-on-background pairs each,
failing if any drops below WCAG AA 4.5. Run it after changing the role mapping
in `config/matugen/templates/dawn-colors.json` — it is what stops a mapping
change from quietly making the desktop unreadable.

It takes a couple of minutes: one matugen invocation per wallpaper × scheme.
Exit codes are distinct — `0` pass, `1` a pair below the floor, `2` the sweep
could not run.
