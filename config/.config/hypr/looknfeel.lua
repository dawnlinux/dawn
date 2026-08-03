-- ============================================
-- LOOK AND FEEL
-- ============================================
colors = {
    activeBorderColor = "rgb(aaacac)",
    secondaryBorderColor = "rgb(000000)",
    white = "rgb(ffffff)",
    black = "rgb(000000)",
}

general = {
    -- gaps_in = 0,
    -- gaps_out = 0,
    -- border_size = 0,
    col_active_border = "rgb(000000) rgb(000000) rgb(000000) rgb(ffffff) rgb(000000) rgb(000000) rgb(000000) rgb(ffffff) 25deg",
    col_inactive_border = "rgb(000000)",
    -- layout = "scrolling",
}

group = {
    col_border_active = "$activeBorderColor",
}

decoration = {
    rounding = 8,
    -- dim_inactive = true,
    -- dim_strength = 0.15,
    inactive_opacity = 0.85,
    fullscreen_opacity = 0.85,
    active_opacity = 0.85,
}

animations = {
    enabled = true,
    bezier = {
        { name = "easeSoft", value = "0.18, 0.62, 0.32, 1.00" },
        { name = "easeFade", value = "0.28, 0.00, 0.22, 1.00" },
    },
    animation = {
        { name = "windows", duration = 1, time = 2.6, bezier = "easeSoft" },
        { name = "windowsIn", duration = 1, time = 2.4, bezier = "easeSoft" },
        { name = "windowsOut", duration = 1, time = 2.2, bezier = "easeFade" },
        { name = "windowsMove", duration = 1, time = 2.8, bezier = "easeSoft" },
        { name = "fade", duration = 1, time = 2.2, bezier = "easeFade" },
        { name = "fadeIn", duration = 1, time = 2.0, bezier = "easeSoft" },
        { name = "fadeOut", duration = 1, time = 1.8, bezier = "easeFade" },
        { name = "fadeDim", duration = 1, time = 1.8, bezier = "easeFade" },
        { name = "layers", duration = 1, time = 2.2, bezier = "easeSoft" },
        { name = "layersIn", duration = 1, time = 2.0, bezier = "easeSoft" },
        { name = "layersOut", duration = 1, time = 1.8, bezier = "easeFade" },
        { name = "workspaces", duration = 1, time = 2.4, bezier = "easeSoft" },
        { name = "specialWorkspace", duration = 1, time = 2.2, bezier = "easeSoft" },
        { name = "border", duration = 1, time = 2.8, bezier = "easeSoft" },
        { name = "borderangle", duration = 1, time = 150, bezier = "linear", extra = "loop" },
        { name = "fadeSwitch", duration = 1, time = 1.4, bezier = "easeFade" },
    }
}

layout = {
    -- single_window_aspect_ratio = "1 1",
}

scrolling = {
    -- column_width = 0.97,
}
