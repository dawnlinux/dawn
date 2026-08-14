pragma Singleton

import QtQuick
import Quickshell
import qs

/*
 * The application launcher's state and search.
 *
 * Quickshell already parses the desktop-entry database, so there is no scanning
 * or caching to do here — `DesktopEntries.applications` is live and the index
 * below is rebuilt only when that list actually changes, not per keystroke.
 *
 * Ranking is deliberately not a fuzzy subsequence match. Fuzzy matching feels
 * clever and behaves badly on a small list: typing "fi" should offer Files and
 * Firefox, not every entry that happens to contain an f followed later by an i.
 * So this scores by *where* the match lands — a name that starts with the query
 * beats a word inside the name, which beats a match in the description — and
 * anything with no match anywhere is dropped. The result is that short queries
 * settle immediately instead of reshuffling as you type.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableLauncher

    property bool open: false
    property string query: ""
    property int selected: 0

    /// One entry per application, with its searchable text pre-lowered so the
    /// scorer isn't calling toLowerCase() thousands of times per keystroke.
    readonly property var index: {
        const out = [];
        const apps = DesktopEntries.applications
                   ? DesktopEntries.applications.values : [];
        for (const app of apps) {
            if (!app || app.noDisplay)
                continue;
            const name = app.name || "";
            if (name === "")
                continue;
            out.push({
                entry: app,
                name: name,
                subtitle: app.genericName || app.comment || "",
                lowerName: name.toLowerCase(),
                lowerExtra: ((app.genericName || "") + " "
                           + (app.comment || "") + " "
                           + ((app.keywords || []).join(" "))).toLowerCase()
            });
        }
        // Alphabetical, so an empty query shows a stable, predictable list.
        out.sort((a, b) => a.lowerName < b.lowerName ? -1
                         : (a.lowerName > b.lowerName ? 1 : 0));
        return out;
    }

    function _score(item, q) {
        const n = item.lowerName;

        if (n === q)             return 1000;
        if (n.indexOf(q) === 0)  return 900 - n.length;

        // Start of any word in the name: "code" finds "Visual Studio Code".
        const wordStart = n.indexOf(" " + q);
        if (wordStart !== -1)    return 700 - wordStart;

        if (n.indexOf(q) !== -1) return 500 - n.indexOf(q);

        // Description / keywords only — always below any name match.
        if (item.lowerExtra.indexOf(q) !== -1) return 200;

        return -1;
    }

    readonly property var results: {
        if (!enabled)
            return [];

        const q = query.trim().toLowerCase();
        if (q === "")
            return index;

        const scored = [];
        for (const item of index) {
            const s = root._score(item, q);
            if (s >= 0)
                scored.push({ item: item, score: s });
        }
        scored.sort((a, b) => b.score - a.score
                           || (a.item.lowerName < b.item.lowerName ? -1 : 1));
        return scored.map(s => s.item);
    }

    readonly property int count: results.length

    /// Keep the highlight inside the list as it shrinks under a longer query.
    onResultsChanged: if (selected >= count) selected = Math.max(0, count - 1)

    // ── Control ───────────────────────────────────────────────────────────

    function show() {
        if (!enabled)
            return;
        query = "";
        selected = 0;
        open = true;
        IslandState.request("launcher", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        open = false;
        query = "";
        selected = 0;
        IslandState.clear("launcher");
    }

    function toggle() {
        if (open) hide(); else show();
    }

    function move(delta) {
        if (count === 0)
            return;
        // Wraps, so holding Down cycles rather than sticking at the bottom.
        selected = (selected + delta % count + count) % count;
    }

    function activate(indexOrUndefined) {
        const i = indexOrUndefined === undefined ? selected : indexOrUndefined;
        if (i < 0 || i >= count)
            return;
        const chosen = results[i];
        hide();
        if (chosen && chosen.entry)
            chosen.entry.execute();
    }
}
