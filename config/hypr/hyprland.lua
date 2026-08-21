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
-- `modules/local.lua` is gitignored. It is where anything true of YOUR
-- hardware and no one else's belongs: monitor modes, GPU driver hints,
-- vendor-specific device names, per-host keybinds.
--
-- Required last so it can override every module above, and wrapped in pcall
-- so that not having one is normal rather than a startup failure — a fresh
-- Dawn install has no local.lua and must still boot to a desktop.
--
-- Start from `modules/local.lua.example`.
local ok, err = pcall(require, "modules.local")

if not ok and not tostring(err):find("not found", 1, true) then
	-- A local.lua that EXISTS but is broken must be loud, otherwise you get a
	-- desktop that quietly ignores your config for reasons nothing on screen
	-- explains. A missing one is silent, because that is the normal case.
	--
	-- This lands in the Hyprland log:  hyprctl rollinglog | grep '^dawn:'
	print("dawn: modules/local.lua failed to load -- " .. tostring(err))
end
