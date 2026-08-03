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
