-------------------
---- AUTOSTART ----
-------------------
--
-- Everything Hyprland launches once, at compositor start.
--
-- Keep this list short. Each entry here is a process that runs for the whole
-- session on every boot, so anything that could be started on demand instead
-- does not belong in this file.

hl.on("hyprland.start", function()
	-- dawn-island: the shell. Owns the top edge — status bar, app launcher,
	-- media controls, the session menu and the wallpaper carousel are all in
	-- here, so this single process replaces what would otherwise be a bar, a
	-- launcher and a power menu.
	hl.exec_cmd("qs -p ~/.config/quickshell/dawn-island/shell.qml")

	-- swaync owns org.freedesktop.Notifications and draws the notification
	-- popups and centre. Only one process can own that bus name, so if the
	-- island ever serves notifications itself, this line goes.
	hl.exec_cmd("swaync")

	-- awww-daemon: the wallpaper daemon. The island's wallpaper carousel
	-- talks to it, and it is what publishes the current wallpaper to the
	-- login screen (see config/greetd/install.sh).
	hl.exec_cmd("awww-daemon")
end)
