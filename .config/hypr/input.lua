-- ============================================
-- INPUT
-- ============================================
input = {
    kb_layout = "us",
    kb_options = "compose:caps",
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,
    -- sensitivity = 0.35,
    -- accel_profile = "flat",
    touchpad = {
        -- natural_scroll = true,
        clickfinger_behavior = true,
        scroll_factor = 0.4,
        -- disable_while_typing = false,
        -- drag_3fg = 1,
    }
}

-- Scroll nicely in the terminal
windowrule = {
    { class = "Alacritty|kitty|foot", rule = "scroll_touchpad 1.5" },
    { class = "com.mitchellh.ghostty", rule = "scroll_touchpad 0.2" },
}

-- Enable touchpad gestures for changing workspaces
gesture = {
    { fingers = 4, direction = "horizontal", action = "workspace" },
    -- Enable touchpad gestures for moving focus
    -- { fingers = 3, direction = "left", action = "dispatcher, movefocus, l" },
    -- { fingers = 3, direction = "right", action = "dispatcher, movefocus, r" },
}
