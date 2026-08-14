pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.theme
import qs.services

/*
 * The accent colour, taken from the wallpaper.
 *
 * The wallpaper chooses the hue. Dawn chooses everything else.
 *
 * That split is the whole design. Lifting a colour out of an image wholesale
 * gives you whatever that image happened to contain — a muddy olive from a
 * forest photo, a near-black from a dark one, something acid from a poster —
 * and half of those cannot be read on a black island next to #f2f2f2 text.
 * So only the hue survives the trip; saturation and lightness are dawn's,
 * fixed in Config. Every wallpaper lands somewhere in the same family, and the
 * shell stays recognisably itself while still answering to what is behind it.
 *
 * Nothing here decodes an image. ffmpeg scales the wallpaper to 16x16 in its
 * own process and exits, and the shell only ever sees 768 bytes — which is why
 * a folder of 4K photographs costs nothing to sample. `od` turns those bytes
 * into decimal text because StdioCollector reads text, and raw RGB contains
 * NULs.
 *
 * Entirely optional. Without ffmpeg the command produces no output, the hue
 * stays -1, and the accent is Theme.accentBase exactly as before.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.deriveAccentFromWallpaper

    /// Which image to sample. Config.wallpaperPath is an escape hatch for
    /// setups where the carousel is off and no daemon can be asked; normally
    /// this follows whatever the island last applied.
    readonly property string path:
        Config.wallpaperPath !== "" ? Config.wallpaperPath : Wallpaper.applied

    /// Derived hue, 0..1 around the wheel. -1 means "no usable colour" — an
    /// honestly greyscale wallpaper, or nothing sampled yet.
    property real hue: -1

    /// The image `hue` was taken from, so the same wallpaper is not resampled
    /// when it is merely reapplied.
    property string sampled: ""

    /// The accent this service is asking for. A plain binding rather than an
    /// imperative set, so flipping the switch off — or nudging the saturation
    /// in Config while the shell runs — resolves without any extra plumbing.
    readonly property color derived:
        (enabled && hue >= 0)
            ? Qt.hsla(hue, Config.accentSaturation, Config.accentLightness, 1)
            : Theme.accentBase

    onDerivedChanged: Theme.accent = derived
    Component.onCompleted: Theme.accent = derived

    onPathChanged: _schedule()
    onEnabledChanged: {
        if (enabled)
            _schedule();
        else
            hue = -1;          // `derived` falls back on its own
    }

    // ── Sampling ──────────────────────────────────────────────────────────

    /// Setting a wallpaper writes the file, tells awww and republishes the
    /// pointer all at once; sampling in the middle of that reads a half-copied
    /// image. The wait also collapses the burst of changes you get holding an
    /// arrow key down in the carousel into one sample of wherever you stopped.
    Timer {
        id: settle
        interval: Config.accentSampleDelay
        onTriggered: root._sample()
    }

    function _schedule() {
        if (enabled && path !== "" && path !== sampled)
            settle.restart();
    }

    /// Single-quoted for the shell, POSIX-escaped — same reasoning as
    /// Wallpaper._quote: these filenames come from the internet.
    function _quote(p) {
        return "'" + p.replace(/'/g, "'\\''") + "'";
    }

    function _sample() {
        if (!enabled || path === "")
            return;
        const n = Config.accentSampleSize;
        // `area` is a box filter: every pixel of the wallpaper contributes to
        // the average. The default bilinear filter point-samples when
        // downscaling this hard, so a 4K image would be judged on a few
        // thousand of its pixels rather than all of them.
        //
        // -nostdin keeps ffmpeg from swallowing the shell's stdin, and
        // -frames:v 1 stops an animated GIF from streaming forever.
        const cmd =
            "ffmpeg -v error -nostdin -i " + _quote(path)
            + " -vf scale=" + n + ":" + n + ":flags=area -frames:v 1"
            + " -f rawvideo -pix_fmt rgb24 - | od -An -v -tu1";

        sampler.running = false;
        sampler.command = ["sh", "-c", cmd];
        sampler.running = true;
    }

    Process {
        id: sampler
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // No ffmpeg, an unreadable file, or a format it cannot open:
                // all arrive here as nothing at all. Keeping the previous hue
                // rather than resetting means a transient failure does not
                // flash the shell back to white and out again.
                const t = text.trim();
                if (t === "")
                    return;
                const h = root._hueOf(t.split(/\s+/));
                root.sampled = root.path;
                root.hue = h;
            }
        }
    }

    // ── Choosing a hue ────────────────────────────────────────────────────

    /*
     * Hues are voted for in buckets rather than averaged.
     *
     * A mean over the whole image is always wrong: hue is an angle, so red at
     * 350° and red at 10° average to cyan, and even without the wraparound the
     * mean of a blue sky and an orange sunset is the grey between them. So
     * every pixel votes for a bucket, the heaviest bucket wins, and only
     * within that bucket is a mean taken — as a circular mean, on the unit
     * circle, which is the one form that survives the 360°/0° seam.
     *
     * Votes are weighted by chroma squared. Chroma alone lets a large field of
     * nearly-grey outvote a small vivid subject; cubed and beyond, the result
     * becomes unstable — measured across this wallpaper folder, squared agrees
     * with linear on every image, while cubed flips one from blue to amber and
     * a fourth power flips another from teal to red. Squared is the strongest
     * weighting that still picks the same colour a person would.
     */
    function _hueOf(bytes) {
        const BUCKETS = 24;                 // 15° each
        const weight = new Array(BUCKETS).fill(0);
        const sin = new Array(BUCKETS).fill(0);
        const cos = new Array(BUCKETS).fill(0);
        const TAU = Math.PI * 2;

        for (let i = 0; i + 2 < bytes.length; i += 3) {
            const r = bytes[i] / 255;
            const g = bytes[i + 1] / 255;
            const b = bytes[i + 2] / 255;
            const max = Math.max(r, g, b);
            const min = Math.min(r, g, b);
            const chroma = max - min;

            // Near-black and blown-out pixels do carry a hue, but not one
            // worth trusting: a couple of bits of sensor noise swings it right
            // round the wheel. Anything this close to grey has no hue to read.
            if (max < Config.accentMinValue || max > Config.accentMaxValue)
                continue;
            if (chroma < Config.accentMinChroma)
                continue;

            let h;
            if (max === r)
                h = ((g - b) / chroma) / 6;
            else if (max === g)
                h = (2 + (b - r) / chroma) / 6;
            else
                h = (4 + (r - g) / chroma) / 6;
            if (h < 0)
                h += 1;

            const w = chroma * chroma;
            const k = Math.min(BUCKETS - 1, Math.floor(h * BUCKETS));
            weight[k] += w;
            sin[k] += w * Math.sin(h * TAU);
            cos[k] += w * Math.cos(h * TAU);
        }

        // Score each bucket together with its two neighbours. A hue sitting on
        // a boundary would otherwise split its vote between two buckets and
        // lose to a broader, duller one that happens to fall in the middle of
        // its own.
        let best = -1;
        let bestWeight = 0;
        let total = 0;
        for (let k = 0; k < BUCKETS; k++) {
            total += weight[k];
            const w = weight[(k + BUCKETS - 1) % BUCKETS]
                    + weight[k]
                    + weight[(k + 1) % BUCKETS];
            if (w > bestWeight) {
                bestWeight = w;
                best = k;
            }
        }

        // A genuinely monochrome wallpaper scores exactly zero here, while the
        // least colourful real one in this folder scores about 0.002 — so the
        // threshold separates "no colour" from "little colour" with room to
        // spare, and a black-and-white photograph keeps the base accent rather
        // than being assigned an invented one.
        const pixels = Math.max(1, Math.floor(bytes.length / 3));
        if (best < 0 || total / pixels < Config.accentMinStrength)
            return -1;

        let s = 0;
        let c = 0;
        for (let d = -1; d <= 1; d++) {
            const k = (best + d + BUCKETS) % BUCKETS;
            s += sin[k];
            c += cos[k];
        }
        let h = Math.atan2(s, c) / TAU;
        return h < 0 ? h + 1 : h;
    }
}
