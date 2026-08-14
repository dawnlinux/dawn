import QtQuick
import qs
import qs.theme
import qs.services

/// Volume. Mute is a distinct state rather than "0%" — a muted sink at 60%
/// is not the same thing as a sink turned down, and the pill says so.
LevelPill {
    icon: "speaker"
    level: Audio.volume
    muted: Audio.muted
    tint: Audio.muted ? Theme.textTertiary : Theme.text
    overrideText: Audio.muted ? "Muted" : ""
    trackLive: true
    onScrubbed: function (f) { Audio.setVolume(f); }
}
