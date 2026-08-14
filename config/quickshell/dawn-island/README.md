# dawn-island

An Apple-style Dynamic Island for Hyprland, built on Quickshell.

At rest it is a small black pill at the top of the screen showing the time.
When something happens — the volume moves, a track changes, a notification
arrives, you switch workspace — the pill *becomes* that thing: it springs to a
new shape, shows what it has to say, and springs back. Hovering it opens the
full panel: now playing on the left, clock and week strip on the right, or your
network / battery / volume when nothing is playing.

It is not a status bar with a popup underneath. There is one surface, and it
changes size.

---

## Running it

```sh
qs -p ~/.config/quickshell/dawn-island/shell.qml
```

Quickshell hot-reloads on save, so editing any file under this directory
updates the running shell immediately — no restart needed.

### Autostart

Already wired into `~/.config/hypr/modules/autostart.lua`:

```lua
hl.exec_cmd("qs -p ~/.config/quickshell/dawn-island/shell.qml")
```

waybar's autostart line is commented out in the same file, because the island
reserves an exclusive zone at the top edge and running both stacks two bars.
Uncomment it to go back.

---

## Dependencies

Everything below was already present on this machine; nothing was installed.

| Package          | Used for                                    | Required?                     |
| ---------------- | ------------------------------------------- | ----------------------------- |
| `quickshell`     | the shell itself (0.3.0)                    | yes                           |
| `hyprland`       | workspace / monitor state (0.56.2)          | yes                           |
| `pipewire`       | volume, mute, peak metering                 | yes, for volume               |
| `brightnessctl`  | reading and setting the backlight           | yes, for brightness           |
| `systemd`        | `udevadm` — backlight change events         | yes, for brightness           |
| `wl-clipboard`   | `wl-paste --watch` — copy events            | yes, for clipboard            |
| `cliphist`       | clipboard *history* for the picker          | optional                      |
| `rofi`           | the clipboard picker UI                     | optional                      |
| `networkmanager` | wifi / ethernet state                       | optional                      |
| `upower`         | battery                                     | optional                      |
| Inter            | UI typeface                                 | falls back to sans-serif      |
| JetBrainsMono NF | icon glyphs where no vector icon exists     | falls back to a missing glyph |

Every service degrades on its own: no battery, no battery row; no backlight, no
brightness pill. Nothing else stops working.

---

## Notifications

Only one process can own `org.freedesktop.Notifications`. **swaync currently
owns it**, so the island receives nothing and logs:

```
Could not register notification server ... presumably because one is already registered.
```

This is expected, not a bug. To hand notifications to the island:

1. Comment out `hl.exec_cmd("swaync")` in `~/.config/hypr/modules/autostart.lua`
2. `pkill swaync`

Quickshell claims the name automatically within a second or two — it retries
whenever the current owner disappears, so you do not need to restart the shell.
Notification banners were verified working this way; swaync was then restored.

Keep in mind the island shows a notification for a few seconds and keeps a
short in-memory history, but it is not a notification *centre*: there is no
persistent panel listing everything you missed. If you want that, keep swaync.

---

## Layout

```
shell.qml            one layer-shell window per screen, masked to the island
Config.qml           every size, duration, priority and feature switch

components/          generic, state-agnostic building blocks
  DynamicIsland.qml    the island: state → view, shape morph, interaction
  IslandSurface.qml    the black body — shape only
  ContentHost.qml      cross-fades between views, reports the size they want
  MorphBehavior.qml    the spring that drives width/height
  ArtImage, CalendarStrip, Icon, IconButton, Label, LevelBar, Marquee, Waveform

modules/             one file per thing the island can show
  IdleView             the resting pill: the time
  ExpandedView         hover panel: media (or status) + clock + calendar
  MediaPane            art, title, transport, seek — shared by two views
  ClockPane            time over the week strip
  StatusPane           network / battery / volume, when nothing is playing
  MediaView, VolumeView, BrightnessView, WorkspaceView,
  NotificationView, ClipboardView, BatteryView, NetworkView, LevelPill

services/            facts about the system; none of them know the island exists
  IslandState.qml      the state machine — priority, expiry, payloads
  EventRouter.qml      the only place that turns a fact into "show this"
  Audio, Brightness, Clipboard, Clock, Hypr, Media, Net, Notifs, Power

theme/               Theme (colour, metrics), Typography, Anim, Glyphs
```

The rule: **services announce, the router decides, modules draw.** A service
never sets the island's state and never knows what a pixel is. Adding a new
thing the island can show is one file in `modules/`, one entry in
`Config.priority`, and one `Connections` block in `EventRouter.qml`.

### The state machine

Services *request* a state for a duration rather than assigning one, because
these events genuinely overlap — music starts, you nudge the volume, a
notification lands, you switch workspace, all inside two seconds. Requests are
resolved by the priority table in `Config.qml`; when one expires the island
falls back to whatever is still active underneath rather than snapping to idle.

Expiry is one timer armed to the next deadline. An idle island schedules
nothing at all, which is why it costs **0.07% CPU** sitting still.

---

## Configuration

Everything tunable is in `Config.qml`; every colour is in `theme/Theme.qml`.
Nothing else in the project hardcodes a size, a duration or a colour.

The knobs you are most likely to want:

```qml
topMargin: 8        // 0 → flush notch with square top corners
                    // >0 → floating pill, all corners rounded
islandWidth: 124    // the resting pill
islandHeight: 28

springStiffness: 5.0    // higher = snappier
springDamping: 0.34     // higher = less bouncy; 1.0 = no overshoot
useRealSpring: true     // false → plain eased curve

volumeDuration: 1600    // how long each state stays up, ms
notificationDuration: 4500

expandOnHover: true
scrollToChangeVolume: true
```

Both `topMargin` modes are implemented and verified: `0` gives the flush notch
with square top corners growing out of the bezel, `8` gives the floating pill.

For a frosted-glass island instead of pure black, set
`Theme.backgroundOpacity` to ~0.82 and add to `hyprland.conf`:

```
layerrule = blur, dawn-island
layerrule = ignorezero, dawn-island
```

---

## Interaction

| Input                    | Result                                     |
| ------------------------ | ------------------------------------------ |
| Hover                    | opens the full panel                       |
| Left click               | pins the panel open; click again to unpin  |
| Right click              | unpins, or runs `Config.rightClickCommand` |
| Middle click             | toggle mute                                |
| Scroll                   | volume                                     |
| Click artwork transport  | previous / play-pause / next               |
| Drag the seek bar        | scrub the track                            |
| Drag the volume bar      | set volume                                 |
| Click a workspace dot    | switch to it                               |
| Click a clipboard entry  | opens the cliphist picker                  |
| Click a notification     | invokes its default action and dismisses   |

---

## Things worth knowing

**Hyprland 0.56 changed the dispatcher API.** It replaced the string grammar
with Lua, so the old `dispatch workspace 3` is now a *syntax error* rather than
a no-op — and from QML that fails completely silently. Workspace switching uses
the Lua form (`hl.dsp.focus({workspace="3"})`). On older Hyprland, set
`Config.hyprlandLuaDispatch = false`.

**Clipboard events do not come from `Quickshell.clipboardText`.** On Wayland the
compositor only sends selection offers to the client with keyboard focus, and a
layer-shell panel deliberately has none — so that property never changes. The
island runs `wl-paste --watch` instead, which uses the focus-independent
data-control protocol. This is the same reason `wl-paste` exists as a daemon.

**Clipboard previews are sanitised.** Anything matching a credential pattern
(`Config.clipboardSecretPatterns`) — or that just looks like a high-entropy blob
— is shown as `hidden — looks sensitive` instead of being rendered full-width on
a screen that might be shared. Verified with an API key.

**Qt's JS engine is not a browser's.** `String.prototype.trimEnd` does not
exist, and calling it throws *inside a binding*, which surfaces as text that
silently never renders rather than as an error. Both truncation helpers use a
regex instead.

**Media metadata is whatever the player publishes.** Firefox does not send
`mpris:length` or `mpris:artUrl` for a YouTube tab, so the seek bar and artwork
are absent there. That is the player, not the island — both degrade to a clean
layout rather than a hole. Native players (mpd, Spotify, VLC…) supply both.

---

## What is not implemented

- **Notification actions with inline replies.** The server advertises
  `inlineReplySupported: false`; the island invokes default actions only.
- **A notification centre.** Recent notifications are kept in memory
  (`Notifs.recent`, capped at 12) but there is no history panel yet.
- **Wallpaper-derived accent colour.** `Config.deriveAccentFromWallpaper`
  exists as a switch and `Theme.accent` is a single override point, but nothing
  extracts a colour yet. The shell is monochrome by design and does not need it.
- **Recording state.** Listed in the brief's state list; there is no recorder on
  this machine to detect, so no service was written for it. Adding one is a file
  in `services/` and a line in `EventRouter.qml`.
- **Per-monitor hover.** Hover and pinning are per-window (correct), but the
  contextual states are global — a volume change shows on every monitor showing
  the island. This is intentional; the alternative is per-screen state machines.
