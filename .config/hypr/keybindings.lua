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
