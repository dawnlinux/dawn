-- ============================================
-- AUTOSTART
-- ============================================
autostart = {
    -- Extra autostart processes
    -- exec-once = "my-service"
}

-- ============================================
-- BINDINGS
-- ============================================
bindings = {
    -- Application bindings
    { mods = "SUPER", key = "RETURN", action = "exec", command = "xdg-terminal-exec --dir=\"$(pwd)\"" },
    { mods = "SUPER ALT", key = "RETURN", action = "exec", command = "xdg-terminal-exec --dir=\"$(pwd)\" bash -c \"tmux attach || tmux new -s Work\"" },
    { mods = "SUPER SHIFT", key = "RETURN", action = "exec", command = "firefox" },
    { mods = "SUPER SHIFT", key = "F", action = "exec", command = "nautilus --new-window" },
    { mods = "SUPER ALT SHIFT", key = "F", action = "exec", command = "nautilus --new-window \"$(pwd)\"" },
    { mods = "SUPER SHIFT", key = "B", action = "exec", command = "firefox" },
    { mods = "SUPER SHIFT ALT", key = "B", action = "exec", command = "firefox --private-window" },
    { mods = "SUPER SHIFT", key = "M", action = "exec", command = "spotify" },
    { mods = "SUPER SHIFT ALT", key = "M", action = "exec", command = "alacritty -e cmus" },
    { mods = "SUPER SHIFT", key = "N", action = "exec", command = "nvim" },
    { mods = "SUPER SHIFT", key = "D", action = "exec", command = "alacritty -e lazydocker" },
    { mods = "SUPER SHIFT", key = "G", action = "exec", command = "signal-desktop" },
    { mods = "SUPER SHIFT", key = "O", action = "exec", command = "obsidian" },
    { mods = "SUPER SHIFT", key = "W", action = "exec", command = "typora --enable-wayland-ime" },
    { mods = "SUPER SHIFT", key = "SLASH", action = "exec", command = "1password" },

    -- Web apps
    { mods = "SUPER SHIFT", key = "A", action = "exec", command = "firefox --new-window \"https://chatgpt.com\"" },
    { mods = "SUPER SHIFT ALT", key = "A", action = "exec", command = "firefox --new-window \"https://grok.com\"" },
    { mods = "SUPER SHIFT", key = "C", action = "exec", command = "firefox --new-window \"https://app.hey.com/calendar/weeks/\"" },
    { mods = "SUPER SHIFT", key = "E", action = "exec", command = "firefox --new-window \"https://app.hey.com\"" },
    { mods = "SUPER SHIFT", key = "Y", action = "exec", command = "firefox --new-window \"https://youtube.com/\"" },
    { mods = "SUPER SHIFT ALT", key = "G", action = "exec", command = "firefox --new-window \"https://web.whatsapp.com/\"" },
    { mods = "SUPER SHIFT CTRL", key = "G", action = "exec", command = "firefox --new-window \"https://messages.google.com/web/conversations\"" },
    { mods = "SUPER SHIFT", key = "P", action = "exec", command = "firefox --new-window \"https://photos.google.com/\"" },
    { mods = "SUPER SHIFT", key = "X", action = "exec", command = "firefox --new-window \"https://x.com/\"" },
    { mods = "SUPER SHIFT ALT", key = "X", action = "exec", command = "firefox --new-window \"https://x.com/compose/post\"" },

    -- Add extra bindings
    -- { mods = "SUPER SHIFT", key = "R", action = "exec", command = "alacritty -e ssh your-server" },

    -- Overwrite existing bindings
    -- unbind = "SUPER, SPACE"
    -- { mods = "SUPER", key = "SPACE", action = "exec", command = "rofi -show run" },
}

-- ============================================
-- HYPRIDLE
-- ============================================
hypridle = {
    general = {
        lock_cmd = "swaylock -f",  -- Or use your preferred locker
        before_sleep_cmd = "swaylock -f",
        after_sleep_cmd = "sleep 1 && hyprctl dispatch dpms on",
        inhibit_sleep = 3,
    },
    listener = {
        -- Start screensaver after 2.5 minutes
        {
            timeout = 150,
            on_timeout = "pidof hyprlock || hyprlock",  -- Or use xscreensaver, etc.
        },
        -- Lock system after 5 minutes
        {
            timeout = 152,
            on_timeout = "swaylock -f",
            on_resume = "hyprctl dispatch dpms on",
        },
    }
}

-- ============================================
-- HYPRLAND MAIN CONFIG
-- ============================================
-- Source default configurations
source = {
    "~/.config/hypr/monitors.conf",
    "~/.config/hypr/input.conf",
    "~/.config/hypr/bindings.conf",
    "~/.config/hypr/looknfeel.conf",
    "~/.config/hypr/autostart.conf",
}

-- ============================================
-- HYPRLOCK
-- ============================================
hyprlock = {
    general = {
        ignore_empty_input = true,
    },
    background = {
        monitor = "",
        color = "$color",
        path = "~/.config/hypr/background",
        blur_passes = 3,
    },
    animations = {
        enabled = false,
    },
    input_field = {
        monitor = "",
        size = { 650, 100 },
        position = { 0, 0 },
        halign = "center",
        valign = "center",
        inner_color = "$inner_color",
        outer_color = "$outer_color",
        outline_thickness = 4,
        font_family = "Victor Mono",
        font_color = "$font_color",
        placeholder_text = "Enter Password",
        check_color = "$check_color",
        fail_text = "<i>$FAIL ($ATTEMPTS)</i>",
        rounding = 0,
        shadow_passes = 0,
        fade_on_empty = false,
    },
    auth = {
        fingerprint_enabled = false,
    }
}

-- ============================================
-- HYPRSUNSET
-- ============================================
hyprsunset = {
    profile = {
        -- Makes hyprsunset do nothing by default
        {
            time = "07:00",
            identity = true,
        },
        -- To enable nightlight:
        -- {
        --     time = "20:00",
        --     temperature = 4000,
        -- }
    }
}

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

-- ============================================
-- MONITORS
-- ============================================
env = {
    { name = "GDK_SCALE", value = "2" },
}

monitor = {
    { name = "", resolution = "preferred", position = "auto", scale = "auto" },
    -- Good compromise for 27" or 32" 4K monitors
    -- { name = "", resolution = "preferred", position = "auto", scale = "1.6" },
    -- Straight 1x setup
    -- { name = "", resolution = "preferred", position = "auto", scale = "1" },
    -- Portrait/rotated secondary monitor
    -- { name = "DP-2", resolution = "preferred", position = "auto", scale = "1", transform = "1" },
    -- Disable a monitor
    -- { name = "DP-2", action = "disable" },
}

-- ============================================
-- XDPH
-- ============================================
screencopy = {
    allow_token_by_default = true,
    custom_picker_binary = "hyprland-preview-share-picker",
}
