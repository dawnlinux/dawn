import QtQuick
import "root:/theme"

/// Text preconfigured for the island. Keeps font decisions out of the modules.
/// Set `eyebrow: true` for the small uppercase rows (artist, "COPIED", app
/// name) — it applies caps, tracking and the muted colour in one flag.
Text {
    id: root

    property bool eyebrow: false

    color: eyebrow ? Theme.textTertiary : Theme.text
    font.family: Typography.family
    font.pixelSize: eyebrow ? Typography.micro : Typography.label
    font.weight: eyebrow ? Typography.medium : Typography.regular
    font.letterSpacing: eyebrow ? Typography.trackingWide : 0
    font.capitalization: eyebrow ? Font.AllUppercase : Font.MixedCase

    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
}
