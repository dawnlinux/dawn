import QtQuick
import "root:/"
import "root:/theme"

/*
 * The week strip from the reference: seven columns centred on today, weekday
 * initial above the date, today in a rounded pill, weekends accented, and the
 * outer columns falling away in opacity so the strip reads as a window onto a
 * longer calendar rather than a boxed-in widget.
 *
 * `today` is injected rather than read from a clock here, so the whole shell
 * shares exactly one timer (see services/Clock.qml).
 */
Item {
    id: root

    property date today: new Date()
    /// Must be odd so "today" sits in the middle.
    property int days: 7
    property real columnWidth: 25
    property real rowSpacing: 3

    readonly property int mid: Math.floor(days / 2)

    /// Row heights, stated rather than measured. Every column is identical, so
    /// deriving the strip's height from the Row — whose height is its tallest
    /// child, which is sized from the strip — would close a binding loop and
    /// collapse the whole strip to nothing.
    property real weekdayHeight: Math.ceil(Typography.micro * 1.45)
    property real dateHeight: 21

    implicitWidth: days * columnWidth
    implicitHeight: weekdayHeight + rowSpacing + dateHeight

    /// Opacity falloff from the centre column outwards.
    function falloff(i) {
        const d = Math.abs(i - mid) / mid;
        return 1.0 - 0.82 * Math.pow(d, 1.25);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.days

            delegate: Item {
                id: col
                required property int index

                readonly property date date: {
                    const d = new Date(root.today);
                    d.setDate(d.getDate() + (index - root.mid));
                    return d;
                }
                readonly property bool isToday: index === root.mid
                readonly property int dow: date.getDay()          // 0 = Sunday
                readonly property bool isWeekend: dow === 0 || dow === 6

                width: root.columnWidth
                height: root.implicitHeight
                opacity: root.falloff(index)

                Column {
                    id: stack
                    anchors.centerIn: parent
                    spacing: root.rowSpacing

                    // Weekday — today spells out three letters, the rest get one.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: col.isToday
                              ? Qt.formatDate(col.date, "ddd").toUpperCase()
                              : Qt.formatDate(col.date, "ddd").charAt(0).toUpperCase()
                        color: col.isToday ? Theme.text
                             : (col.isWeekend ? Theme.weekend : Theme.textTertiary)
                        font.family: Typography.family
                        font.pixelSize: Typography.micro
                        font.weight: col.isToday ? Typography.semibold : Typography.medium
                        font.letterSpacing: col.isToday ? 0.4 : 0
                    }

                    // Date, in a pill when it is today.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.columnWidth - 3
                        height: root.dateHeight

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.columnWidth
                            height: root.dateHeight
                            radius: 7
                            color: Theme.surfaceHigh
                            antialiasing: true
                            visible: col.isToday
                        }

                        Text {
                            anchors.centerIn: parent
                            text: col.date.getDate()
                            color: col.isToday ? Theme.text
                                 : (col.isWeekend ? Theme.weekend : Theme.textSecondary)
                            font.family: Typography.family
                            font.pixelSize: col.isToday ? Typography.label + 1 : Typography.label
                            font.weight: col.isToday ? Typography.semibold : Typography.regular
                            font.features: Typography.tabular
                        }
                    }
                }
            }
        }
    }
}
