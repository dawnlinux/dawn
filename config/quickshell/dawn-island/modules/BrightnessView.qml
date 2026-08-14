import QtQuick
import "root:/"
import "root:/theme"
import "root:/services"

/// Screen backlight.
LevelPill {
    icon: "sun"
    level: Brightness.level
    tint: Theme.text
    onScrubbed: function (f) { Brightness.setPercent(f * 100); }
}
