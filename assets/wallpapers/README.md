# Wallpapers

Images here are copied into `~/Pictures/Wallpapers` by `dawn link`, which is
where the island's wallpaper carousel reads from (`wallpaperDir` in
`config/quickshell/dawn-island/Config.qml`).

## What ships

| File | |
|---|---|
| `dawn-black.png` | Arch mark, white on black. 1920×1080. The default. |
| `dawn-white.png` | Arch mark, black on white. 1890×1080. |

Both are deliberately monochrome, and that has a consequence worth knowing.

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

That pairing is why these ship: out of the box Dawn looks like Dawn, and the
moment you pick a photograph it becomes Material You.

## Adding your own

Drop any image in here and it is seeded on a fresh install. Extensions must be
one of those listed in `wallpaperExtensions` in the island's `Config.qml`:
`png`, `jpg`, `jpeg`, `webp`, `gif`, `bmp`.

Keep the set small. These are binary files that live in git history forever,
and the accent is derived from whatever you choose anyway — so any image works
and none is privileged.
