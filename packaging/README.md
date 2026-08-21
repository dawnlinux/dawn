# Packaging

Three packages are built from one `PKGBUILD`:

| Package | Arch | Contents |
|---|---|---|
| `dawn` | any | meta; depends on the whole desktop |
| `dawn-config` | any | `/usr/share/dawn/`, `/usr/bin/dawn` |
| `dawn-typist` | x86_64 | `/usr/bin/typist` |

## Releasing

Tagging is the only release action — `pkgver` derives from the tag, and the
workflow refuses to build if the two disagree.

```sh
# 1. bump pkgver in packaging/PKGBUILD
# 2. commit it
git tag v1.0.1
git push origin v1.0.1
```

`.github/workflows/release.yml` then runs the tests, builds, signs, lints with
`namcap`, and pushes to `dawnlinux/repo`, which GitHub Pages serves.

The workflow is deliberately thin — the real work is in `release.sh`, so a
release can be reproduced locally through the same code path:

```sh
DAWN_LOCAL_SOURCE=1 ./packaging/release.sh /tmp/dawn-repo
```

## Building locally

```sh
cd packaging
DAWN_LOCAL_SOURCE=1 makepkg --syncdeps --cleanbuild
namcap ./*.pkg.tar.zst
pacman -Qlp ./dawn-config-*.pkg.tar.zst | head
```

`DAWN_LOCAL_SOURCE=1` builds from the working tree instead of the published
git tag, which is how packaging is verified before a release exists. The
workflow never sets it.

> **Do not `pacman -U` the result on your development machine.** Installing
> `dawn-config` replaces the desktop you are developing on. Use
> `packaging/test-install.sh`, which does it in a throwaway container.

## Signing

Every package and the database are signed; `pacman.conf` uses
`SigLevel = Required`, so an unsigned or unknown-key package is refused.

```
key   C36BACF174290B6ED5456879BCB1F6ACA2DD7A59
uid   Dawn Linux (Dawn package signing key)
```

The public key is published at `https://dawnlinux.github.io/repo/dawn.gpg`
and exported by `release.sh` on every run, so it can never drift from the key
that actually signed the packages.

CI needs the private key as the `GPG_PRIVATE_KEY` secret:

```sh
gpg --armor --export-secret-keys C36BACF174290B6ED5456879BCB1F6ACA2DD7A59 \
  | base64 -w0 \
  | gh secret set GPG_PRIVATE_KEY --repo dawnlinux/dawn
```

It also needs `REPO_PUSH_TOKEN`, a token with write access to
`dawnlinux/repo`.

## Two things that are easy to get wrong

**`repo-add` creates symlinks.** `dawn.db` is a symlink to `dawn.db.tar.gz`,
and pacman fetches the plain `dawn.db` name. GitHub Pages does not follow
symlinks, so committing them serves a 404 or the link text — the repository
looks broken to every user while looking fine in git. `release.sh` materialises
all four links into real files and asserts they are not symlinks before
finishing.

**`$srcdir` does not exist at parse time.** The PKGBUILD resolves source paths
in `_dawn_srcdir()` at call time. Referencing `$srcdir` at top level breaks
every tool that merely sources the file for its metadata —
`makepkg --printsrcinfo`, and `check-depends.sh` — because under `set -u` the
unbound variable aborts the source before `depends` can be read.

## Dependencies

`install/packages.txt` is the single source of truth. `packaging/PKGBUILD`
carries an explicit `_dawn_depends=()` array because `makepkg` parses
`depends=()` before sources are fetched, so the manifest cannot be read at
build time. `packaging/check-depends.sh` runs in the PKGBUILD's `check()` and
fails the build if the two drift apart.

```sh
./packaging/check-depends.sh
```

Exit codes are distinct: `0` agree, `1` drifted (with a diff), `2` the check
could not run — so CI can tell "your lists disagree" from "the check is
broken".
