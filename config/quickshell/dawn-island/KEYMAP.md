# dawn-island — keymap

Every binding the island responds to, in one place.

They live in two files that cannot see each other — `binds.lua` holds the
Hyprland side, the QML views hold the in-panel handlers — so this is the only
place that can answer "what does this key do" or show a collision before you
ship one. **Any keymap change belongs here as part of the change, not after it.**

- Global shortcuts: `~/.config/hypr/modules/binds.lua` → `shell.qml`
- In-panel keys: the `Keys` handlers in `modules/*View.qml`

---

## Opening things

Hyprland routes these to global shortcuts the shell registers. They work from
anywhere, and do nothing at all when the shell isn't running.

| Key | Opens | Shortcut name |
| --- | --- | --- |
| `Super+Space` | App launcher | `quickshell:launcher` |
| `Super+I` | Status panel | `quickshell:status` |
| `Super+N` | Notification centre | `quickshell:notifications` |
| `Super+Shift+W` | Wallpaper carousel | `quickshell:wallpaper` |
| `Super+.` | Expanded panel — the keyboard equivalent of hovering | `quickshell:island` |
| `Super+R` | Restart the shell (runs `launch.sh`) | — (plain `exec`) |

Each key toggles: pressing it again closes what it opened.

Only one panel is ever up. The launcher, status panel, notification centre and
wallpaper carousel all take exclusive keyboard focus, so opening any of them
closes the others; clicking anywhere else closes whichever is open.

---

## Inside the panels

### Everywhere

| Key | Does |
| --- | --- |
| `Esc` | Close |
| `Tab` / `Shift+Tab` | Next / previous |

### Vim keys

`hjkl` work **alongside** the arrows in every panel except the launcher — both
sets are live at once, so neither habit is wrong. Same axes vim uses: `jk` move
along a list, `hl` move along a level or a row of tiles.

The launcher is the exception on purpose: it has a text field, so `j` has to
mean the letter j.

| Panel | `h` | `j` | `k` | `l` |
| --- | --- | --- | --- | --- |
| Status panel | adjust down | move down | move up | adjust up |
| Notification centre | — | move down | move up | — |
| Wallpaper carousel | previous | next | previous | next |
| App launcher | *types the letter* | | | |

In the carousel `jk` are synonyms for `hl` rather than dead keys — the axis is
horizontal and there is no second one for them to mean.

### App launcher — `Super+Space`

| Key | Does |
| --- | --- |
| *any text* | Filter |
| `↑` `↓` | Move the selection |
| `⏎` | Launch |
| `Esc` | Close |

Ranking is by *where* the match lands, not fuzzy subsequence: a name starting
with the query beats a word inside the name, which beats the description.

### Status panel — `Super+I`

Rows: Wi-Fi, Bluetooth, Battery, Volume, Brightness — whichever the machine
actually has.

| Key | Does |
| --- | --- |
| `↑` `↓` / `k` `j` | Move the selection |
| `⏎` | Open the row's real tool — `nmtui` for wifi, `bluetui` for bluetooth; toggles mute on Volume |
| `Backspace` | Switch the selected row **off** — radio off, audio muted |
| `Ctrl` | Switch it **on** again |
| `←` `→` / `h` `l` | Slide the rows that hold a level — Volume, Brightness |
| `Esc` | Close |

Three verbs rather than one toggle. The key you press most often should do the
thing you most often want, and on a wifi row that is "show me the networks", not
"cut my connection". Off and on get their own keys, so neither can be hit by
muscle memory aimed at the other, and both are idempotent — mashing `Backspace`
leaves the radio off rather than flapping it.

Battery is a readout: it ignores all three verbs rather than closing the panel
under you.

### Notification centre — `Super+N`

| Key | Does |
| --- | --- |
| `↑` `↓` / `k` `j` | Move the selection |
| `⏎` | Run the notification's default action, then dismiss it |
| `Backspace` | Dismiss the selected one |
| `Shift+Backspace` | Clear all |
| `d` | Do not disturb |
| `Esc` | Close |

DND suppresses the interruption, not the record — notifications still land in
the list while it is on. `Critical` urgency ignores DND entirely.

### Wallpaper carousel — `Super+Shift+W`

| Key | Does |
| --- | --- |
| `←` `→` / `h` `l` / `k` `j` | Browse (wraps) |
| `⏎` | Set the centred wallpaper |
| `Tab` / `Shift+Tab` | Next / previous |
| `Esc` | Close |

---

## Pointer

Not keys, but the same surface.

| Input | Does |
| --- | --- |
| Hover the notch | Expands to the panel |
| Left click | Pin / unpin the expanded panel |
| Right click | Close the open panel, or unpin |
| Middle click | Toggle mute |
| Scroll | Volume — or the carousel, one tile per notch, while it is open |

Inside a panel, hovering a row moves the keyboard selection to it, so the two
never disagree about what `⏎` would do. In the carousel, clicking a tile selects
it and clicking the already-centred tile applies it — the pointer can never set
a wallpaper you hadn't looked at.

---

## Collisions to know about

These are Hyprland binds that sit next to the island's and are easy to confuse:

| Key | Owner | Does |
| --- | --- | --- |
| `Super+W` | Hyprland | Close window — *not* the wallpaper carousel (`Super+Shift+W`) |
| `Super+N` | dawn-island | Notification centre — was swaync until swaync was retired |
| `Super+R` | dawn-island | Restart the shell — rarely needed, Quickshell hot-reloads on save |

To rebind anything, change the key in `binds.lua`; the shortcut *names*
(`quickshell:launcher` and friends) are defined in `Config.qml` and should stay
as they are.
