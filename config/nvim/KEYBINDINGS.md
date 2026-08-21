---
id: KEYBINDINGS
aliases: []
tags: []
---
# Keybindings

Every mapping defined in this config, grouped by purpose.

- **Leader** is `<Space>` (`lua/engine/core/keymaps.lua:1`)
- Mode column: `n` normal, `i` insert, `v` visual, `t` terminal
- "Source" points at the file that defines the mapping

---

## Buffers / open files (the tabs at the top)

Those tabs come from **bufferline.nvim** — they are Neovim _buffers_, not real tab pages.

| Key               | Mode | Action                                                        | Source                                 |
| ----------------- | ---- | ------------------------------------------------------------- | -------------------------------------- |
| `<Tab>`           | n    | Go to the buffer to the **right**                             | `lua/engine/core/keymaps.lua:20`       |
| `<S-Tab>`         | n    | Go to the buffer to the **left**                              | `lua/engine/core/keymaps.lua:21`       |
| `L` (`Shift`+`l`) | n    | Go to the buffer to the **right**                             | `lua/engine/core/keymaps.lua:23`       |
| `H` (`Shift`+`h`) | n    | Go to the buffer to the **left**                              | `lua/engine/core/keymaps.lua:24`       |
| `<leader>l`       | n    | **Move** the current buffer one slot right (reorders the tab) | `lua/engine/plugins/bufferline.lua:86` |
| `<leader>h`       | n    | **Move** the current buffer one slot left (reorders the tab)  | `lua/engine/plugins/bufferline.lua:85` |
| `<leader>x`       | n    | Close the current buffer (`:bdelete`)                         | `lua/engine/core/keymaps.lua:25`       |
| `<leader>n`       | n    | New tab page (`:tabnew`)                                      | `lua/engine/core/keymaps.lua:26`       |

Note the difference: `Tab`/`H`/`L` **switch** which file you are looking at.
`<leader>h` / `<leader>l` **drag the tab itself** to a different position in the bar.

## Windows / splits

| Key                             | Mode | Action                                                               | Source                           |
| ------------------------------- | ---- | -------------------------------------------------------------------- | -------------------------------- |
| `<leader>sv`                    | n    | Split window vertically                                              | `lua/engine/core/keymaps.lua:9`  |
| `<leader>sh`                    | n    | Split window horizontally                                            | `lua/engine/core/keymaps.lua:10` |
| `<leader>se`                    | n    | Make all splits equal size                                           | `lua/engine/core/keymaps.lua:11` |
| `<leader>sx`                    | n    | Close the current split                                              | `lua/engine/core/keymaps.lua:12` |
| `<C-Up>`                        | n    | Increase window height (+2)                                          | `lua/engine/core/keymaps.lua:14` |
| `<C-Down>`                      | n    | Decrease window height (-2)                                          | `lua/engine/core/keymaps.lua:15` |
| `<C-Left>`                      | n    | Narrower window (-4)                                                 | `lua/engine/core/keymaps.lua:16` |
| `<C-Right>`                     | n    | Wider window (+4)                                                    | `lua/engine/core/keymaps.lua:17` |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | n    | Move between splits **and tmux panes** (vim-tmux-navigator defaults) | `lua/engine/plugins/init.lua:3`  |

## Movement & editing

| Key     | Mode | Action                                         | Source                           |
| ------- | ---- | ---------------------------------------------- | -------------------------------- |
| `<C-u>` | n    | Half page up, then recenter (`zz`)             | `lua/engine/core/keymaps.lua:5`  |
| `<C-d>` | n    | Half page down, then recenter (`zz`)           | `lua/engine/core/keymaps.lua:6`  |
| `J`     | v    | Move the selected lines **down** and re-indent | `lua/engine/core/keymaps.lua:27` |
| `K`     | v    | Move the selected lines **up** and re-indent   | `lua/engine/core/keymaps.lua:28` |
| `jk`    | i    | Leave insert mode                              | `lua/engine/core/keymaps.lua:47` |
| `jk`    | t    | Leave terminal mode                            | `lua/engine/core/keymaps.lua:49` |
| `<Esc>` | t    | Leave terminal mode                            | `lua/engine/core/keymaps.lua:44` |

**mini.move** (`lua/engine/plugins/mini-move.lua`), stock mappings:

| Key     | Mode | Action                                          |
| ------- | ---- | ----------------------------------------------- |
| `<M-h>` | n, v | Move the line / selection left (dedent)         |
| `<M-l>` | n, v | Move the line / selection right (indent)        |
| `<M-j>` | n, v | Move the line / selection down                  |
| `<M-k>` | n, v | Move the line / selection up                    |

(`<M-…>` is `Alt`. These overlap in purpose with the visual `J`/`K` above; both work.)

**nvim-surround** is installed with its stock mappings (`lua/engine/plugins/surround.lua`):

| Key                | Mode | Action                             |
| ------------------ | ---- | ---------------------------------- |
| `ys{motion}{char}` | n    | Surround the motion (e.g. `ysiw"`) |
| `yss{char}`        | n    | Surround the whole line            |
| `ds{char}`         | n    | Delete the surrounding pair        |
| `cs{old}{new}`     | n    | Change the surrounding pair        |
| `S{char}`          | v    | Surround the selection             |

## File explorer

| Key         | Mode | Action           | Source                                |
| ----------- | ---- | ---------------- | ------------------------------------- |
| `<leader>e` | n    | Toggle nvim-tree | `lua/engine/plugins/nvim-tree.lua:42` |
| `<C-n>`     | n    | Focus nvim-tree  | `lua/engine/plugins/nvim-tree.lua:43` |

Inside the tree, nvim-tree's own defaults apply: `<CR>`/`o` open, `a` create, `d` delete, `r` rename, `x` cut, `c` copy, `p` paste, `R` refresh, `H` toggle hidden, `?` show the full help.

> `<leader>e` is mapped twice. `lua/engine/core/keymaps.lua:31` maps it to `:Ex` (netrw), but `nvim-tree.lua` loads later and overwrites it, so you get nvim-tree. The netrw line is dead.

## Find / Telescope

| Key              | Mode | Action                         | Source                                |
| ---------------- | ---- | ------------------------------ | ------------------------------------- |
| `<Space><Space>` | n    | Find files                     | `lua/engine/core/keymaps.lua:37`      |
| `<leader>ff`     | n    | Find files                     | `lua/engine/plugins/telescope.lua:36` |
| `<leader>fw`     | n    | Live grep in cwd               | `lua/engine/plugins/telescope.lua:37` |
| `<leader>fc`     | n    | Grep the word under the cursor | `lua/engine/plugins/telescope.lua:38` |

Inside a Telescope prompt (`lua/engine/plugins/telescope.lua:24-29`):

| Key               | Mode | Action                                          |
| ----------------- | ---- | ----------------------------------------------- |
| `<C-k>`           | i    | Previous result                                 |
| `<C-j>`           | i    | Next result                                     |
| `<C-q>`           | i    | Send selection to the quickfix list and open it |
| `<C-t>`           | i    | Open the results in Trouble                     |
| `<C-c>` / `<Esc>` | i    | Close (Telescope default)                       |

## LSP

Buffer-local, attached on `LspAttach` (`lua/engine/plugins/lsp/lspconfig.lua:50-86`):

| Key          | Mode | Action                                          |
| ------------ | ---- | ----------------------------------------------- |
| `gd`         | n    | Go to definition                                |
| `gD`         | n    | Go to declaration                               |
| `gr`         | n    | References (Telescope)                          |
| `gi`         | n    | Implementations (Telescope)                     |
| `gt`         | n    | Type definitions (Telescope)                    |
| `K`          | n    | Hover docs                                      |
| `<leader>ca` | n, v | Code action                                     |
| `<leader>rn` | n    | Rename symbol                                   |
| `<leader>rs` | n    | Restart the LSP server                          |
| `<leader>d`  | n    | Buffer diagnostics (Telescope)                  |
| `<leader>dl` | n    | Show the diagnostic under the cursor in a float |
| `[d`         | n    | Previous diagnostic                             |
| `]d`         | n    | Next diagnostic                                 |

Call hierarchy (global, `lua/engine/core/keymaps.lua:33-36`):

| Key          | Mode | Action          |
| ------------ | ---- | --------------- |
| `<leader>ci` | n    | Incoming calls  |
| `<leader>co` | n    | Outgoing calls  |
| `<leader>ch` | n    | Implementations |
| `<leader>cu` | n    | References      |

> `<leader>rs` has no `:LspRestart` to call — the servers here start through `vim.lsp.config()` / `vim.lsp.enable()` (`lua/engine/plugins/lsp/lspconfig.lua:160+`), and that API ships no restart command. The mapping stops every client attached to the buffer and reloads it so the autostart re-attaches them.

> `<leader>d` (diagnostics) and `<leader>dl`/`<leader>db`/… (debugger) share a prefix, so `<leader>d` waits for `timeoutlen` before firing.

## Completion (nvim-cmp)

Insert mode, while the menu is open (`lua/engine/plugins/nvim-cmp.lua:34-41`):

| Key         | Action                    |
| ----------- | ------------------------- |
| `<C-k>`     | Previous item             |
| `<C-j>`     | Next item                 |
| `<C-b>`     | Scroll docs up            |
| `<C-f>`     | Scroll docs down          |
| `<C-Space>` | Trigger completion        |
| `<C-e>`     | Abort                     |
| `<CR>`      | Confirm the selected item |

## Debugging (nvim-dap / dap-ui)

| Key          | Mode | Action                           | Source                             |
| ------------ | ---- | -------------------------------- | ---------------------------------- |
| `<leader>dc` | n    | Continue / start                 | `lua/engine/plugins/dap.lua:144`   |
| `<leader>db` | n    | Toggle breakpoint                | `lua/engine/plugins/dap.lua:145`   |
| `<leader>ds` | n    | Step over                        | `lua/engine/plugins/dap.lua:146`   |
| `<leader>di` | n    | Step into                        | `lua/engine/plugins/dap.lua:147`   |
| `<leader>do` | n    | Step out                         | `lua/engine/plugins/dap.lua:148`   |
| `<leader>dr` | n    | Restart                          | `lua/engine/plugins/dap.lua:149`   |
| `<leader>dt` | n    | Terminate                        | `lua/engine/plugins/dap.lua:150`   |
| `<leader>du` | n    | Toggle the DAP UI                | `lua/engine/plugins/dap-ui.lua:62` |
| `<leader>dw` | n    | Add a watch expression (prompts) | `lua/engine/plugins/dap-ui.lua:65` |
| `<leader>dW` | n    | Remove a watch                   | `lua/engine/plugins/dap-ui.lua:72` |
| `<leader>dC` | n    | Clear all watches                | `lua/engine/plugins/dap-ui.lua:76` |

## Treesitter selection

| Key         | Mode | Action                                | Source                                  |
| ----------- | ---- | ------------------------------------- | --------------------------------------- |
| `<C-space>` | n    | Start incremental selection           | `lua/engine/plugins/treesitter.lua:120` |
| `<C-space>` | v    | Grow the selection to the parent node | `lua/engine/plugins/treesitter.lua:121` |
| `<BS>`      | v    | Shrink the selection                  | `lua/engine/plugins/treesitter.lua:123` |

## Notes: Obsidian & markdown

Loaded on demand by these keys (`lua/engine/plugins/obsidian.lua:7-17`):

| Key          | Mode | Action                                                                 |
| ------------ | ---- | ---------------------------------------------------------------------- |
| `<leader>ob` | n    | Backlinks                                                              |
| `<leader>oc` | n    | Toggle checkbox                                                        |
| `<leader>od` | n    | Today's daily note                                                     |
| `<leader>ol` | n    | Links in the note                                                      |
| `<leader>oo` | n    | Open in the Obsidian app                                               |
| `<leader>oq` | n    | Quick switch note                                                      |
| `<leader>os` | n    | Search notes                                                           |
| `<leader>ot` | n    | Insert a template                                                      |
| `<leader>oT` | n    | Table of contents                                                      |
| `<leader>om` | n    | Toggle markdown rendering (`lua/engine/plugins/render-markdown.lua:7`) |

Inside the Obsidian picker (`lua/engine/core/obsidian.lua`, `picker` section):

| Key     | Action                           |
| ------- | -------------------------------- |
| `<C-x>` | Create a new note / tag the note |
| `<C-l>` | Insert a link / insert a tag     |

## Themes

| Key          | Mode | Action                        | Source                           |
| ------------ | ---- | ----------------------------- | -------------------------------- |
| `<leader>ts` | n    | `:Theme` — pick a colorscheme | `lua/engine/core/keymaps.lua:39` |
| `<leader>tn` | n    | `:ThemeNext`                  | `lua/engine/core/keymaps.lua:40` |
| `<leader>tp` | n    | `:ThemePrev`                  | `lua/engine/core/keymaps.lua:41` |

The commands live in `lua/engine/core/theme.lua` and walk the list in `lua/engine/core/colorschemes.lua` (56 schemes):

| Command        | What it does                                                     |
| -------------- | ---------------------------------------------------------------- |
| `:Theme`       | Opens a `vim.ui.select` picker (dressing gives it the nice UI)   |
| `:Theme <name>` | Applies one scheme directly; `<Tab>` completes the names        |
| `:ThemeNext`   | Next scheme in the list, wraps around, echoes `name (n/56)`      |
| `:ThemePrev`   | Previous scheme in the list                                      |

The choice is written to `~/.local/state/nvim/engine-theme` and restored on the next start; if that scheme ever disappears from the list, startup falls back to `koda` without overwriting the file. koda's own variants get `require("koda").setup()` called with the right background overrides before the scheme is applied.

## Dashboard (alpha-nvim)

On the start screen only (`lua/engine/plugins/alpha.lua`):

| Key | Action      |
| --- | ----------- |
| `e` | New file    |
| `f` | Find file   |
| `q` | Quit Neovim |

## Commands (no key bound)

The hand-written tools live in `lua/engine/tools/`, one directory per language (`cpp/`, `java/`, `typst/`), each registering its own commands from `lua/engine/tools/init.lua`.

**Shared**

| Command | What it does                                                              |
| ------- | ------------------------------------------------------------------------- |
| `:Skel` | Skeleton for the current file, dispatched by filetype (C/C++ → header or source stub, Java → picks a template from the file name) |

**C/C++** (`lua/engine/tools/cpp/`)

| Command                         | What it does                                     |
| ------------------------------- | ------------------------------------------------ |
| `:CppExtractDefinitions`        | Move all inline definitions to the `.cpp`        |
| `:CppExtractFunctionDefinition` | Move the function under the cursor to the `.cpp` |

**Java** (`lua/engine/tools/java/`) — fill an empty `.java` file with the boilerplate for its kind. The type name always comes from the file name; in an unnamed scratch buffer the first argument is the name instead. Add `!` to overwrite a buffer that already has content.

| Command                    | Generates                                                     |
| -------------------------- | ------------------------------------------------------------- |
| `:JavaClass`               | `public class Foo { }`                                        |
| `:JavaInterface`           | `public interface Foo { }`                                    |
| `:JavaEnum`                | `public enum Foo { }`                                          |
| `:JavaRecord`              | `public record Foo(…) { }`                                     |
| `:JavaAnnotation`          | `@Retention` + `@Target` + `public @interface Foo { }`         |
| `:JavaAbstract`            | `public abstract class Foo { }`                                |
| `:JavaFinal`               | `public final class Foo { }`                                   |
| `:JavaException`           | class extending `RuntimeException` with both usual constructors |
| `:JavaMain`                | class with a `main` method                                     |
| `:JavaTest`                | JUnit 5 test class with a `@Test` stub                         |
| `:JavaSingleton`           | eager singleton with a private constructor and `getInstance()` |
| `:Java {kind}`             | Any of the above; `<Tab>` completes the kinds, bare `:Java` opens a picker |
| `:JavaPackage`             | Insert or repair this file's `package …;` line                 |

Every command derives the package from the maven/gradle layout on disk (`src/main/java`, `src/test/java`, `src/`, else the path below the project root) and omits the declaration for the default package. Trailing arguments are template input:

| Example                        | Result                                        |
| ------------------------------ | --------------------------------------------- |
| `:JavaRecord int x, int y`     | `public record Point(int x, int y) {`         |
| `:JavaEnum RED, GREEN, BLUE`   | the three constants, uppercased, `;`-terminated |
| `:JavaAnnotation METHOD, FIELD` | `@Target({ ElementType.METHOD, ElementType.FIELD })` |
| `:JavaClass implements Runnable` | appended to the declaration (`extends`, `implements` and `permits` all work) |

**Typst** (`lua/engine/tools/typst/`)

| Command         | What it does                     |
| --------------- | -------------------------------- |
| `:TypstPreview` | Open the compiled PDF in zathura |

`.typ` files auto-compile on save, C/C++ includes are auto-sorted on save, and renaming a C/C++ file from nvim-tree rewrites the `#include`s that pointed at it — all autocmds, no keys.

## Installed but unmapped

These plugins are loaded without any keymaps, so only their defaults (if any) apply: `trouble.nvim` (no `<leader>x*` maps — reachable via `:Trouble` and `<C-t>` in Telescope), `nvim-ufo` (no `setup()`, folding uses `foldmethod=marker` with `#pragma region` markers instead), `todo-comments.nvim`, `bufdelete.nvim` (`:Bdelete`), `nvim-colorizer`, `satellite.nvim`, `snacks.nvim`, `dressing.nvim`, `nvim-autopairs`, `nvim-ts-autotag`.

## Known conflicts and dead maps

1. `<leader>e` — mapped to netrw in `keymaps.lua` and to nvim-tree in `nvim-tree.lua`; nvim-tree wins.
2. `<leader>d` — collides with the `<leader>d*` debugger prefix, so it lags by `timeoutlen`.
3. `K` — LSP hover in normal mode, move-line-up in visual mode. Different modes, no real conflict.
4. `<Tab>` — remapping it also remaps `<C-i>`, so jump-forward in the jumplist is gone (`<C-o>` back still works).