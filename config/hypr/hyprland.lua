--[[ =========================================================================
  DAWN — HYPRLAND ENTRY POINT

  Each module owns one concern. Order matters only in that `local` comes last:
  it is the machine-specific override layer and has to be able to win.
========================================================================== ]]

require("modules.monitors")
require("modules.binds")
require("modules.autostart")
require("modules.env")
require("modules.decorations")
require("modules.misc")
require("modules.input")
require("modules.windowrules")

-- ── Machine-local overrides ──────────────────────────────────────────────
--
-- `~/.config/dawn/local.lua` is where anything true of YOUR hardware and no
-- one else's belongs: monitor modes, GPU driver hints, vendor-specific device
-- names, per-host keybinds.
--
-- It lives outside ~/.config/hypr on purpose. Dawn's shipped config is owned
-- by pacman and read-only, so an override cannot sit beside the files it
-- overrides. ~/.config/dawn/ is the one directory Dawn never writes to after
-- seeding it.
--
-- Loaded last so it can override every module above. loadfile() rather than
-- require() because the file is outside package.path, and stretching that to
-- reach an absolute home directory is worse than just reading the file.
--
-- Start from /usr/share/dawn/examples/local.lua.

local home     = os.getenv("HOME")
local override = home .. "/.config/dawn/local.lua"
local errfile  = home .. "/.config/dawn/last-error"

-- Reporting a broken override is harder than it looks. Hyprland's Lua config
-- has no `hl.notify`, and `print()` from here reaches neither hyprland.log nor
-- `hyprctl rollinglog` — both were tested. So a failure is recorded two ways:
--
--   1. to a file, which always works and which `dawn status` surfaces
--   2. via notify-send, which makes it visible immediately IF a notification
--      daemon is already up — at boot it usually is not, which is precisely
--      why the file is written first rather than instead.
--
-- A desktop that silently ignores your config has no visible cause, and that
-- is the failure this exists to prevent.
local function report(msg)
	local f = io.open(errfile, "w")
	if f then
		f:write(msg .. "\n")
		f:close()
	end
	hl.exec_cmd(string.format("notify-send -u critical 'Dawn' %q", msg))
end

local function clear_report()
	os.remove(errfile)
end

local chunk, load_err = loadfile(override)

if chunk then
	-- Parsed. If it THROWS at runtime, that still has to be reported.
	local ok, run_err = pcall(chunk)
	if ok then
		clear_report()
	else
		report("~/.config/dawn/local.lua failed: " .. tostring(run_err))
	end
elseif load_err and not tostring(load_err):find("No such file", 1, true) then
	-- Exists but could not be read or parsed — a syntax error, or bad
	-- permissions. A MISSING file is the normal case and stays silent: a
	-- fresh Dawn install has no local.lua and must still boot to a desktop.
	report("~/.config/dawn/local.lua could not be read: " .. tostring(load_err))
else
	clear_report()
end
