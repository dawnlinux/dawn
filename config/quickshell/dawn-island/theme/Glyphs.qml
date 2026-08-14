pragma Singleton

import QtQuick
import Quickshell

/*
 * Nerd Font (Material Design Icons) codepoints.
 *
 * Written as String.fromCodePoint rather than literal characters so the source
 * stays ASCII and reviewable — these are all above the BMP, where a literal
 * would need a surrogate pair and would be impossible to proofread.
 *
 * Every codepoint here was verified against
 * /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf.
 */
Singleton {
    id: root

    function cp(code) { return String.fromCodePoint(code); }

    // Audio
    readonly property string volumeHigh: cp(0xF057E)
    readonly property string volumeMedium: cp(0xF0580)
    readonly property string volumeLow: cp(0xF057F)
    readonly property string volumeOff: cp(0xF0581)
    readonly property string volumeMute: cp(0xF075F)

    // Display
    readonly property string brightnessHigh: cp(0xF00E0)
    readonly property string brightnessMid: cp(0xF00DF)
    readonly property string brightnessLow: cp(0xF00DE)

    // Media
    readonly property string play: cp(0xF040A)
    readonly property string pause: cp(0xF03E4)
    readonly property string next: cp(0xF04AD)
    readonly property string previous: cp(0xF04AE)
    readonly property string music: cp(0xF075A)
    readonly property string musicNote: cp(0xF0387)

    // Notifications
    readonly property string bell: cp(0xF009A)
    readonly property string bellOutline: cp(0xF009C)

    // Clipboard
    readonly property string copy: cp(0xF018F)
    readonly property string clipboard: cp(0xF0146)

    // Network
    readonly property string wifi: cp(0xF05A9)
    readonly property string wifiOff: cp(0xF05AA)
    readonly property string ethernet: cp(0xF0200)

    // Power
    readonly property string battery: cp(0xF0079)
    readonly property string batteryCharging: cp(0xF0084)
    readonly property string batteryAlert: cp(0xF0083)

    // Misc
    readonly property string circle: cp(0xF09DE)
    readonly property string circleSmall: cp(0xF09DF)
    readonly property string check: cp(0xF012C)
    readonly property string close: cp(0xF0156)
    readonly property string calendar: cp(0xF00ED)
    readonly property string monitor: cp(0xF0379)
    readonly property string keyboard: cp(0xF030C)
    readonly property string record: cp(0xF044A)
    readonly property string chevronRight: cp(0xF0142)

    /// Speaker glyph appropriate to a 0..1 volume level.
    function volumeFor(level, muted) {
        if (muted || level <= 0.001) return volumeMute;
        if (level < 0.34) return volumeLow;
        if (level < 0.67) return volumeMedium;
        return volumeHigh;
    }

    /// Sun glyph appropriate to a 0..1 brightness level.
    function brightnessFor(level) {
        if (level < 0.34) return brightnessLow;
        if (level < 0.67) return brightnessMid;
        return brightnessHigh;
    }
}
