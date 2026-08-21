-- dawn — the colour engine's scheme.
--
-- Reads ~/.config/dawn/generated/nvim-colors.lua, which `dawn-theme` renders
-- through matugen from the current wallpaper. Pick it like any other:
--
--     :colorscheme dawn
--
-- It is one entry in engine/core/colorschemes.lua beside tokyonight and the
-- rest; nothing here replaces them.
--
-- ── Minimal on purpose ────────────────────────────────────────────────────
--
-- About twenty groups, not eighty. It was written to answer one question
-- before more work went into it: is a wallpaper-derived syntax theme actually
-- readable?
--
-- Under a colourful scheme, yes. Under `scheme-monochrome` primary, secondary
-- and tertiary collapse to three near-identical greys and String comes out the
-- same colour as ordinary text — which is a large part of why monochrome is
-- not the shipped default.
--
-- If it reads well, the remaining groups (Treesitter @*, LSP semantic tokens,
-- git signs, telescope, cmp) are mechanical from the same palette.

local FALLBACK = {
	bg = "#19120d",
	bgAlt = "#261e18",
	bgHigh = "#312822",
	sel = "#3c332d",
	fg = "#f0dfd6",
	fgDim = "#d6c3b7",
	muted = "#9f8d82",
	primary = "#ffb781",
	secondary = "#d6c3b7",
	tertiary = "#c7ca95",
	error = "#ffb4ab",
	warn = "#e8c07d",
	ok = "#7ec699",
}

--- Load the generated palette, falling back to Dawn's default.
---
--- A fresh install has not run dawn-theme yet, and a colorscheme that errors
--- leaves the editor unusable — so a missing or broken file is not fatal.
local function palette()
	local path = vim.fn.expand("~/.config/dawn/generated/nvim-colors.lua")
	local chunk = loadfile(path)
	if not chunk then
		return FALLBACK
	end

	local ok, generated = pcall(chunk)
	if not ok or type(generated) ~= "table" then
		return FALLBACK
	end

	-- Merge rather than replace, so a template that gains a key before the
	-- generated file is regenerated still produces a complete scheme.
	local merged = vim.deepcopy(FALLBACK)
	for key, value in pairs(generated) do
		merged[key] = value
	end
	return merged
end

--- Re-apply this scheme whenever dawn-theme rewrites the palette.
---
--- Every other surface in Dawn repaints live: the island watches colors.json
--- through FileView, kitty takes a signal, Hyprland is reloaded. Without this
--- the editor would be the one thing left on a stale palette until it was
--- restarted.
---
--- The watch is torn down as soon as another colourscheme is selected, so
--- picking `koda` does not leave a file watcher running for a scheme that is
--- no longer in use.
local function watch(path)
    local uv = vim.uv or vim.loop
    local handle = uv.new_fs_event()
    if not handle then
        return
    end

    local reapplying = false

    handle:start(path, {}, function(err)
        if err or reapplying then
            return
        end
        reapplying = true
        vim.schedule(function()
            -- Only if this scheme is still the active one. A watch that
            -- outlives its scheme would yank the user back to dawn.
            if vim.g.colors_name == "dawn" then
                pcall(vim.cmd.colorscheme, "dawn")
            end
            reapplying = false
        end)
    end)

    vim.api.nvim_create_autocmd("ColorScheme", {
        once = true,
        callback = function(ev)
            if ev.match ~= "dawn" and not handle:is_closing() then
                handle:stop()
                handle:close()
            end
        end,
    })
end

vim.cmd.highlight("clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd.syntax("reset")
end

vim.o.background = "dark"
vim.g.colors_name = "dawn"

local c = palette()
local hl = function(group, spec)
	vim.api.nvim_set_hl(0, group, spec)
end

-- ── Editor surface ────────────────────────────────────────────────────────
hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalFloat", { fg = c.fg, bg = c.bgAlt })
hl("FloatBorder", { fg = c.muted, bg = c.bgAlt })
hl("CursorLine", { bg = c.bgAlt })
hl("CursorLineNr", { fg = c.primary, bold = true })
hl("LineNr", { fg = c.muted })
hl("Visual", { bg = c.sel })
hl("Search", { fg = c.bg, bg = c.tertiary })
hl("IncSearch", { fg = c.bg, bg = c.primary })
hl("WinSeparator", { fg = c.bgHigh })
hl("StatusLine", { fg = c.fgDim, bg = c.bgAlt })
hl("Pmenu", { fg = c.fgDim, bg = c.bgAlt })
hl("PmenuSel", { fg = c.fg, bg = c.sel, bold = true })

-- ── Syntax ────────────────────────────────────────────────────────────────
--
-- Bold and italic carry as much of the distinction as hue does, so the scheme
-- degrades gracefully when a wallpaper yields a narrow palette.
hl("Comment", { fg = c.muted, italic = true })
hl("String", { fg = c.tertiary })
hl("Character", { fg = c.tertiary })
hl("Number", { fg = c.secondary })
hl("Boolean", { fg = c.secondary, bold = true })
hl("Constant", { fg = c.secondary })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.primary, bold = true })
hl("Keyword", { fg = c.secondary, bold = true })
hl("Statement", { fg = c.secondary, bold = true })
hl("Operator", { fg = c.fgDim })
hl("Type", { fg = c.primary })
hl("PreProc", { fg = c.tertiary, italic = true })
hl("Special", { fg = c.tertiary })
hl("Delimiter", { fg = c.fgDim })
hl("Todo", { fg = c.bg, bg = c.warn, bold = true })
hl("Error", { fg = c.error, bold = true })

-- ── Diagnostics ───────────────────────────────────────────────────────────
--
-- Severity must not follow the wallpaper: an error that turns green because
-- the desktop did has stopped being an error.
hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn", { fg = c.warn })
hl("DiagnosticInfo", { fg = c.primary })
hl("DiagnosticHint", { fg = c.muted })
hl("DiagnosticOk", { fg = c.ok })

-- ── Diffs ─────────────────────────────────────────────────────────────────
hl("DiffAdd", { fg = c.ok })
hl("DiffDelete", { fg = c.error })
hl("DiffChange", { fg = c.warn })
hl("DiffText", { fg = c.warn, bold = true })

-- ── Follow the palette ────────────────────────────────────────────────────
--
-- Started last, so a failure here cannot leave the scheme half-applied.
watch(vim.fn.expand("~/.config/dawn/generated/nvim-colors.lua"))
