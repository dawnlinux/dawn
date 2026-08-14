import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.theme
import qs.services
import qs.modules

/*
 * The island.
 *
 * Three ideas hold this together:
 *
 *  1. Content decides the shape. Each view reports an implicit size; the island
 *     springs its own width and height towards whatever the current view asks
 *     for. Nothing anywhere hardcodes "the volume pill is 258 wide" outside the
 *     view that draws it, so adding a state is adding one file.
 *
 *  2. There is exactly one surface. The expanded panel is not a popup drawn
 *     under the notch — it is the notch, at a different size. That is the
 *     entire illusion, and it is why the shape morph runs on a spring that
 *     carries velocity through interruptions rather than on a fixed curve.
 *
 *  3. Hover and click are local; everything else is global. Two monitors
 *     showing the island share the volume state but not the hover, which is
 *     the behaviour you want in both cases.
 */
Item {
    id: root

    /// The view actually on screen.
    ///
    /// The launcher and the status panel win outright — they are the states the
    /// user opened on purpose, and having a hover or a notification yank one
    /// away mid-search would be indefensible. Below those, hovering or pinning
    /// outranks the state machine: while you are looking at the island directly
    /// you want the panel, not whatever briefly happened.
    readonly property string viewState:
          IslandState.current === "launcher"          ? "launcher"
        : IslandState.current === "power"             ? "power"
        : IslandState.current === "wallpaper"         ? "wallpaper"
        : IslandState.current === "notifcenter"       ? "notifcenter"
        : IslandState.current === "status"            ? "status"
        : (pinned || hoverExpanded || Nav.panelPinned) ? "expanded"
        : IslandState.current

    /// The shell needs to know when to take keyboard focus. Only the panels
    /// that read keystrokes ask for it — an island that held focus while merely
    /// expanded would take every keystroke on the machine.
    readonly property bool wantsKeyboard:
        viewState === "launcher" || viewState === "status"
        || viewState === "wallpaper" || viewState === "notifcenter"
        || viewState === "power"

    property bool hoverExpanded: false
    property bool pinned: false

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool showingPanel: viewState === "expanded"

    /// What the island wants to be, before the spring gets to it.
    readonly property real targetWidth: Math.max(Config.islandWidth, host.contentWidth)
    readonly property real targetHeight: Math.max(Config.islandHeight, host.contentHeight)

    width: targetWidth
    height: targetHeight

    MorphBehavior on width {}
    MorphBehavior on height {}

    // ── Shadow + body ─────────────────────────────────────────────────────
    //
    // The surface is rendered into a layer and drawn by the effect, so the
    // shadow follows the real rounded silhouette instead of approximating it.
    // Falls back to drawing the surface directly when shadows are off.

    IslandSurface {
        id: surface
        anchors.fill: parent
        hovered: root.hovered
        visible: !Theme.shadowEnabled
        layer.enabled: Theme.shadowEnabled
    }

    MultiEffect {
        anchors.fill: surface
        source: surface
        visible: Theme.shadowEnabled
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowOpacity: Theme.shadowOpacity
        shadowBlur: 1.0
        blurMax: Theme.shadowRadius
        shadowVerticalOffset: Theme.shadowOffset
        shadowHorizontalOffset: 0
    }

    // ── Content ───────────────────────────────────────────────────────────
    //
    // Clipped to a rounded box so a view that is wider than the island — which
    // every view is, for the moment between the content swapping and the
    // spring catching up — is cut to the island's shape instead of spilling
    // out of it.

    ClippingRectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Config.topMargin > 0 ? Config.floatingRadius : Config.cornerRadius

        ContentHost {
            id: host
            anchors.fill: parent
            content: root.componentFor(root.viewState)
        }
    }

    // ── State → view ──────────────────────────────────────────────────────

    function componentFor(state) {
        switch (state) {
        case "launcher":     return launcherView;
        case "power":        return powerView;
        case "wallpaper":    return wallpaperView;
        case "notifcenter":  return notifCenterView;
        case "status":       return statusView;
        case "expanded":     return expandedView;
        case "notification": return notificationView;
        case "volume":       return volumeView;
        case "brightness":   return brightnessView;
        case "clipboard":    return clipboardView;
        case "workspace":    return workspaceView;
        case "battery":      return batteryView;
        case "network":      return networkView;
        case "bluetooth":    return bluetoothView;
        case "media":        return mediaView;
        default:             return idleView;
        }
    }

    Component {
        id: idleView
        IdleView { onLogoClicked: Launcher.toggle() }
    }

    Component { id: launcherView; LauncherView {} }
    Component { id: statusView; StatusView {} }
    Component { id: wallpaperView; WallpaperView {} }
    Component { id: powerView; PowerView {} }
    Component { id: notifCenterView; NotifCenterView {} }
    Component { id: volumeView; VolumeView {} }
    Component { id: brightnessView; BrightnessView {} }
    Component { id: workspaceView; WorkspaceView {} }
    Component { id: batteryView; BatteryView {} }
    Component { id: networkView; NetworkView {} }
    Component { id: bluetoothView; BluetoothView {} }

    Component {
        id: mediaView
        MediaView { active: root.viewState === "media" }
    }

    Component {
        id: expandedView
        ExpandedView { active: root.viewState === "expanded" }
    }

    // Payload-carrying views capture their data once at creation rather than
    // binding to IslandState.payload: the payload is already gone by the time
    // the outgoing copy has finished fading, and a bound view would blank out
    // halfway through its own exit animation.
    Component {
        id: notificationView
        NotificationView {
            Component.onCompleted: notification = IslandState.payload
        }
    }

    Component {
        id: clipboardView
        ClipboardView {
            Component.onCompleted: entry = IslandState.payload
        }
    }

    // ── Interaction ───────────────────────────────────────────────────────
    //
    // Pointer handlers rather than a MouseArea: a MouseArea covering the
    // island would sit either above the transport buttons (and eat their
    // clicks) or below them (and never see a hover). Handlers on the island
    // itself see everything without competing with the buttons inside it.

    // While the launcher is open the island belongs to it: hovering must not
    // yank the panel out from under a search, clicking a result must not also
    // toggle the pin, and scrolling should move the result list rather than
    // the volume.

    HoverHandler {
        id: hoverHandler
        enabled: Config.expandOnHover && !root.wantsKeyboard
        onHoveredChanged: {
            if (hovered) {
                closeTimer.stop();
                openTimer.restart();
            } else {
                openTimer.stop();
                closeTimer.restart();
            }
        }
    }

    Timer {
        id: openTimer
        interval: Config.hoverOpenDelay
        onTriggered: root.hoverExpanded = true
    }

    Timer {
        id: closeTimer
        interval: Config.hoverCloseDelay
        onTriggered: root.hoverExpanded = false
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: Config.expandOnClick && !root.wantsKeyboard
        onTapped: {
            // The keyboard pin and the click pin are one affordance reached
            // two ways, so clicking a keyboard-opened panel closes it rather
            // than fighting it.
            if (Nav.panelPinned) {
                Nav.panelPinned = false;
                root.pinned = false;
                return;
            }
            root.pinned = !root.pinned;
            if (root.pinned)
                root.hoverExpanded = true;
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (root.viewState === "launcher")
                Launcher.hide();
            else if (root.viewState === "wallpaper")
                Wallpaper.hide();
            else if (root.viewState === "notifcenter")
                Notifs.hide();
            else if (root.viewState === "power")
                Session.hide();
            else if (root.viewState === "status")
                Nav.hide();
            else if (Config.rightClickCommand !== "")
                Quickshell.execDetached(["sh", "-c", Config.rightClickCommand]);
            else {
                root.pinned = false;
                Nav.panelPinned = false;
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        enabled: !root.wantsKeyboard
        onTapped: Audio.toggleMute()
    }

    WheelHandler {
        enabled: Config.scrollToChangeVolume && !root.wantsKeyboard
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (ev) {
            // Touchpads deliver many small deltas and a mouse wheel delivers
            // few large ones; normalising by 120 (one notch) makes both feel
            // like the same control.
            Audio.step((ev.angleDelta.y / 120) * 0.03);
        }
    }

    // Un-pin when the state machine has something genuinely urgent to say.
    Connections {
        target: IslandState
        function onStateEntered(state) {
            if (state === "notification")
                root.pinned = false;
        }
    }
}
