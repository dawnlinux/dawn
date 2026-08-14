import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

/*
 * dawn-island — an Apple-style Dynamic Island for Hyprland.
 *
 * One layer-shell window per screen, spanning the full width of the top edge
 * but masked down to the island's own silhouette, so everywhere else on that
 * strip still belongs to your windows. The window is deliberately larger than
 * the island: the shape springs, occasionally past its target, and a window
 * sized exactly to the resting notch would clip the overshoot.
 *
 * Layout is the shell's job; the island itself knows nothing about screens.
 */
ShellRoot {
    id: shell

    /// Services → island. One instance for the whole shell, not per screen.
    EventRouter {}

    /*
     * Driving the island from the keyboard.
     *
     * Quickshell 0.3.0 has no IpcHandler, so there is no `qs ipc call` to bind
     * a key to. Hyprland's global-shortcuts protocol is the way in: the shell
     * registers each shortcut, and hyprland.conf routes a key to it with
     * `hl.dsp.global("quickshell:launcher")`. That also means the bindings
     * survive config reloads without the shell knowing anything about keys.
     *
     * Three ways in, deliberately: search (launcher), read and toggle (status),
     * and glance (the expanded panel). Everything past that point is handled by
     * the panel that has focus.
     */
    GlobalShortcut {
        appid: "quickshell"
        name: Config.launcherShortcut
        description: "Toggle the dawn-island app launcher"
        onPressed: Launcher.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: Config.statusShortcut
        description: "Toggle the dawn-island status panel"
        onPressed: Nav.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: Config.wallpaperShortcut
        description: "Toggle the dawn-island wallpaper carousel"
        onPressed: Wallpaper.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: Config.islandShortcut
        description: "Toggle the dawn-island expanded panel"
        onPressed: Nav.togglePanel()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData

            screen: modelData

            readonly property bool onFocusedMonitor: {
                const mine = Hypr.monitorFor(modelData);
                const focused = Hypr.focusedMonitor;
                return mine !== null && focused !== null && mine.id === focused.id;
            }

            visible: Config.followFocusedMonitor
                     ? onFocusedMonitor
                     : (Config.monitors.length === 0
                        || Config.monitors.indexOf(modelData.name) !== -1)

            WlrLayershell.namespace: Config.layerNamespace
            WlrLayershell.layer: WlrLayer.Top

            /// Only while the launcher is up. A bar that permanently holds
            /// keyboard focus takes every keystroke on the machine.
            WlrLayershell.keyboardFocus: island.wantsKeyboard
                                         ? WlrKeyboardFocus.Exclusive
                                         : WlrKeyboardFocus.None

            anchors.top: true
            anchors.left: true
            anchors.right: true

            color: "transparent"

            /// Room for the tallest view, the top margin, and the shadow.
            implicitHeight: Config.topMargin
                            + Math.max(Config.expandedHeight,
                                       Config.notificationHeight,
                                       Config.mediaHeight,
                                       Config.pillHeight + 8,
                                       Config.islandHeight,
                                       Config.launcherSearchHeight
                                         + Config.launcherMaxRows * Config.launcherRowHeight
                                         + 20,
                                       Config.statusHeaderHeight
                                         + 5 * Config.statusRowHeight
                                         + 20,
                                       Config.wallpaperHeaderHeight
                                         + Config.wallpaperTileHeight
                                         + 70)
                            + Config.shadowPadding

            /// Windows must not tile under the notch, but they may tile under
            /// the space the island only occasionally grows into.
            exclusiveZone: Config.exclusiveZone

            /// Everything outside the island's own outline belongs to whatever
            /// is underneath — without this the whole top strip would swallow
            /// clicks meant for your windows.
            mask: Region { item: island }

            /*
             * Click anywhere else to dismiss the launcher.
             *
             * The grab is armed on a short delay rather than bound directly to
             * `wantsKeyboard`. Taking keyboard focus is itself a focus change,
             * and a grab installed in the same frame is cleared by the very
             * change that opened the launcher — it opened and shut instantly.
             * Letting focus settle first is the whole fix.
             *
             * It is also only held while the launcher is up; a permanent grab
             * would make the rest of the desktop unclickable.
             */
            HyprlandFocusGrab {
                id: grab
                windows: [panel]
                onCleared: {
                    if (!island.wantsKeyboard)
                        return;
                    // Whichever panel is holding focus is the one that just
                    // lost it; closing both is simpler than asking which.
                    Launcher.hide();
                    Nav.hide();
                    Wallpaper.hide();
                }
            }

            Timer {
                id: armGrab
                interval: 120
                onTriggered: if (island.wantsKeyboard && panel.visible) grab.active = true
            }

            onVisibleChanged: if (!visible) grab.active = false

            Connections {
                target: island
                function onWantsKeyboardChanged() {
                    if (island.wantsKeyboard) {
                        armGrab.restart();
                    } else {
                        armGrab.stop();
                        grab.active = false;
                    }
                }
            }

            DynamicIsland {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: Config.topMargin
            }
        }
    }
}
