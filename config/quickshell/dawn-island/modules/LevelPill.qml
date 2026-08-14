import QtQuick
import qs
import qs.theme
import qs.components

/*
 * The volume / brightness pill: icon, track, percentage.
 *
 * Anchored rather than laid out in a Row so the track absorbs the slack — the
 * icon and the readout keep fixed positions while only the bar changes length,
 * which is what stops the pill twitching as the number goes from 9% to 100%.
 * The readout is right-aligned in a fixed box for the same reason.
 */
Item {
    id: root

    property string icon: ""
    property string glyph: ""
    /// 0..1
    property real level: 0
    property bool muted: false
    property color tint: Theme.text
    /// Shown instead of the percentage when set (e.g. "Muted").
    property string overrideText: ""

    /// Set false while dragging so the fill tracks the pointer exactly.
    property bool trackLive: true

    signal scrubbed(real fraction)

    implicitWidth: Config.pillWidth
    implicitHeight: Config.pillHeight

    Icon {
        id: symbol
        anchors.left: parent.left
        anchors.leftMargin: Theme.padH
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        fallbackGlyph: root.glyph
        size: 17
        color: root.tint
        level: root.level
        muted: root.muted

        // A small kick each time the icon's meaning changes, so a repeated
        // keypress reads as "again" rather than as a static image.
        SequentialAnimation on scale {
            id: kick
            running: false
            NumberAnimation { to: 1.16; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 260; easing.type: Easing.OutBack }
        }
    }

    onLevelChanged: if (Config.animationsEnabled) kick.restart()
    onMutedChanged: if (Config.animationsEnabled) kick.restart()

    Text {
        id: readout
        anchors.right: parent.right
        anchors.rightMargin: Theme.padH
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        horizontalAlignment: Text.AlignRight
        text: root.overrideText !== "" ? root.overrideText
                                       : Math.round(root.level * 100) + "%"
        color: root.muted ? Theme.textTertiary : Theme.textSecondary
        font.family: Typography.family
        font.pixelSize: Typography.caption + 1
        font.weight: Typography.medium
        font.features: Typography.tabular
        ColorBehavior on color {}
    }

    LevelBar {
        id: bar
        anchors.left: symbol.right
        anchors.leftMargin: Theme.spacing
        anchors.right: readout.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        thickness: Theme.trackThickness
        value: root.muted ? 0 : root.level
        animated: root.trackLive
        fillColor: root.tint
        trackColor: Theme.surfaceHighest
    }

    // Grown past the bar so the 4px track is actually hittable; the extra
    // margin is subtracted back out before turning x into a fraction.
    MouseArea {
        id: scrub
        anchors.fill: bar
        anchors.margins: -10
        cursorShape: Qt.PointingHandCursor

        function fractionAt(x) {
            return Math.max(0, Math.min(1, (x - 10) / bar.width));
        }

        onPressed: function (ev) { root.scrubbed(fractionAt(ev.x)); }
        onPositionChanged: function (ev) {
            if (pressed)
                root.scrubbed(fractionAt(ev.x));
        }
    }
}
