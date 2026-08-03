---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "./.config/rofi/type-1/launcher.sh"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier


-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/waybar/launch.sh"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. "+ SHIFT + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client --toggle-panel"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Global clipboard
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("wtype -M ctrl -M shift c -m shift -m ctrl"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("wtype -M ctrl -M shift v -m shift -m ctrl"))

-- Screenshot
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("flameshot full"))

-- Open browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))

-- Mac keyboard backlight
hl.bind("XF86KbdBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl --device='smc::kbd_backlight' set +10%"),
    { locked = true, repeating = true }
)

hl.bind("XF86KbdBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl --device='smc::kbd_backlight' set 10%-"),
    { locked = true, repeating = true }
)


-- =============================
-- Advanced window management
-- =============================

hl.bind(mainMod .. " + X", hl.dsp.window.pin(), { description = "Pin Window" })
hl.bind(mainMod .. " + Y", hl.dsp.layout("togglesplit"), { description = "Toggle Window Split" })

hl.bind(
    mainMod .. " + D",
    hl.dsp.exec_cmd([[
        if hyprctl activewindow | grep -q 'floating: 0'; then
            W=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.width / .scale) * 0.9) | floor')
            H=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.height / .scale) * 0.9) | floor')
            hyprctl --batch "dispatch hl.dsp.window.float({action='set'}); dispatch hl.dsp.window.resize({x=${W}, y=${H}, relative=false})"
            hyprctl dispatch "hl.dsp.window.center()"
        else
            hyprctl dispatch "hl.dsp.window.float({action='unset'})"
        fi
    ]]),
    { description = "Smart Float" }
)

hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.window.pseudo({ action = "toggle" }),
    { description = "Toggle Pseudo" }
)

-- --- Focus Movement ---
hl.bind(
    "SUPER + h",
    hl.dsp.focus({ direction = "l" }),
    { description = "Focus Left", repeating = true }
)

hl.bind(
    "SUPER + l",
    hl.dsp.focus({ direction = "r" }),
    { description = "Focus Right", repeating = true }
)

hl.bind(
    "SUPER + k",
    hl.dsp.focus({ direction = "u" }),
    { description = "Focus Up", repeating = true }
)

hl.bind(
    "SUPER + j",
    hl.dsp.focus({ direction = "d" }),
    { description = "Focus Down", repeating = true }
)
