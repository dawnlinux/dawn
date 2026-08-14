--[[ =========================================================================
  HYPRLAND KEYBINDINGS
  Main modifier: SUPER ("Windows" key)
========================================================================== ]]

-- =============================================================
-- PROGRAMS
-- Set the apps that keybinds below will launch
-- =============================================================

local terminal    = "kitty"
local fileManager = "nautilus"

local mainMod     = "SUPER"


-- =============================================================
-- CORE / SYSTEM
-- =============================================================

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Open Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "Open File Manager" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"), { description = "Open Browser" })
-- Absolute path on purpose: Hyprland inherits the login environment, which has
-- no ~/.local/bin on PATH (fish adds it, and Hyprland never sources fish), so a
-- bare "typist" here silently finds nothing.
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/typist"),
	{ description = "Typing Test" })
-- The launcher lives in the dawn-island shell, which registers a global
-- shortcut named "quickshell:launcher" (appid + Config.launcherShortcut).
-- Dispatching to it rather than exec'ing keeps the key working across shell
-- restarts, and does nothing at all when the shell isn't running.
hl.bind(mainMod .. " + SPACE", hl.dsp.global("quickshell:launcher"),
	{ description = "App Launcher (dawn-island)" })

-- Keyboard-driven island. SUPER+I opens the status panel (wifi, bluetooth,
-- battery, volume, brightness) where arrows navigate, Enter toggles and Escape
-- closes; SUPER+PERIOD is the keyboard equivalent of hovering the notch.
hl.bind(mainMod .. " + I", hl.dsp.global("quickshell:status"),
	{ description = "Status Panel (dawn-island)" })
hl.bind(mainMod .. " + PERIOD", hl.dsp.global("quickshell:island"),
	{ description = "Toggle Island Panel (dawn-island)" })
-- SUPER+SHIFT+W: wallpaper carousel. ←→ browses ~/Pictures/Wallpapers,
-- Enter applies it through awww with a random transition.
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:wallpaper"),
	{ description = "Wallpaper Carousel (dawn-island)" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/quickshell/dawn-island/launch.sh"),
	{ description = "Restart Shell (dawn-island)" })
-- The island owns org.freedesktop.Notifications now, so swaync is gone and
-- swaync-client was a no-op. ↑↓ walks the history, Enter runs the
-- notification's action, Backspace dismisses, d silences.
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:notifications"),
	{ description = "Notification Centre (dawn-island)" })
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("flameshot gui --clipboard"), { description = "Screenshot" })

-- Session menu: lock / sleep / log out / restart / shut down, as a carousel in
-- the island. Replaces the old straight-to-shutdown bind, which had no
-- confirmation and no way back out. Destructive entries ask twice.
hl.bind(mainMod .. " + M", hl.dsp.global("quickshell:power"),
	{ description = "Session Menu (dawn-island)" })

-- Global clipboard (requires wtype)
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("wtype -M ctrl -M shift c -m shift -m ctrl"),
	{ description = "Clipboard Copy" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("wtype -M ctrl -M shift v -m shift -m ctrl"),
	{ description = "Clipboard Paste" })


-- =============================================================
-- WINDOW MANAGEMENT (basic)
-- =============================================================

local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close Window" })
-- closeWindowBind:set_enabled(false)

hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle Floating" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(), { description = "Toggle Fullscreen" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle Pseudotile" })
hl.bind(mainMod .. " + X", hl.dsp.window.pin(), { description = "Pin Window" })
hl.bind(mainMod .. " + Y", hl.dsp.layout("togglesplit"), { description = "Toggle Window Split" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"), { description = "Toggle Split (dwindle only)" })

hl.bind(
	"SUPER + SHIFT + D",
	hl.dsp.window.pseudo({ action = "toggle" }),
	{ description = "Toggle Pseudo (alt)" }
)

-- Smart float: floats + centers + resizes to 90% of monitor, or unfloats
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
	{ description = "Smart Float (center + resize to 90%)" }
)

-- Move/resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag Window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize Window" })


-- =============================================================
-- FOCUS MOVEMENT (vim-style + arrows)
-- =============================================================

-- Arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus Left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus Right" })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus Up" })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus Down" })

-- Vim-style (hjkl), repeating for hold-to-move
hl.bind("SUPER + h", hl.dsp.focus({ direction = "l" }), { description = "Focus Left", repeating = true })
hl.bind("SUPER + l", hl.dsp.focus({ direction = "r" }), { description = "Focus Right", repeating = true })
hl.bind("SUPER + k", hl.dsp.focus({ direction = "u" }), { description = "Focus Up", repeating = true })
hl.bind("SUPER + j", hl.dsp.focus({ direction = "d" }), { description = "Focus Down", repeating = true })


-- =============================================================
-- WINDOW MOVEMENT (vim-style, SHIFT + hjkl)
-- =============================================================

hl.bind("SUPER + SHIFT + h", hl.dsp.window.move({ direction = "l" }),
	{ description = "Move Window Left", repeating = true })
hl.bind("SUPER + SHIFT + l", hl.dsp.window.move({ direction = "r" }),
	{ description = "Move Window Right", repeating = true })
hl.bind("SUPER + SHIFT + k", hl.dsp.window.move({ direction = "u" }),
	{ description = "Move Window Up", repeating = true })
hl.bind("SUPER + SHIFT + j", hl.dsp.window.move({ direction = "d" }),
	{ description = "Move Window Down", repeating = true })


-- =============================================================
-- WINDOW RESIZING (arrows)
-- =============================================================

hl.bind("SUPER + right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }),
	{ description = "Resize Width +", repeating = true })
hl.bind("SUPER + left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }),
	{ description = "Resize Width -", repeating = true })
hl.bind("SUPER + up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }),
	{ description = "Resize Height -", repeating = true })
hl.bind("SUPER + down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }),
	{ description = "Resize Height +", repeating = true })


-- =============================================================
-- WORKSPACES
-- =============================================================

-- Switch workspaces: mainMod + [0-9]
-- Move active window to workspace: mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Go to Workspace " .. key })
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
		{ description = "Move Window to Workspace " .. key })
end

hl.bind(
	"SUPER + TAB",
	hl.dsp.focus({ workspace = "previous" }),
	{ description = "Last Workspace", repeating = true }
)

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next Workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous Workspace" })

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle Scratchpad" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
	{ description = "Move Window to Scratchpad" })


-- =============================================================
-- MEDIA KEYS (audio, mic, brightness — requires playerctl)
-- =============================================================

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Mac keyboard backlight
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl --device='smc::kbd_backlight' set +10%"),
	{ locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl --device='smc::kbd_backlight' set 10%-"),
	{ locked = true, repeating = true })
