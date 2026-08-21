------------------
---- MONITORS ----
------------------
--
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Dawn ships ONE rule: let every output negotiate its own best mode. Anything
-- more specific than that is a statement about hardware Dawn cannot see —
-- a display that lies about its EDID, an HDMI port stuck at 1.4, a scale that
-- only looks right on one panel.
--
-- Those belong in `local.lua`, which is required after this file and can
-- override any output. See modules/local.lua.example.

hl.monitor({
	output   = "",
	mode     = "preferred",
	position = "auto",
	scale    = "auto",
})
