------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- HDMI is 1.4a on this machine, so "preferred" on a 4K TV negotiates 2160p@30
-- and everything feels laggy. Force 1080p60 and an integer scale instead.
for _, out in ipairs({ "HDMI-A-1", "HDMI-A-2", "HDMI-A-3" }) do
    hl.monitor({
        output   = out,
        mode     = "1920x1080@60",
        position = "auto",
        scale    = 1,
    })
end

-- Catch-all for everything else (internal panel, DisplayPort).
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
