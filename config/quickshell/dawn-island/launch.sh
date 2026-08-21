#!/bin/bash
#
# Restart dawn-island. Bound to Super+R.
#
# Note that you rarely need this: Quickshell hot-reloads whenever a file under
# ~/.config/quickshell/dawn-island changes, so editing the config already
# updates the running shell. This is for reloading hyprland.conf alongside it,
# or for recovering if the shell is wedged.

SHELL_QML="$HOME/.config/quickshell/dawn-island/shell.qml"

# Match on the config path, not on "qs" — otherwise this kills any other
# Quickshell config you happen to be running.
pkill -f "qs -p $SHELL_QML"

hyprctl reload

# Wait for the layer surface to actually go away before claiming the top edge
# again; relaunching into the old surface leaves a dead exclusive zone behind.
for _ in $(seq 20); do
	pgrep -f "qs -p $SHELL_QML" >/dev/null || break
	sleep 0.05
done

qs -p "$SHELL_QML" &

disown
