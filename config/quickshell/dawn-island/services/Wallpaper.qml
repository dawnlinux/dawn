pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

/*
 * The wallpaper carousel's state.
 *
 * Reading the directory is FolderListModel's job rather than a `find` in a
 * Process: it is already reactive, so dropping a new image into the folder
 * makes it appear in the carousel without the shell being told, and it costs
 * nothing while the panel is shut.
 *
 * Nothing here loads an image. The model hands out paths; the view decides how
 * big a thumbnail it wants and lets Qt's image cache do the rest — which is the
 * only reason a carousel over a folder of 4K photographs is affordable at all.
 *
 * `applied` is tracked separately from `selected` so the carousel can mark
 * which wallpaper is actually on the desktop while you scroll past others.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableWallpaper

    property bool open: false
    property int selected: 0

    /// Absolute path of the wallpaper currently on the desktop, as far as this
    /// shell knows. Seeded from the daemon on first open, then maintained here.
    property string applied: ""

    // ── The folder ────────────────────────────────────────────────────────

    FolderListModel {
        id: folder
        folder: "file://" + Config.wallpaperDir
        nameFilters: Config.wallpaperExtensions.map(e => "*." + e)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        caseSensitive: false
    }

    /// Plain array of absolute paths, rebuilt when the folder changes. A plain
    /// array rather than the model itself because PathView wants a stable
    /// index and the rest of this file wants to do arithmetic on it.
    readonly property var items: {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const p = folder.get(i, "filePath");
            if (p)
                out.push(p);
        }
        return out;
    }

    readonly property int count: items.length
    readonly property string current:
        (selected >= 0 && selected < count) ? items[selected] : ""

    function nameOf(path) {
        if (!path)
            return "";
        const base = path.slice(path.lastIndexOf("/") + 1);
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    readonly property string currentName: nameOf(current)

    onCountChanged: if (selected >= count) selected = Math.max(0, count - 1)

    // ── The panel ─────────────────────────────────────────────────────────

    /// Opens even with nothing to show — the view explains an empty folder,
    /// which beats the shortcut appearing to be broken.
    function show() {
        if (!enabled)
            return;
        // Open on whatever is already up, so the carousel starts where the
        // desktop is rather than snapping to the alphabetically-first image.
        const at = items.indexOf(applied);
        selected = at >= 0 ? at : 0;
        open = true;
        IslandState.request("wallpaper", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        open = false;
        IslandState.clear("wallpaper");
    }

    function toggle() {
        if (open) hide(); else show();
    }

    function move(delta) {
        if (count === 0)
            return;
        // Wraps, so a long folder is a loop rather than a wall at both ends.
        selected = (selected + delta % count + count) % count;
    }

    // ── Applying ──────────────────────────────────────────────────────────

    /// Single-quoted for the shell, with embedded quotes escaped the POSIX way
    /// ('\'') — wallpapers come from the internet and arrive named things like
    /// "don't panic.png".
    function _quote(path) {
        return "'" + path.replace(/'/g, "'\\''") + "'";
    }

    function apply(indexOrUndefined) {
        const i = indexOrUndefined === undefined ? selected : indexOrUndefined;
        if (i < 0 || i >= count)
            return;
        const path = items[i];

        applied = path;
        selected = i;
        hide();

        const cmd = Config.wallpaperCommand.replace("{}", _quote(path));
        Quickshell.execDetached(["sh", "-c", cmd]);

        _publish(path);
    }

    /// Hand the wallpaper to the login screen.
    ///
    /// This used to write the path and stop there, which could never have
    /// worked: the greeter runs as `greeter`, and `greeter` cannot traverse a
    /// 0700 home directory, so a path into ~/Pictures names a file it is not
    /// allowed to open however the file itself is chmodded. The login screen
    /// fell back to the aurora every time and looked like it had simply not
    /// been told.
    ///
    /// So the image is copied next to the pointer, in a directory the greeter
    /// can read, and the pointer names the copy. The alternative — opening
    /// your home directory to every local account — is a far larger change
    /// than a login screen is worth.
    ///
    /// Best-effort and deliberately silent: the directory may not exist or may
    /// not be writable, and failing to tell the greeter about a wallpaper is
    /// not a reason to fail setting it.
    function _publish(path) {
        if (Config.wallpaperPointer === "")
            return;

        Quickshell.execDetached(["sh", "-c",
            '( set -e; '
            + 'ptr=' + _quote(Config.wallpaperPointer) + '; '
            + 'src=' + _quote(path) + '; '
            + 'dir=$(dirname "$ptr"); '
            // Keep the extension: Qt picks the image plugin by suffix first,
            // and a wallpaper named `current` with no suffix is a wallpaper
            // that may quietly fail to decode.
            //
            // `case` rather than `[ ] && ext=…` because this runs under
            // `set -e`, where a trailing test that fails is only exempt by a
            // fine point of the POSIX AND-OR rule. Not worth resting the
            // login screen's wallpaper on.
            + 'case "$src" in *.*) ext=${src##*.};; *) ext=img;; esac; '
            + 'rm -f "$dir"/current.*; '
            + 'cp -f "$src" "$dir/current.$ext"; '
            + 'chmod 0644 "$dir/current.$ext"; '
            // Written last, so the pointer never names a copy that is still
            // being written.
            + 'printf "%s\\n" "$dir/current.$ext" > "$ptr" '
            + ') >/dev/null 2>&1 || true']);
    }

    // ── Seeding `applied` from the daemon ─────────────────────────────────
    //
    // awww already knows what is on screen; asking it once at startup means the
    // carousel opens on the right tile even after a shell restart, and the
    // "current" marker is honest rather than assumed.

    Process {
        id: query
        command: ["sh", "-c", "awww query"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // "…: eDP-1: 1440x900, scale: 2, currently displaying: image: /path/to.png"
                const m = text.match(/image:\s*(\S.*?)\s*$/m);
                if (m && m[1]) {
                    root.applied = m[1];
                    // Republish on every shell start, not only when you pick a
                    // wallpaper. Otherwise the login screen shows whatever was
                    // current the last time you happened to open the carousel,
                    // and a wallpaper set before any of this existed would
                    // never reach it at all.
                    root._publish(m[1]);
                }
            }
        }
    }

    Component.onCompleted: if (enabled) query.running = true
}
