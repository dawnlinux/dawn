# dawn-greet

The login screen, written in Quickshell, in dawn-island's language.

Laid out after macOS: your wallpaper edge to edge with nothing on top of it but
type. Date, then a very large thin clock, centred in the upper third; avatar,
name and password field in the lower. No card, no panel — legibility comes from
a scrim over the photograph rather than a box behind the text.

The motion is dawn's. The password field arrives as the island's 124×28 notch
and unfolds on the island's spring; a wrong password shakes it; being let in
ends with the same wipe the island uses to hand over, so the first thing you see
at boot is the last thing you were looking at when you shut down.

## The wallpaper

The background is whatever wallpaper is currently on your desktop, resolved down
a chain, most-live first:

1. **`awww query`** — correct and current, but only where a daemon is already
   running. That is the demo case, inside your own session.
2. **A pointer file** — one path in a plain text file, written by the island
   every time you pick a wallpaper (`Config.wallpaperPointer`, default
   `/var/lib/dawn/wallpaper`). This is the greetd case.
3. **Nothing** — the aurora draws instead. A greeter whose wallpaper path moved
   must still be a greeter, not a black screen you cannot log in to fix.

The pointer file exists because the greeter runs as the unprivileged `greeter`
user: it cannot read your home directory and has no awww daemon to ask.
`install.sh` creates `/var/lib/dawn` for it, owned by you and readable by
everyone.

A pointer alone is not enough, though, and this is the part that used to be
wrong. `greeter` cannot *traverse* a 0700 home directory, so a path into
`~/Pictures` names a file it may not open however that file itself is chmodded —
the login screen fell back to the aurora every time and looked simply
uninformed. So the island **copies** the image next to the pointer, as
`/var/lib/dawn/current.<ext>`, and the pointer names the copy. The alternative
is opening your home directory to every local account, which is a much larger
change than a login screen is worth.

That happens every time you pick a wallpaper from `Super+Shift+W`, and once more
whenever the island starts — otherwise a wallpaper set before any of this
existed would never reach the greeter at all. Both writes are best-effort and
silent: failing to inform the login screen is not a reason to fail setting your
wallpaper.

The upshot is that wallpapers can stay in `~/Pictures/Wallpapers` and your home
directory stays `0700`.

---

## It cannot run under SDDM

SDDM greeters are QML, but they run *inside* SDDM's own greeter process against
SDDM's QML API. Quickshell is a separate binary and a Wayland client; SDDM has
no way to host it, and Quickshell has no way to speak SDDM's protocol.

The supported path for a custom Wayland greeter is **greetd**: a tiny daemon
that owns the PAM conversation and exposes it over a socket. greetd starts a
compositor as an unprivileged greeter user, that compositor starts this shell,
and `Quickshell.Services.Greetd` talks to the socket. That is what `Auth.qml`
does.

So installing this means replacing SDDM with greetd. **That is the risky part**
— get it wrong and you boot to a black screen — so the steps below include the
way back, and you should read them before running any of them.

---

## Try it first, safely

```sh
qs -p ~/.config/quickshell/dawn-greet/shell.qml
```

`Greetd.available` is false in an ordinary session, so `Auth` falls into **demo
mode**: any password is accepted except the literal word `wrong`, which plays
the refusal animation. `Esc` quits, at any point.

Demo mode has no session to hand over to, so it exits once the wipe has covered
the screen — that exit *is* the handover, standing in for greetd taking the
machine away. It has to end somehow: a demo that plays the wipe and then simply
stops leaves a grey rectangle over your desktop holding exclusive keyboard
focus, and the only way out is killing `qs` from another TTY.

Demo mode is chosen by the environment, never by a config flag. A greeter with a
setting that makes it accept any password is a greeter with a backdoor; if
greetd is absent there is no session to unlock in the first place.

Note this takes the whole screen and the keyboard while it runs — it is a
fullscreen overlay, because that is what a login screen is.

---

## Installing it

```sh
sudo ../../greetd/install.sh
```

That is the whole thing. It installs greetd, copies this directory to
`/etc/greetd/dawn-greet` where the `greeter` user can read it, writes
`/etc/greetd/config.toml` and `/etc/greetd/hyprland.conf` from the tracked
copies in `config/greetd/`, creates `/var/lib/dawn` for the wallpaper, disables
SDDM and enables greetd. Re-run it after editing any of the QML to push the
changes to `/etc/greetd`.

Two things it deliberately does not do:

- **It never stops SDDM.** Switching display managers is disabling one unit and
  enabling another; it lands at the next boot. Stopping SDDM from inside your
  session kills the desktop you would need in order to fix anything that went
  wrong.
- **It never removes SDDM.** SDDM is the way back, and a way back has to still
  be installed to be one.

### On the greeter's config format

Hyprland 0.56 reads **both** Lua and hyprlang, and picks by file extension —
`~/.config/hypr/hyprland.lua` is Lua, `/etc/greetd/hyprland.conf` is hyprlang.
Either works; the greeter's is hyprlang because it is forty lines of flat
settings with no logic in it, and hyprlang is the smaller thing to be wrong
about. If you would rather keep one language across the whole setup, rename it
`.lua` and rewrite it in the `hl.*` API — Hyprland logs which manager it loaded
(`Config is NOT lua, loading regular mgr`) so you can tell what it decided.

An unrecognised key does not get ignored either way: it raises the config-error
overlay, on top of the login screen, where you cannot dismiss it. So every
option in `config/greetd/hyprland.conf` was checked against the running Hyprland
with `hyprctl getoption` before being written down — which caught `misc:vfr`,
gone in 0.56. Before installing any change to it:

```sh
Hyprland --verify-config -c /etc/greetd/hyprland.conf
```

That parses the config and exits without starting a compositor.

`Auth.user` reads `$USER`, which under greetd is `greeter`, not you —
authenticating as `greeter` fails every time with a PAM message that explains
nothing. It refuses to use `greeter` or `root` for that reason, so you must say
who you are. Either set it in the greetd session command:

```toml
command = "env DAWN_GREET_USER=jhayonline Hyprland -c /etc/greetd/dawn-greet.lua"
```

…or hardcode it in `Auth.qml`:

```qml
property string loginUser: "jhayonline"
```

### Testing it

**Do not reboot to test.** Switch to a TTY and restart the display manager from
there, so a failure leaves you at a working prompt instead of a black screen:

```sh
# Ctrl+Alt+F2, log in
sudo systemctl stop sddm && sudo systemctl start greetd
```

Stopping SDDM ends your desktop session, so save first.

### The way back

From any TTY (`Ctrl+Alt+F2`):

```sh
sudo /path/to/dawn/config/greetd/install.sh --revert
sudo systemctl start sddm
```

SDDM is not removed by any of the above, so this always works. If greetd starts
but the greeter never draws, `journalctl -u greetd -b` has the reason — usually
a path the `greeter` user cannot read.

---

## Files

| File | What it is |
| --- | --- |
| `shell.qml` | Root. Wallpaper, scrim, clock, power; one layer per screen, controls only on the first |
| `UserPanel.qml` | Avatar, name, and the notch that unfolds into the password field |
| `Wall.qml` | Resolves which wallpaper to show, down the chain above |
| `Aurora.qml` | Fallback background — three drifting radial fields and a vignette |
| `Auth.qml` | greetd conversation, and the demo fallback |
| `Theme.qml` | Colours, type and spring values, matched to dawn-island |

`Theme.qml` is a deliberate copy of the island's values rather than an import of
them: the greeter runs as a different user, in a different compositor, before
the island exists. A shared module would be a dependency across a boundary that
cannot be crossed — two files agreeing on `#161616` is the cheaper problem.

## Tuning

- **Layout** — the two `topMargin` fractions in `shell.qml`: `0.11` for the
  clock, `0.70` for the user. Those two numbers are the whole composition.
- **Scrim** — the gradient stops in `shell.qml`. This is what makes white type
  legible over an arbitrary photograph; darken the ends before you reach for a
  panel behind the text.
- **Type scale** — `Theme.clock` (132px, Light) and `Theme.date`. The clock is
  thin on purpose: at that size, weight reads as shouting.
- **Entrance timing** — the `entrance` sequence in `shell.qml`. The pauses *are*
  the animation.
- **Spring feel** — `Theme.springStiffness` / `springDamping` / `springMass`,
  the same numbers as the island's `Config.qml`.
- **Handover** — the `handover` sequence in `shell.qml`. Its one pause is 240ms,
  and it is the only thing standing between PAM being satisfied and greetd being
  told to start your session, so treat it as a latency budget rather than a
  timing knob. Everything after it happens on top of a session that is already
  coming up and is therefore free; the pause itself is not.

## Why login is fast

The handover used to be in series with the session: dwell 460ms at pill size,
grow for 700ms, *then* call `Greetd.launch()`. Nothing was starting during that
1160ms — it was animation with the machine idle behind it.

It is inverted now. The wipe covers the screen on the island's spring, and as
soon as it has covered — 240ms — greetd is told to go. The rest of the wipe, and
all of Hyprland's startup, happen underneath a screen that is already `#161616`,
which is the colour the session comes up on anyway. The animation costs nothing
because it is no longer in front of anything.

The greeter times itself and prints the segments, so if login ever feels slow
you can find out where it actually went rather than guessing:

```
[dawn-greet] +0ms submit → greetd createSession(jhayonline)
[dawn-greet] +312ms PAM satisfied
[dawn-greet] +553ms → greetd.launch uwsm start -e -D Hyprland hyprland.desktop
[dawn-greet] +561ms greetd launched the session
```

Under greetd those land in `journalctl -u greetd -b`. Note that `uwsm start`
itself costs about 160ms generating units before Hyprland is even executed; that
is uwsm's, not the greeter's, and it is not worth chasing.

## When the handover fails

If greetd never takes the machine away, the wipe would otherwise sit there as a
grey rectangle holding exclusive keyboard focus, with no way out but killing
`qs` from a TTY. Eight seconds after handing over, the greeter says so on the
wipe itself — the session command it tried, and where to look. A login screen is
not allowed to fail silently.
