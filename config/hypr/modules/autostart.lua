-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
  -- dawn-island: the Dynamic Island shell. Replaces waybar's top bar.
  hl.exec_cmd("qs -p ~/.config/quickshell/dawn-island/shell.qml")

  -- waybar is disabled because dawn-island now owns the top edge and reserves
  -- an exclusive zone there; running both stacks two bars on top of each other.
  -- Uncomment to go back to waybar (and set exclusiveZone = 0 in the island's
  -- Config.qml, or drop the island line above).
  -- hl.exec_cmd("waybar")

  -- swaync keeps org.freedesktop.Notifications. The island can serve
  -- notifications itself instead — only one process can own that bus name, so
  -- comment this out if you want notifications inside the island.
  hl.exec_cmd("swaync")

  hl.exec_cmd("awww-daemon")
end)
