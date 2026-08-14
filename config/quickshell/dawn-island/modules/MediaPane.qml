import QtQuick
import "root:/"
import "root:/theme"
import "root:/components"
import "root:/services"

/*
 * Album art, track text and transport — the left half of the reference layout.
 *
 * Split out of MediaView because the expanded panel needs exactly the same
 * pane beside the clock. The only thing that differs between the two is how
 * much horizontal room the text gets, so that is the one knob.
 *
 * The transport row and the seek bar share a line: the buttons take what they
 * need and the bar absorbs the rest, which keeps the pane's height fixed no
 * matter how wide it is.
 */
Item {
    id: root

    /// Room given to the title/artist column.
    property real textWidth: 176
    property real artSize: Theme.artSize

    /// Set false while the island is not actually showing this, so the title
    /// marquee and the level meter stop.
    property bool active: true

    /// The pane is exactly as tall as the artwork, and the text column fills
    /// the same box: title flush with the top of the art, transport flush with
    /// its bottom. Giving the column any more height than the art is what
    /// makes the two halves look accidentally misaligned.
    readonly property real contentHeight: artSize

    implicitWidth: row.implicitWidth
    implicitHeight: contentHeight

    Row {
        id: row
        anchors.fill: parent
        spacing: Theme.spacing

        // ── Artwork ───────────────────────────────────────────────────────
        Item {
            width: root.artSize
            height: root.contentHeight

            ArtImage {
                id: art
                anchors.verticalCenter: parent.verticalCenter
                width: root.artSize
                height: root.artSize
                radius: Theme.artRadius
                source: Media.artUrl
                fallbackGlyph: Glyphs.musicNote
            }

            // Level meter, tucked into the corner of the artwork. Only drawn
            // over real album art — floating on the fallback tile it reads as
            // clutter rather than as part of the image.
            Rectangle {
                anchors.right: art.right
                anchors.bottom: art.bottom
                anchors.margins: 4
                width: meter.width + 8
                height: meter.height + 6
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.55)
                antialiasing: true
                visible: Config.showAudioWaveform && art.hasArt && Media.isPlaying
                opacity: visible ? 1 : 0
                FadeBehavior on opacity {}

                Waveform {
                    id: meter
                    anchors.centerIn: parent
                    level: Audio.peak
                    active: root.active && Media.isPlaying
                    color: Theme.text
                    barWidth: 2
                    minHeight: 2.5
                    maxHeight: 11
                }
            }
        }

        // ── Text and controls ─────────────────────────────────────────────
        Item {
            width: root.textWidth
            height: root.contentHeight

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Marquee {
                    text: Media.title !== "" ? Media.title : (Media.identity !== "" ? Media.identity : "Nothing playing")
                    active: root.active
                    maxWidth: root.textWidth
                    pixelSize: Typography.title
                    weight: Typography.semibold
                    color: Theme.text
                }

                Label {
                    width: parent.width
                    visible: Media.album !== "" && Media.album !== Media.title
                    text: Media.album
                    color: Theme.textSecondary
                    font.pixelSize: Typography.label
                }

                Label {
                    width: parent.width
                    visible: Media.artist !== ""
                    text: Media.artist
                    eyebrow: true
                }
            }

            // Transport + seek, sharing the bottom line.
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24

                Row {
                    id: transport
                    anchors.left: parent.left
                    anchors.leftMargin: -5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    IconButton {
                        icon: "prev"
                        iconSize: 14
                        hitPadding: 5
                        enabled: Media.canPrev
                        onClicked: Media.previous()
                    }
                    IconButton {
                        icon: Media.isPlaying ? "pause" : "play"
                        iconSize: 14
                        hitPadding: 5
                        enabled: Media.canToggle
                        onClicked: Media.playPause()
                    }
                    IconButton {
                        icon: "next"
                        iconSize: 14
                        hitPadding: 5
                        enabled: Media.canNext
                        onClicked: Media.next()
                    }
                }

                // Seek bar fills whatever the buttons leave behind.
                Item {
                    anchors.left: transport.right
                    anchors.leftMargin: Theme.spacingSm
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    visible: Config.showMediaProgress && Media.hasProgress && width > 40

                    LevelBar {
                        id: seek
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        thickness: 3
                        value: Media.progress
                        fillColor: seekArea.containsMouse ? Theme.text : Theme.textSecondary
                        trackColor: Theme.surfaceHigh
                        // Follow the pointer exactly while scrubbing; the
                        // eased fill would otherwise lag behind the cursor.
                        animated: !seekArea.pressed
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function (ev) { Media.seekFraction(ev.x / width); }
                        onPositionChanged: function (ev) {
                            if (pressed)
                                Media.seekFraction(ev.x / width);
                        }
                    }
                }
            }
        }
    }
}
