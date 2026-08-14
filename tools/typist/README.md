# typist

A minimal typing test for Wayland. One line of text, a caret, and a score.

Written against the compositor directly — no toolkit, no browser, no GPU
context. It renders in software straight into the buffer it shares with the
compositor, and leaves its surface transparent so the compositor's own blur is
what gives the panel its depth.

```
              8/9

  the quick brown fox jumps over the lazy dog
                             ^
```

## Use

```sh
typist            # 25 words
typist -w 50      # 50 words
typist -t 30      # 30 seconds
```

The clock starts on your first keystroke, not on launch.

| key | |
| --- | --- |
| `tab` | restart with new words |
| `enter` | next test, from the results screen |
| `backspace` | fix the last character |
| `ctrl+backspace` | fix the last word |
| `esc` | quit |

Mistakes are shown in red at the position you made them and the caret moves on
regardless, so the line never shifts under you. Words-per-minute is net of
errors, on the usual five-characters-to-a-word convention. Accuracy is measured
over keystrokes, so correcting a mistake fixes the text but not the score.

## Build

```sh
cargo build --release
install -Dm755 target/release/typist ~/.local/bin/typist
```

Fonts are found through fontconfig at runtime — JetBrains Mono for the prompt
and Inter for the interface, each falling back to the generic `monospace` and
`sans-serif` families. The resolved paths are cached under
`~/.cache/typist/fonts`; delete that file after changing fonts.

## Hyprland

The app draws its own translucent panel and hairline border, so the compositor
should supply only the blur behind it:

```lua
hl.window_rule({
	name        = "float-typist",
	match       = { class = "^(typist)$" },
	float       = true,
	size        = { 1100, 620 },
	center      = true,
	rounding    = 16,
	border_size = 0,
	opacity     = 1.0,
	animation   = "popin",
})
```

`rounding` should match `theme::RADIUS` so the compositor clips exactly where
the panel's own corners end. `opacity = 1.0` matters if you set a global window
opacity: without it the compositor dims the text as well as the backdrop, and
the app's own alpha stops being the only thing deciding how see-through it is.

Blur needs to be on globally (`decoration.blur.enabled`); it applies to this
window automatically because the surface is translucent.

For a keybind:

```lua
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("typist"),
	{ description = "Typing Test" })
```

Without any of this it still runs — it just sits wherever your layout puts it,
with whatever border and rounding your compositor gives every other window.

## How it works

| | |
| --- | --- |
| `main.rs` | Wayland surface, input, and the redraw loop |
| `state.rs` | the test: target text, what was typed, and the score |
| `render.rs` | drawing both screens |
| `text.rs` | font resolution, glyph cache, blitting |
| `theme.rs` | colours and the proportions the layout derives from |
| `words.rs` | the word pool and a small PRNG |

Three things are worth knowing if you change it.

**It renders into the shm buffer directly.** `wl_shm`'s `ARGB8888` is a
little-endian word, so its bytes run B, G, R, A, while the rasterizer writes
R, G, B, A. Rather than a fix-up pass over several megabytes every frame, the
red and blue channels are swapped at the two points where colours reach memory:
`Rgba::to_color` and `text::blit`. If a colour comes out looking wrong, that is
the first place to look.

**Glyphs are rasterized lazily.** A Nerd Font carries thousands of icon glyphs
this app never draws. A rasterizer that expands them all at load time costs tens
of megabytes of resident memory for nothing, so outlines are only produced on
first use and then cached per character and size. Font files are read once and
shared between the faces that live in the same collection.

**It only draws when something changed.** There is no render loop. A frame is
produced on a keystroke, while the caret or scroll is still moving, or when the
caret blinks — and each one waits for the compositor's frame callback. Sitting
at the results screen costs a couple of wakeups a second and no drawing at all.

Sizes derive from the window height rather than being fixed, so the layout holds
its proportions at any size and on any display scale; the height is capped
against the width so a tall, narrow window does not render enormous text.

```sh
cargo test    # the scoring rules and the input model
```
