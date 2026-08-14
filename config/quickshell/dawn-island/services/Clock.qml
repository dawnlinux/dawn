pragma Singleton

import QtQuick
import Quickshell

/*
 * The one clock in the shell.
 *
 * Everything that needs the time binds to this rather than instantiating its
 * own SystemClock, so there is exactly one wakeup per minute for the whole
 * island instead of one per widget. Precision is Minutes deliberately —
 * nothing on screen shows seconds, and asking for Seconds would wake the
 * process 60x more often for no visible difference.
 */
Singleton {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: true
    }

    readonly property date now: clock.date

    readonly property string time24: Qt.formatDateTime(now, "HH:mm")
    readonly property string time12: Qt.formatDateTime(now, "h:mm")
    readonly property string meridiem: Qt.formatDateTime(now, "AP")
    readonly property string weekday: Qt.formatDateTime(now, "dddd")
    readonly property string dayMonth: Qt.formatDateTime(now, "d MMMM")
    readonly property string shortDate: Qt.formatDateTime(now, "ddd d MMM")
}
