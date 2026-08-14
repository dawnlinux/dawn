import QtQuick
import qs
import qs.theme

/// Standard content transition — opacity, scale, small offsets.
Behavior {
    id: root

    property int duration: Anim.content
    property int easing: Anim.contentEasing

    enabled: Config.animationsEnabled

    NumberAnimation {
        duration: root.duration
        easing.type: root.easing
    }
}
