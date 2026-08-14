import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/// Transient "now playing" — what the island becomes when a track changes.
/// Same pane as the expanded panel, minus the clock, with the text given the
/// room the calendar would otherwise take.
Item {
    id: root

    property bool active: true

    implicitWidth: Config.mediaWidth
    implicitHeight: Config.mediaHeight

    MediaPane {
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        // Fixed rather than derived from the island's width: the island sizes
        // itself from this pane, so reading its width back here would close a
        // binding loop.
        textWidth: Config.mediaWidth - Theme.padH * 2 - artSize - Theme.spacing
        active: root.active
    }
}
