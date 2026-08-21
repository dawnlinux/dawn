# dawn-island

An Apple-style Dynamic Island for Hyprland, built on Quickshell.

At rest it is a small black pill at the top of the screen showing the time.
When something happens — the volume moves, a track changes, a notification
arrives, you switch workspace — the pill _becomes_ that thing: it springs to a
new shape, shows what it has to say, and springs back. Hovering it opens the
full panel: now playing on the left, clock and week strip on the right, or your
wifi / bluetooth / battery / volume when nothing is playing.

It is also drivable entirely from the keyboard — see [Keyboard](#keyboard).

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

This is the default bar now. Wired into `~/.config/hypr/modules/autostart.lua`:

```lua
hl.exec_cmd("qs -p ~/.config/quickshell/dawn-island/shell.qml")
```

### Super+R restarts it

`~/.config/hypr/modules/binds.lua` now points Super+R at
`~/.config/quickshell/dawn-island/launch.sh`. The script reloads
`hyprland.conf` and restarts the shell.

You rarely need it — Quickshell hot-reloads whenever a file in this directory
changes, so editing `Config.qml` updates the running island immediately.

---

## Keyboard

The island is a pointer surface by default — hover to expand, click to pin,
scroll to change the volume. That is fine until your hands are on the keyboard,
which on a tiling desktop is nearly always, so there is a second way in.

Quickshell 0.3.0 has no `IpcHandler`, so the shell registers Hyprland global
shortcuts instead and `binds.lua` routes keys to them. The binding lives in
Hyprland, survives config reloads, and quietly does nothing when the shell isn't
running.

| Key             | Does                                                       |
| --------------- | ---------------------------------------------------------- |
| `Super+Space`   | app launcher — type to search, `↑↓` select, `⏎` launch     |
| `Super+I`       | status panel — wifi, bluetooth, battery, volume, backlight |
| `Super+Shift+W` | wallpaper carousel                                         |
| `Super+N`       | notification centre                                        |
| `Super+M`       | session menu — lock, sleep, log out, restart, shut down    |
| `Super+.`       | expanded panel, the keyboard equivalent of hovering        |

Inside the status panel:

| Key         | Does                                                                 |
| ----------- | -------------------------------------------------------------------- |
| `↑` `↓`     | move the selection (`Tab` / `Shift+Tab` also work)                   |
| `⏎`         | open the row's real tool — `nmtui` for wifi, `bluetui` for bluetooth |
| `Backspace` | switch the selected row **off** — radio off, audio muted             |
| `Ctrl`      | switch it **on** again                                               |
| `←` `→`     | slide the rows that hold a level — volume, brightness                |
| `Esc`       | close                                                                |

Three verbs rather than one toggle, deliberately. The key you press most often
should do the thing you most often want, and on a wifi row that is "show me the
networks", not "cut my connection" — so `⏎` hands off to the tool that can
actually pick a network or pair a device, and the radio switch gets its own two
keys. Unlike a toggle, both are idempotent: mashing `Backspace` leaves the radio
off rather than flapping it, and neither can be hit by muscle memory aimed at
the other.

The commands are `Config.wifiCommand` and `Config.bluetoothCommand`:

```qml
property string wifiCommand: "kitty --class floating-nmtui -e nmtui"
property string bluetoothCommand: "kitty --class floating-bluetui -e bluetui"
```

Both float via their `--class`; the matching rules are already in
`~/.config/hypr/modules/windowrules.lua`. The panel closes as it launches — the
terminal is about to take the focus anyway.

The rows are built from what the machine actually has: no battery, no battery
row; no bluetooth adapter, no bluetooth row. A row that cannot do anything —
battery is a readout — ignores all three verbs rather than closing the panel
under you.

### Colour

The island does not derive its own colours. `theme/Colors.qml` reads
`~/.config/dawn/generated/colors.json`, which `dawn-theme` renders through
matugen from the current wallpaper or a seed colour — the same palette that
colours the terminal, the launcher and the window borders.

```sh
dawn-theme wallpaper ~/Pictures/Wallpapers/lantern-line.png
dawn-theme scheme vibrant
```

`FileView` watches that file, so the island repaints the moment it changes; it
is never restarted. The defaults written into `Colors.qml` are the palette a
fresh install runs on, before `dawn-theme` has been invoked at all.

`positive` and `warning` are deliberately excluded from derivation: Material
You has no success or warning role, and a low-battery warning that changes hue
with the wallpaper has stopped communicating urgency.

See [`docs/theming.md`](../../../docs/theming.md).

### Notification centre

`Super+N`. A notification used to live for four and a half seconds and then be
gone for good — fine for a volume change, indefensible for a message that landed
while something was fullscreen. This is the other half: the same events, kept
(`Notifs.recent`, capped at 12), reachable on purpose rather than by luck.

| Key               | Does                                                   |
| ----------------- | ------------------------------------------------------ |
| `↑` `↓`           | move the selection                                     |
| `⏎`               | run the notification's default action, then dismiss it |
| `Backspace`       | dismiss the selected one                               |
| `Shift+Backspace` | clear all                                              |
| `d`               | do not disturb                                         |
| `Esc`             | close                                                  |

Same verbs as the status panel, deliberately — learning the island once should
be enough to drive all of it. Rows show the app, how long ago it arrived, the
summary and a line of body; the `⏎` hint only appears on rows that actually
carry an action, so it never promises something the notification cannot do.
Critical notifications keep their own colour even while selected.

**Do not disturb** suppresses the interruption, not the record. Notifications
still land in the list while `d` is on — silencing something by throwing it away
is how you miss the one that mattered. `Critical` urgency ignores DND entirely,
which is what that level is for: a full disk does not respect your quiet hours.

Note that arrival times are the shell's own. The freedesktop spec carries no
timestamp, so `Notifs.recent` holds `{ n, at }` wrappers rather than bare
notifications — that pair is the only place the age can live.

### Session menu

`Super+M` unfolds the notch into the same carousel the wallpapers use — two
panels that move identically are one thing to learn — but the tiles are verbs,
so each is an icon and a word rather than a picture.

Lock and Sleep fire on `⏎`. **Log Out, Restart and Shut Down ask twice**: the
first `⏎` arms the tile red and the panel says so, the second runs it, and the
arming lapses after three seconds or the moment you move off. This panel takes
exclusive keyboard focus, so a stray Enter arriving as it opens must not be able
to power the machine off — which is also why `Space` is unbound here, why it
always opens on the least destructive entry, and why hover cannot move the
selection for the first 400ms.

Log out goes through `uwsm stop` rather than killing Hyprland, because SDDM
starts this session as `uwsm start -e -D Hyprland` and the compositor is a
systemd user unit; killing it directly strands that unit.

Lock only appears when a locker is actually installed — there is none on this
machine today, so the tile is hidden until `hyprlock` or `swaylock` shows up.
Hibernate is deliberately absent: it needs swap at least the size of RAM and a
`resume=` kernel parameter, and this machine has neither, so it would suspend
and never come back.

See [KEYMAP.md](KEYMAP.md) for every binding in one place.

### One panel at a time

The launcher, the status panel, the wallpaper carousel, the notification centre
and the session menu all take exclusive keyboard focus, so only one is ever up;
opening any of them closes the others.
Clicking anywhere else closes whichever is open.

To rebind, change the keys in `~/.config/hypr/modules/binds.lua`; the shortcut
names themselves live in `Config.qml` as `launcherShortcut`, `statusShortcut`
and `islandShortcut`:

```lua
hl.bind("SUPER + SPACE",     hl.dsp.global("quickshell:launcher"))
hl.bind("SUPER + I",         hl.dsp.global("quickshell:status"))
hl.bind("SUPER + SHIFT + W", hl.dsp.global("quickshell:wallpaper"))
hl.bind("SUPER + N",         hl.dsp.global("quickshell:notifications"))
hl.bind("SUPER + M",         hl.dsp.global("quickshell:power"))
hl.bind("SUPER + PERIOD",    hl.dsp.global("quickshell:island"))
```

---

## Dependencies

Everything below was already present on this machine; nothing was installed.

| Package          | Used for                                | Required?                     |
| ---------------- | --------------------------------------- | ----------------------------- |
| `quickshell`     | the shell itself (0.3.0)                | yes                           |
| `hyprland`       | workspace / monitor state (0.56.2)      | yes                           |
| `pipewire`       | volume, mute, peak metering             | yes, for volume               |
| `brightnessctl`  | reading and setting the backlight       | yes, for brightness           |
| `systemd`        | `udevadm` — backlight change events     | yes, for brightness           |
| `wl-clipboard`   | `wl-paste --watch` — copy events        | yes, for clipboard            |
| `cliphist`       | clipboard _history_ for the picker      | optional                      |
| `rofi`           | the clipboard picker UI (not the launcher) | optional                   |
| `networkmanager` | wifi / ethernet state                   | optional                      |
| `bluez`          | bluetooth adapter and device state      | optional                      |
| `awww`           | setting the wallpaper from the carousel | optional                      |
| `upower`         | battery                                 | optional                      |
| Inter            | UI typeface                             | falls back to sans-serif      |
| JetBrainsMono NF | icon glyphs where no vector icon exists | falls back to a missing glyph |

Every service degrades on its own: no battery, no battery row; no bluetooth
adapter, no bluetooth row; no backlight, no brightness pill. Nothing else stops
working.

---

## Notifications

The island **is** the notification daemon. `services/Notifs.qml` claims
`org.freedesktop.Notifications` on the session bus, `NotificationView.qml`
draws the banners, and `NotifCenterView.qml` is the persistent centre —
Super+N, or click the badge on the island.

Only one process can own that bus name, so **no other notification daemon may
be running**. swaync, dunst and mako all win the name if they start first, and
when that happens the island logs:

```
Could not register notification server ... presumably because one is already registered.
```

and then silently receives nothing. Dawn does not install any of them; if you
add one yourself, that is the trade you are making.

Quickshell claims the name automatically within a second or two and retries
whenever the current owner disappears, so stopping a competing daemon is enough
— you do not need to restart the shell.

Set `Config.enableNotifications = false` to opt out entirely and free the bus
name for a daemon of your choosing.

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

Services _request_ a state for a duration rather than assigning one, because
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

| Input                   | Result                                     |
| ----------------------- | ------------------------------------------ |
| Hover                   | opens the full panel                       |
| Left click              | pins the panel open; click again to unpin  |
| Right click             | unpins, or runs `Config.rightClickCommand` |
| Middle click            | toggle mute                                |
| Scroll                  | volume                                     |
| Click artwork transport | previous / play-pause / next               |
| Drag the seek bar       | scrub the track                            |
| Drag the volume bar     | set volume                                 |
| Click a workspace dot   | switch to it                               |
| Click a clipboard entry | opens the cliphist picker                  |
| Click a notification    | invokes its default action and dismisses   |

---

## Things worth knowing

**Hyprland 0.56 changed the dispatcher API.** It replaced the string grammar
with Lua, so the old `dispatch workspace 3` is now a _syntax error_ rather than
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
exist, and calling it throws _inside a binding_, which surfaces as text that
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
- **Recording state.** Listed in the brief's state list; there is no recorder on
  this machine to detect, so no service was written for it. Adding one is a file
  in `services/` and a line in `EventRouter.qml`.
- **Per-monitor hover.** Hover and pinning are per-window (correct), but the
  contextual states are global — a volume change shows on every monitor showing
  the island. This is intentional; the alternative is per-screen state machines.
