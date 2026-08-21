# How Dawn is packaged

Dawn ships as three signed pacman packages served from a GitHub Pages
repository. This document explains how that works, why it is shaped this way,
and the non-obvious problems it had to solve.

For the release *procedure*, see [`packaging/README.md`](../packaging/README.md).
For the design rationale and rejected alternatives, see the
[design spec](superpowers/specs/2026-08-21-packaging-design.md).

---

## The problem it solves

Dawn used to install by cloning the repository and running a script that
symlinked `config/<name>` into `~/.config/<name>`. That meant updating Dawn was
`git pull` plus remembering to re-run the installer, every user carried a full
git checkout as a runtime dependency, and dependencies were installed by a
shell loop rather than resolved by the package manager.

The goal was `pacman -Syu` updating the desktop the same way it updates
everything else.

---

## The three packages

| Package | Arch | Contents |
|---|---|---|
| `dawn` | any | meta — depends on `dawn-config` plus the 31 runtime packages |
| `dawn-config` | any | `/usr/share/dawn/`, `/usr/bin/dawn` |
| `dawn-typist` | x86_64 | `/usr/bin/typist` |

All three come from one split `PKGBUILD` (`pkgbase=dawn`), so a single build
produces the set.

`pacman -S dawn` installs the whole desktop. `pacman -S dawn-typist` installs
just the typing test — the split exists so that adding another tool later does
not grow the desktop package.

**All three share one `pkgver`,** taken from the git tag. A split PKGBUILD
cannot version its packages independently; `pkgver` belongs to `pkgbase`. So
typist versions with Dawn. That is accepted: it ships as part of Dawn, and a
separate PKGBUILD purely for an independent version number would duplicate the
release pipeline.

---

## How configuration reaches your home directory

This is the core mechanism, and the part with the most hidden complexity.

`dawn-config` installs the config tree to `/usr/share/dawn/config`, owned by
pacman and read-only to you. `/usr/bin/dawn` then symlinks it into
`~/.config`. Because those are symlinks, `pacman -Syu` updates the running
desktop instantly — no merge step, no migration scripts, no per-release upgrade
logic.

```
/usr/share/dawn/config/     the config tree, root-owned
/usr/share/dawn/examples/   seed sources for ~/.config/dawn
/usr/share/dawn/greetd/     greetd config and its own installer
/usr/bin/dawn               the link manager

~/.config/dawn/             your overrides — pacman never touches this
~/.config/<app>             symlinks into /usr/share/dawn/config
~/.dawn-backup/<timestamp>/ whatever the CLI displaced
```

### Three link strategies, because one is not enough

The obvious design — symlink every config directory — breaks for three
applications, because **they write into their own configuration directory**:

| File | Written by | When |
|---|---|---|
| `fish_variables` | fish | every `set -U` |
| `lazy-lock.json` | lazy.nvim | every `:Lazy update` |
| `.qmlls.ini` | Quickshell's QML language server | on use |

A read-only symlinked directory makes all three fail. So each application
declares how it is linked:

| Strategy | Behaviour | Applies to |
|---|---|---|
| `DIR` | symlink the entry wholesale | `hypr`, `kitty`, `rofi`, `starship.toml` |
| `LINK` | real directory; symlink only the entries Dawn owns | `fish`, `nvim`, `quickshell` |
| `SEED` | copy once if absent, never overwrite | `local.lua`, `local.fish`, `lazy-lock.json` |

`DIR` covers files as well as directories — `starship.toml` is a single file,
and `ln -sfn` treats both identically. The strategy is "symlink this entry as a
whole", not "symlink this directory".

Under `LINK`, `~/.config/fish/` is a real writable directory containing
`config.fish` as a symlink into `/usr/share/dawn`. fish writes `fish_variables`
beside it without conflict.

**`LINK` uses an explicit entry list, never a glob.** Globbing would silently
start linking any new file added upstream — including one the application
expects to own — which is the exact bug the strategy exists to prevent.

`SEED` exists for files Dawn ships an initial version of but the user or an
application then owns. `lazy-lock.json` is the clearest case: symlinking it
would point `:Lazy update` at a read-only path.

### Nothing is ever deleted

A real file or directory occupying a link target is **moved** to
`~/.dawn-backup/<timestamp>/`, and `dawn unlink` puts it back. A symlink
pointing somewhere else is replaced without a backup, because replacing a
symlink loses nothing.

The CLI never touches a link it did not create: `is_ours()` checks that a
symlink resolves under the current source root before removing it.

---

## Machine-local overrides

Shipped config is read-only, so an override cannot sit beside the file it
overrides. `~/.config/dawn/` is the one directory Dawn never writes to after
seeding it:

| File | For |
|---|---|
| `~/.config/dawn/local.lua` | monitor modes, GPU driver hints, vendor keybinds |
| `~/.config/dawn/local.fish` | personal aliases, extra `PATH` entries, secrets |

`config/hypr/hyprland.lua` loads its override with `loadfile()` on an absolute
path rather than `require()`, because the file is outside `package.path` and
stretching that to reach a home directory is worse than just reading the file.

**Missing is normal; broken is loud.** A fresh install has no `local.lua` and
must still boot to a desktop. But a file that exists and fails to parse is
reported — a desktop that silently ignores your config has no visible cause.

Reporting that failure was harder than it looks. Hyprland's Lua config has no
`hl.notify`, and `print()` from it reaches neither `hyprland.log` nor
`hyprctl rollinglog` — both verified by probe. So failures are recorded to
`~/.config/dawn/last-error`, which `dawn status` surfaces, *and* pushed through
`notify-send`. The file is the reliable channel; the notification is
best-effort, because at boot no notification daemon is running yet. On a
healthy config the file is deleted, so a stale error cannot linger.

---

## Dev mode

Developing Dawn after packaging would otherwise break: you edit the checkout
and nothing happens, because `~/.config` points at `/usr/share`.

```sh
dawn dev ~/software/dawn   # links from the checkout
dawn link                  # back to the packaged config
dawn status                # which mode, and every link
```

`<repo>` is the checkout **root** — the directory containing `config/`, not
`config/` itself — because that is what you cloned.

Seed sources are derived from the config source, not from `/usr/share`:

```
package   /usr/share/dawn/config  ->  /usr/share/dawn/examples
dev       <checkout>/config       ->  <checkout>/examples
```

One line, correct in both modes. Reading `$DAWN_SHARE` there instead would
silently seed nothing in dev mode on a machine with no `dawn-config` installed
— which is exactly the bug an integration test against the real repository
caught, and unit tests could not, because their fixtures build the examples
directory by hand.

---

## Dependencies

`install/packages.txt` is the **single source of truth** — 31 packages, each
with a comment saying what needs it. Every one is in the official Arch
repositories; Dawn has no AUR dependencies, so there is no AUR helper to
install, to trust, or to break an install halfway through.

The PKGBUILD **cannot read that file at build time.** `makepkg` parses
`depends=()` to resolve dependencies *before* sources are fetched, so `$srcdir`
does not exist yet. Instead it carries an explicit `_dawn_depends=()` array —
which is what anyone reading a PKGBUILD expects — and `check-depends.sh` fails
the build if the two drift apart.

```sh
./packaging/check-depends.sh
```

Exit codes are distinct on purpose: `0` they agree, `1` they drifted (with a
diff), `2` the check could not run at all. CI needs to tell "your dependency
lists disagree" from "the check itself is broken"; a single non-zero exit
conflates them.

---

## Release pipeline

Tagging is the only release action.

```sh
git tag v1.0.1 && git push origin v1.0.1
```

```
tag ──> workflow ──> tests ──> build ──> sign ──> repo-add ──> dawnlinux/repo ──> Pages
                                  │
                                  └──> workflow artifact (for the future ISO)
```

The workflow is deliberately thin; the work lives in `packaging/release.sh`, so
a release can be reproduced and debugged locally through the same code path:

```sh
DAWN_LOCAL_SOURCE=1 ./packaging/release.sh /tmp/dawn-repo
```

It refuses to build if the git tag and `pkgver` disagree, so you cannot ship
`v1.0.1` from a PKGBUILD that still says `1.0.0`.

The workflow publishes the packages as an artifact as well as pushing them,
because there is a **second consumer**: the installer ISO will bake an
*offline* pacman repository onto the image, which is what lets an ISO install
in under two minutes — the packages are on the USB stick and `pacstrap` never
touches the network.

### Signing

Every package and the database are signed. `pacman.conf` uses
`SigLevel = Required`, so an unsigned or unknown-key package is refused.

```
key   C36BACF174290B6ED5456879BCB1F6ACA2DD7A59
uid   Dawn Linux (Dawn package signing key)
```

A third-party pacman repository ships code that runs as root on every user's
machine. Unsigned packages would mean anyone who gained write access to the
Pages repository — or could MITM a user — could execute arbitrary code as root
on every Dawn install.

The public key is exported by `release.sh` on every run, so it can never drift
from the key that actually signed the packages.

---

## Problems this had to solve

Each of these was found by tooling or testing, not by reading the code.

**`repo-add` creates symlinks that GitHub Pages will not serve.** `dawn.db` is
a symlink to `dawn.db.tar.gz`, and pacman fetches the plain `dawn.db` name.
Pages does not follow symlinks — committing them serves a 404 or the link text.
The repository would have looked broken to every user while looking perfectly
fine in git. `release.sh` materialises all four links into real files and
asserts they are not symlinks before finishing.

**`$srcdir` does not exist at parse time.** Referencing it at PKGBUILD top
level breaks every tool that merely *sources* the file for its metadata —
`makepkg --printsrcinfo`, and `check-depends.sh` — because under `set -u` the
unbound variable aborts the source before `depends` can be read. Source paths
resolve in `_dawn_srcdir()` at call time instead.

**A `sed`-substituted sentinel breaks the guard that checks it.** The bootstrap
originally compared `DAWN_KEY_ID` against the literal placeholder string. The
release step substitutes that placeholder — rewriting both the assignment *and*
the comparison, leaving a guard that compares the real key against itself and
always fires. Every released installer would have refused to run. The guard now
validates the key's *shape* (`^[0-9A-Fa-f]{40}$`), which no substitution can
break and which also catches a truncated key.

**`set -euo pipefail` plus a failing command substitution is a silent killer.**
It bit twice. `find` on a non-existent `~/.dawn-backup` aborted `dawn unlink`
before it could report "no backups" — so unlink exited 1 and skipped restoring
on any clean install, the most common case. The same pattern in
`check-depends.sh` made a PKGBUILD that could not be sourced indistinguishable
from a genuine dependency mismatch. Both now guard explicitly rather than
relying on redirection to hide the failure.

**namcap found two real dependency errors.** `dawn-typist` was missing
`libxkbcommon`, which `ldd` confirms the binary links via
smithay-client-toolkit — the package would have installed and then failed to
start. `dawn-config` declared only `bash`, but it ships a QML shell and needs
`quickshell` and `qt6-declarative`; installing it alone would have produced
config that could not run.

**The debug package appeared non-deterministically.** `dawn-debug` only gets
built when the builder's `makepkg.conf` has `debug` on, so the set of produced
packages differed between machines and CI. `options=('!debug')` makes it always
exactly three.

---

## Testing

| Layer | How | Status |
|---|---|---|
| Link strategies | `tests/dawn.bats` against a fake `$XDG_CONFIG_HOME` | 23 passing |
| Manifest drift | `tests/depends.bats` | 3 passing |
| Shell lint | `shellcheck` on all four scripts | clean |
| Package lint | `namcap` on all three packages | 0 errors |
| Repository | build, sign, `repo-add`, verify db signature | verified |
| End-to-end install | `packaging/test-install.sh` in a container | **not yet written** |

The link-strategy tests are the important ones — that logic is where a bug
silently eats someone's configuration.

**The one thing that cannot be tested on a development machine** is installing
`dawn-config`, because it would overwrite the desktop being developed on. That
needs a `systemd-nspawn` container, which is the remaining piece of work.
