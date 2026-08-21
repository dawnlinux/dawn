<div align="center">

# dawn

**Dawn is the moment where darkness meets light — not the absence of darkness, but its transformation.**

A Linux desktop built on Arch, Hyprland and Quickshell.

</div>

---

Dawn is built around one idea: the balance between minimalism and beauty,
between power and elegance, between night and the beginning of something new.

In practice that means a desktop where **one process draws the interface**.
The status bar, the app launcher, the notification centre, the media controls,
the clipboard history, the wallpaper carousel and the session menu are not six
programs stitched together with scripts — they are `dawn-island`, a single
Quickshell surface at the top of the screen that expands into whatever you
asked for.

Dawn is where your system comes to life.

---

## Requirements

- An existing **Arch Linux** install (or an Arch derivative with `pacman`)
- A machine that can run Wayland

That is all. **Dawn has no AUR dependencies** — every one of its 31 packages
comes from the official repositories, so there is no AUR helper to install, to
trust, or to break an install halfway through.

## Install

```sh
git clone https://github.com/dawnlinux/dawn
cd dawn
./install.sh
```

See exactly what it will do first with `./install.sh --dry-run`.

The bootstrap does four things and nothing else:

1. imports and locally signs the Dawn package signing key
2. adds the `[dawn]` repository to `/etc/pacman.conf`
3. `pacman -Sy dawn`
4. `dawn link`

After that, **Dawn updates like everything else on the system**:

```sh
sudo pacman -Syu
```

### Doing it by hand

```sh
sudo pacman-key --recv-keys C36BACF174290B6ED5456879BCB1F6ACA2DD7A59
sudo pacman-key --lsign-key C36BACF174290B6ED5456879BCB1F6ACA2DD7A59
```

```ini
# /etc/pacman.conf
[dawn]
SigLevel = Required DatabaseOptional
Server = https://dawnlinux.github.io/repo/$arch
```

```sh
sudo pacman -Sy dawn && dawn link
```

Packages are signed and `SigLevel = Required`, so pacman refuses anything not
signed by that key.

### The `dawn` command

Configuration is installed to `/usr/share/dawn/config` and symlinked into
`~/.config`, which is what lets `pacman -Syu` update the running desktop with
no merge step. `dawn` owns those links:

| Command | Effect |
|---|---|
| `dawn link` | point `~/.config` at the packaged config |
| `dawn dev <repo>` | point it at a checkout instead, for hacking on Dawn |
| `dawn status` | which mode you are in, and every link |
| `dawn unlink` | remove Dawn's links and restore backups |

Nothing is ever deleted — anything occupying a link target is moved to
`~/.dawn-backup/<timestamp>/`.

How all of this fits together: [`docs/packaging.md`](docs/packaging.md).

## The login screen

`dawn-greet` is Dawn's greeter — the same Quickshell design language as the
desktop, running under greetd. It is **not** installed by `install.sh`, because
replacing a display manager is the one change that can leave you staring at a
black screen with no way in.

It has its own installer, which never stops your running session, never removes
your existing display manager, and reverts in one command:

```sh
sudo ./config/greetd/install.sh
sudo ./config/greetd/install.sh --revert   # the way back
```

Details and the recovery procedure: [`config/quickshell/dawn-greet/README.md`](config/quickshell/dawn-greet/README.md).

## Making it yours

Dawn separates **shipped config** from **your machine**. Two files are
gitignored, seeded on install, and loaded last so they override everything:

| File | For |
|---|---|
| `~/.config/dawn/local.lua` | monitor modes, GPU driver hints, vendor keybinds, per-host autostart |
| `~/.config/dawn/local.fish` | personal aliases, extra `PATH` entries, secrets |

Both are seeded from `/usr/share/dawn/examples/` on your first `dawn link`
and never overwritten afterwards. They live in `~/.config/dawn/`, outside
every symlink Dawn creates, so `pacman -Syu` can never touch them — and
because they load last, you never have to fork a shipped file to change one
line.

Hardware-specific settings belong there, **not** in the shared modules. A
`LIBVA_DRIVER_NAME` that is right for one GPU is wrong for every other.

## What's in here

```
install.sh                    the bootstrap — adds the repo, installs Dawn
install/packages.txt          every dependency, with a reason for each

config/
  hypr/                       Hyprland, split into modules by concern
    hyprland.lua              entry point; loads ~/.config/dawn/local.lua last
    modules/                  binds, monitors, decorations, autostart, ...
  quickshell/
    dawn-island/              the shell — bar, launcher, notifications,
                              media, clipboard, wallpapers, session menu
    dawn-greet/               the login screen
  greetd/                     greetd config + its own reversible installer
  fish/  kitty/  rofi/  nvim/ shell, terminal, clipboard picker, editor

examples/                     seed sources for ~/.config/dawn

packaging/
  PKGBUILD                    builds dawn, dawn-config, dawn-typist
  dawn                        the link manager installed to /usr/bin/dawn
  release.sh                  build → sign → assemble the pacman repo
  check-depends.sh            fails the build if deps drift from the manifest

tests/                        bats suites for the CLI and the drift check

tools/
  typist/                     a lightweight typing-speed test

assets/                       branding, and wallpapers to seed on install

docs/
  packaging.md                how the packaging and link system works
  superpowers/                design specs and implementation plans
```

Keybindings live in
[`config/quickshell/dawn-island/KEYMAP.md`](config/quickshell/dawn-island/KEYMAP.md).

## Design decisions

**One shell, not six programs.** No waybar, no swaync, no wofi, no wlogout.
`dawn-island` owns the bar, the launcher, notifications, the power menu and the
wallpaper switcher. Fewer processes, one design language, one place to change
a colour.

**One palette.** Dawn does not ship a theme switcher. The interface is
monochrome and the *colour* comes from your wallpaper — `Accent.qml` samples
the image you picked and everything follows. A wallpaper you like is a better
theme than a theme you picked from a list.

**Rofi draws one thing.** The clipboard picker, because `rofi -dmenu` is still
the fastest way to build one. It is not the app launcher; the island draws its
own.

**Nothing in the repo that nothing uses.** If you cannot point at what needs a
file, it does not belong here.

## Uninstall

```sh
./install.sh --uninstall
```

Symlinks are removed and the most recent backup is restored. Packages are left
alone — they are ordinary Arch packages, and removing them is your call. If you
switched to dawn-greet, revert that separately with the command above.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">
<sub>Built on <a href="https://hypr.land">Hyprland</a> and <a href="https://quickshell.org">Quickshell</a>.</sub>
</div>
