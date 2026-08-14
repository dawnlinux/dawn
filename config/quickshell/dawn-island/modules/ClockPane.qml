import QtQuick
import "root:/"
import "root:/theme"
import "root:/components"
import "root:/services"

/*
 * Time over a week strip — the right half of the reference layout.
 *
 * The clock is centred over the strip rather than left-aligned with it,
 * because the strip is symmetrical about today and an off-centre clock makes
 * the whole pane look accidentally misaligned.
 */
Item {
    id: root

    property real columnWidth: 20

    implicitWidth: strip.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Clock.time24
            color: Theme.text
            font.family: Typography.family
            font.pixelSize: Typography.clock
            font.weight: Typography.medium
            font.letterSpacing: Typography.trackingTight
            font.features: Typography.tabular
        }

        CalendarStrip {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Config.showCalendar
            today: Clock.now
            columnWidth: root.columnWidth
        }
    }
}
