import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/components"
import "root:/services"

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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
                                       Config.islandHeight)
                            + Config.shadowPadding

            /// Windows must not tile under the notch, but they may tile under
            /// the space the island only occasionally grows into.
            exclusiveZone: Config.exclusiveZone

            /// Everything outside the island's own outline belongs to whatever
            /// is underneath — without this the whole top strip would swallow
            /// clicks meant for your windows.
            mask: Region { item: island }

            DynamicIsland {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: Config.topMargin
            }
        }
    }
}
