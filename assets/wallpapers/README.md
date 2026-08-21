# Wallpapers

Images here are copied into `~/Pictures/Wallpapers` by `dawn link`, which is
where the island's wallpaper carousel reads from (`wallpaperDir` in
`config/quickshell/dawn-island/Config.qml`).

## What ships

| File | |
|---|---|
| `torii-ember.png` | A torii gate against a setting sun. **The default.** |
| `dawn-black.png` | Arch mark, white on black. 1920×1080. |
| `dawn-white.png` | Arch mark, black on white. 1890×1080. |

`torii-ember.png` ships as the default because a distribution named Dawn
should open on sunrise colours. Under `scheme-tonal-spot` it yields a warm
near-black surface (`#19120d`) and an amber accent (`#ffb781`).

The two Arch-mark wallpapers are deliberately monochrome, and that has a
consequence worth knowing.

## Monochrome wallpapers and the colour engine

Dawn derives its accent from the wallpaper. An image with no chroma has no
accent to give, so what happens next depends entirely on the scheme:

| Scheme | `surface` | `primary` | |
|---|---|---|---|
| `scheme-tonal-spot` | `#111318` | `#adc6ff` | matugen's built-in fallback blue — **not** from the image |
| `scheme-monochrome` | `#131313` | `#ffffff` | true neutral |

With `tonal-spot`, both files produce byte-identical palettes, because neither
yields a source colour and matugen falls back to the same default. Seeding a
grey via `--fallback-color` does not help either: Material You's tonal
generation always pushes a seed toward some hue, so `#f2f2f2` comes back as
cyan.

`scheme-monochrome` is the only route to a genuinely neutral palette, and on
`dawn-black.png` it lands on a near-black surface with a white accent — which
is Dawn's original hand-tuned identity, generated rather than hardcoded.

That is why `scheme-monochrome` exists as an option but is not the default:
it is the only way to get a genuinely neutral desktop, and the Arch-mark
wallpapers are the images it suits. It has one real cost — under monochrome
the editor colourscheme loses hue differentiation entirely, and strings come
out the same colour as ordinary text.

## Adding your own

Drop any image in here and it is seeded on a fresh install. Extensions must be
one of those listed in `wallpaperExtensions` in the island's `Config.qml`:
`png`, `jpg`, `jpeg`, `webp`, `gif`, `bmp`.

Keep the set small. These are binary files that live in git history forever,
and the accent is derived from whatever you choose anyway — so any image works
and none is privileged.
