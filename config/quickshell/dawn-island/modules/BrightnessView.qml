import QtQuick
import qs
import qs.theme
import qs.services

/// Screen backlight.
LevelPill {
    icon: "sun"
    level: Brightness.level
    tint: Theme.text
    onScrubbed: function (f) { Brightness.setPercent(f * 100); }
}
