---
id: CMD
aliases: []
tags: []
---

# Go toolkit commands

- Defined in `lua/engine/tools/go/init.lua`
- **`:Skel` is the only command.** The toolkit has no commands and no autocmds of
  its own, so it is not in `TOOLKITS` — `tools/init.lua:30` requires it lazily
  through the `:Skel` dispatch table
- **No keymaps are bound**, same as the C++ and Java toolkits
- The buffer must be **saved** first: the package name comes from the directory
- A non-empty buffer is left alone (there is no bang here, unlike `:Java*`)

---

## What `:Skel` produces

| File                | Skeleton                                        |
| ------------------- | ----------------------------------------------- |
| `main.go`           | `package main` + `func main` + `fmt` import     |
| `*_test.go`         | the package + `testing` import + a test function |
| anything else       | just the package declaration                    |

```vim
" main.go
:Skel
```

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello, world!")█
}
```

```vim
" internal/scraper/client_test.go
:Skel
```

```go
package scraper

import "testing"

func TestClient(t *testing.T) {
	█
}
```

```vim
" internal/scraper/client.go
:Skel
```

```go
package scraper

█
```

`█` marks where the cursor is parked.

The test function name comes from the file name: `client_test.go` → `TestClient`,
`price_parser_test.go` → `TestPriceParser`. `main_test.go` is the exception — it
becomes **`TestRun`**, because `TestMain` is reserved by the testing package for the
optional `TestMain(m *testing.M)` entry point and you do not want to write one by
accident.

---

## How the package name is worked out

Handled by `lua/engine/tools/go/context.lua`, in this order:

1. **What the neighbours already say.** Every `.go` file in the directory has to
   declare the same package, so the sibling files are the authority. The first
   `package …` clause found wins, skipping `//` and `/* … */` comments so a licence
   header or build constraint above it does not confuse the scan.
   `_test.go` siblings never get a vote — they are allowed to say `package foo_test`,
   which would be the wrong answer for a normal file.
2. **`main.go`, or any file directly under `cmd/`** → `package main`.
3. **The directory name**, lower-cased with non-alphanumerics removed, following Go's
   convention of no dashes or underscores: `internal/price-parser/` → `package priceparser`.
   A leading digit gets an `_` prefix so it stays a legal identifier (`2d` → `_2d`).

Because rule 1 comes first, a new file in an existing package always joins that
package — the directory name is only a fallback for the first file in a fresh
directory.

---

## Indentation and gofmt

The skeleton always indents with a **tab**, ignoring the buffer's `expandtab` /
`shiftwidth`, because gofmt would rewrite spaces on the next write anyway.

Two things are worth knowing:

- The cursor line inside a function body is a lone tab, which `gofmt -l` counts as
  trailing whitespace. gopls is configured (`lua/engine/plugins/lsp/lspconfig.lua:315`)
  and conform formats on save with `lsp_fallback` (`lua/engine/plugins/formatting.lua:38`),
  so **it is stripped the moment you write the file**.
- A plain (non-main, non-test) skeleton is a package clause and a blank line. On its own
  that is not gofmt-clean, but it is the right shape to type into: the blank line is
  exactly the separator gofmt wants between the package clause and the first
  declaration.

Both resolve themselves as soon as there is real code in the file.
