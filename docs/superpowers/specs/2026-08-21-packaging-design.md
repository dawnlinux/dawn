# Dawn packaging — design

**Date:** 2026-08-21
**Status:** approved, not yet implemented

## Problem

Dawn installs today by cloning the repository and running `install.sh`, which
symlinks `config/<name>` into `~/.config/<name>`. That works, but it means:

- updating Dawn is `git pull` plus remembering to re-run the installer
- every user carries a full git checkout, including history, as a runtime dependency
- there is no way to install Dawn without also becoming a Dawn developer
- dependencies are installed by a shell loop rather than resolved by the package manager

The goal is `pacman -Syu` updating the desktop the same way it updates
everything else on an Arch system.

## Decisions

Five decisions frame the design. Each was chosen deliberately; the rejected
alternatives are recorded because the reasons are not obvious later.

### D1 — Configuration is symlinked from `/usr/share/dawn/config`

The package installs the config tree to `/usr/share/dawn/config/`, and
`~/.config/<app>` points into it. `pacman -Syu` therefore updates the running
desktop with no merge step, no migration scripts, and no per-release upgrade
logic.

*Rejected:* copying templates into `~/.config` and three-way merging on update
(Omarchy's model). It lets users edit shipped files, at the cost of merge
logic, conflict handling, and a migration script per release — permanent
machinery to maintain.

*Rejected:* packaging only the binaries and leaving config as a git checkout.
Smallest change, but it does not deliver `pacman -Syu` updates, which is the
entire point.

**Consequence:** shipped config files are root-owned and read-only to the user.
This is acceptable *only* because Dawn already has a local-override layer —
see D4.

### D2 — Three packages from one split PKGBUILD

```
pkgbase=dawn

dawn          any     meta; depends on the package manifest + dawn-config
dawn-config   any     /usr/share/dawn/config, /usr/bin/dawn, greetd files
dawn-typist   x86_64  /usr/bin/typist
```

`pacman -S dawn` installs the desktop. `pacman -S dawn-typist` installs just
the typing test. Splitting the tools out means adding a second tool later does
not grow the desktop package.

*Rejected:* one monolithic package (no way to take the desktop without the
extras). *Rejected:* five packages splitting the shell and greeter out
separately — more PKGBUILD surface than 164 files justify.

### D3 — Hosted on GitHub Pages under the `dawnlinux` org

```ini
[dawn]
SigLevel = Required DatabaseOptional
Server   = https://dawnlinux.github.io/repo/$arch
```

Free, static, no infrastructure to keep online, and CI can push to it. Dawn's
packages are a few hundred kilobytes against a ~1 GB practical limit.

*Rejected:* GitHub Releases (needs assets overwritten on a fixed tag for the
URL to stay stable). *Rejected:* a VPS (costs money, and becomes something that
can go down and take installs with it). *Rejected:* AUR-only, which would
contradict Dawn's no-AUR-dependencies rule and require an AUR helper to install
Dawn itself.

### D4 — Local overrides move to `~/.config/dawn/`

Directly forced by D1: a user cannot write into a root-owned directory, so
`local.lua` can no longer live in `config/hypr/modules/`.

```
~/.config/dawn/local.lua     was config/hypr/modules/local.lua
~/.config/dawn/local.fish    was config/fish/local.fish
```

`~/.config/dawn/` becomes *the* writable user-override directory: one place,
outside every symlink, that pacman never touches.

`config/hypr/hyprland.lua` changes from `require("modules.local")` to
`loadfile()` against an absolute path. This is simpler than making
`package.path` reach outside the config tree, and it keeps the "missing is
normal, broken is loud" behaviour already implemented.

### D5 — Packages are GPG-signed, `SigLevel = Required`

A third-party pacman repo ships code that runs as root on every user's machine.
Unsigned packages mean anyone who gains write access to the Pages repository —
or can MITM a user — can execute arbitrary code as root on every Dawn install.

Users import the key once during setup; the private key lives in a GitHub
Actions secret. This is what Chaotic-AUR and ALHP do.

---

## Architecture

### Repositories

| Repository | Contents |
|---|---|
| `dawnlinux/dawn` | source; gains a `packaging/` directory |
| `dawnlinux/repo` | built packages and `dawn.db`, served by GitHub Pages |

Built artifacts stay out of the source repository: committing `.pkg.tar.zst`
files would bloat every clone permanently, and git history cannot be pruned
after the fact without rewriting it.

### Filesystem layout

```
/usr/share/dawn/config/     the config tree, root-owned
/usr/share/dawn/examples/   seed sources for ~/.config/dawn
/usr/share/dawn/greetd/     greetd config and its installer
/usr/bin/dawn               the CLI
/usr/bin/typist             dawn-typist

~/.config/dawn/             user overrides, never touched by pacman
~/.config/<app>             symlinks into /usr/share/dawn/config
~/.dawn-backup/<timestamp>/ whatever the CLI displaced
```

### Link strategies

The naive model — symlink every config directory — breaks for three
applications, because **they write into their own configuration directory**:

| File | Written by | When |
|---|---|---|
| `fish_variables` | fish | every `set -U` |
| `lazy-lock.json` | lazy.nvim | every `:Lazy update` |
| `.qmlls.ini` | Quickshell's QML language-server integration | on use |

A read-only symlinked directory makes all three fail. Linking therefore has
three strategies, declared per application:

| Strategy | Behaviour | Applies to |
|---|---|---|
| `DIR` | symlink the entry wholesale | `hypr`, `kitty`, `rofi`, `starship.toml` |
| `LINK` | create a real directory; symlink each listed entry into it | `fish`, `nvim`, `quickshell` |
| `SEED` | copy once if absent; never overwrite | `lazy-lock.json`, `~/.config/dawn/local.*` |

`DIR` covers files as well as directories — `starship.toml` is a single file
at the root of the config tree, and `ln -sfn` treats both identically. The
strategy is "symlink this entry as a whole", not "symlink this directory".

`LINK` is driven by an explicit per-application entry list held in the CLI, not
by globbing the source directory. Globbing would silently start linking any new
file added upstream, including ones an application expects to own — which is
the bug this strategy exists to prevent. The initial lists are:

| App | Linked entries |
|---|---|
| `fish` | `config.fish` |
| `nvim` | `init.lua`, `lua/`, `dap.txt`, `KEYBINDINGS.md`, `README.md`, `showcase/` |
| `quickshell` | `dawn-island/`, `dawn-greet/` |

Under `LINK`, `~/.config/fish/` is a real writable directory containing
`config.fish` as a symlink to `/usr/share/dawn/config/fish/config.fish`. fish
writes `fish_variables` beside it without conflict.

`SEED` exists for files Dawn ships an initial version of but the user or an
application then owns. `lazy-lock.json` is the clearest case: symlinking it
would make `:Lazy update` fail writing to a read-only path.

Seed sources live at `/usr/share/dawn/examples/`, from `examples/` in the
source repository. `local.lua.example` and `local.fish.example` move there
from their current locations under `config/`, since they no longer belong
beside the files they override:

```
/usr/share/dawn/examples/local.lua   ->  ~/.config/dawn/local.lua
/usr/share/dawn/examples/local.fish  ->  ~/.config/dawn/local.fish
```

### The `dawn` CLI

One job — owning the links. Installed to `/usr/bin/dawn` by `dawn-config`.

```
dawn link              point ~/.config at /usr/share/dawn/config
dawn dev <repo>        point it at a checkout instead
dawn status            current mode, source path, and any stale links
dawn unlink            remove Dawn's links and restore backups
```

`<repo>` is the checkout root — the directory containing `config/`, not
`config/` itself. `dawn dev ~/software/dawn` therefore links from
`~/software/dawn/config/`. Taking the root rather than the config directory
keeps the argument identical to what the user cloned, and lets the CLI read
`install/packages.txt` from the same checkout. It is rejected with an error if
`<repo>/config` does not exist.

`dawn link` and `dawn dev` differ only in source directory; they share all
backup, strategy and idempotency logic. `dawn status` is what makes the two
modes debuggable — without it, "I edited the repo and nothing changed" has no
visible cause.

The CLI never removes a link it did not create: it checks that a symlink
resolves under the expected source root before touching it. A real directory
where a link should go is moved to `~/.dawn-backup/<timestamp>/`, never
deleted.

### Dependency manifest

`install/packages.txt` remains the single source of truth for what Dawn
depends on.

**It cannot be read by the PKGBUILD at build time.** `makepkg` parses
`depends=()` to resolve dependencies *before* sources are fetched or
extracted, so `$srcdir` does not exist yet. (This corrects the approach
sketched during design discussion.)

Instead: the PKGBUILD carries an explicit `depends=()` array — which is what
anyone reading a PKGBUILD expects — and a check script fails the build if that
array has drifted from `install/packages.txt`. The manifest stays canonical;
the PKGBUILD stays idiomatic; drift is caught by CI rather than by a user.

### Versioning

All three packages share one `pkgver`, taken from the git tag. A split
PKGBUILD cannot give its packages different versions — `pkgver` belongs to
`pkgbase`.

This means `dawn-typist` versions with Dawn rather than with its own
`Cargo.toml`. That is accepted: typist ships as part of Dawn, and a separate
PKGBUILD purely to give it an independent version number is not worth the
duplicated release pipeline. If typist ever gains an independent release
cadence, it gets its own PKGBUILD then.

### Release pipeline

Triggered by pushing a tag:

1. `makepkg` builds all three packages
2. each package is signed with the key from Actions secrets
3. `repo-add` updates `dawn.db.tar.gz`
4. packages and database are committed to `dawnlinux/repo`
5. GitHub Pages serves them

`pkgver` derives from the tag, so tagging is the only release action.

**The pipeline has a second consumer.** GitHub Pages is not the only thing that
needs these packages: the installer ISO (next stage) has to bake an *offline*
pacman repository onto the image, holding the three Dawn packages plus their
resolved dependency closure. That is what lets an ISO install in under two
minutes — the packages are on the USB stick, and `pacstrap` never touches the
network.

So the release job must expose the built packages as a reusable artifact, not
only commit them to `dawnlinux/repo`. Concretely: publish the signed
`.pkg.tar.zst` files as a workflow artifact that a later ISO build can download
and feed to `repo-add` locally.

This does not change any package or any link strategy. It is recorded here
because writing the workflow as if Pages were the only target would need
reworking the moment the ISO exists.

### `install.sh` becomes a bootstrap

The current installer's job splits in two. Linking moves into the CLI; what
remains is first-contact setup:

1. import and locally sign the Dawn signing key
2. add the `[dawn]` section to `/etc/pacman.conf`
3. `pacman -Sy dawn`
4. `dawn link`

The backup and symlink logic is not duplicated between the two — it lives in
the CLI, and `install.sh` calls it.

---

## Error handling

- **Missing local override** — normal. A fresh install has no
  `~/.config/dawn/local.lua` and must boot to a desktop.
- **Broken local override** — loud. Logged as a `dawn:` line in the Hyprland
  log, because a desktop silently ignoring your config has no visible cause.
- **Occupied link target** — moved to `~/.dawn-backup/<timestamp>/`, reported,
  never deleted.
- **Foreign symlink at a link target** — replaced, with a warning naming the
  previous target. Replacing a symlink loses nothing.
- **Manifest drift** — fails the build, not the user's install.
- **Unsigned or badly signed package** — pacman refuses it, by virtue of D5.

## Testing

Honest constraint: **this cannot be fully verified on the development
machine**, because installing `dawn-config` would overwrite the live desktop
it is being developed on.

| Layer | How |
|---|---|
| Link strategies | run the CLI against a fake `$XDG_CONFIG_HOME` in a temp dir; assert the resulting tree |
| Idempotency | run twice; assert the second run changes nothing |
| Backup/restore | occupy a target, link, unlink, assert the original returns byte-identical |
| Package contents | `makepkg`, then `pacman -Qlp` and `namcap` |
| Manifest drift | check script, run in CI |
| End-to-end install | `systemd-nspawn` container, via `packaging/test-install.sh` |

The link-strategy tests are the important ones — that logic is where a bug
silently eats someone's configuration.

## Scope

**In scope**

- `packaging/PKGBUILD` producing the three packages
- `packaging/dawn` — the CLI
- relocating local overrides to `~/.config/dawn/`, moving the two `.example`
  files to `examples/`, and the `hyprland.lua` and `config.fish` changes that
  follow
- the manifest drift check
- the release workflow and signing setup
- reducing `install.sh` to a bootstrap
- README and `pacman.conf` documentation
- the test harness above

**Out of scope**

- an archiso ISO with a graphical installer — the next stage. It depends on
  this one: its core step is `pacstrap /mnt base linux linux-firmware dawn`,
  which requires the `dawn` package to exist. Building it first would mean
  hand-rolling config installation into the ISO and discarding that work once
  packaging lands. The only accommodation made for it here is the reusable
  package artifact described under *Release pipeline*.
- `dawn greeter enable|disable` CLI wrappers; the existing
  `config/greetd/install.sh` ships as-is and keeps working
- automatic migration between Dawn releases; D1 makes it unnecessary for
  config, and anything else is handled by pacman hooks if it ever comes up
- architectures other than `x86_64`

## Open questions

None blocking. Two to revisit after the first release:

- whether `dawn status` should also report when a shipped file has drifted
  from the installed package (`pacman -Qkk`)
- whether the greeter's QML should ship from `dawn-config` rather than being
  copied into `/etc/greetd` by its installer
