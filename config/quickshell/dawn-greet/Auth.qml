pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Greetd

/*
 * Authentication, and the one thing it must never do: lie.
 *
 * greetd's exchange is a conversation, not a function call — you open a session
 * for a user, greetd sends back however many prompts PAM asks for, you answer
 * each one, and only then is there something to launch. Modelling it as
 * "submit(password) → true/false" would be wrong the first time PAM is
 * configured to ask twice.
 *
 * ── Demo mode ──
 *
 * `Greetd.available` is false whenever this config is run inside an ordinary
 * session, which is exactly how the animation gets built and tuned: there is no
 * greetd socket to talk to, so the whole flow is simulated. Demo mode accepts
 * any password except the literal word "wrong", which is there so the failure
 * animation can be looked at on demand.
 *
 * Demo mode is chosen by the *environment*, never by a config flag — a greeter
 * that could be put into a mode where it accepts any password is a greeter with
 * a backdoor. If greetd is there, it is used; if it is not, nothing can be
 * unlocked because there is no session to unlock.
 */
Singleton {
    id: root

    readonly property bool live: Greetd.available
    readonly property bool demo: !live

    /// Who to authenticate as.
    ///
    /// Under greetd this process runs as `greeter`, so `$USER` is the wrong
    /// answer and authenticating as it fails every time with a PAM message
    /// that explains nothing. Resolved in order:
    ///
    ///   1. `$DAWN_GREET_USER`, set in the greetd session command
    ///   2. `loginUser` below, for when you would rather not use the env var
    ///   3. `$USER`, but only when it is a real login rather than the greeter
    ///      account — which is the demo case, inside your own session
    readonly property string user: {
        const forced = Quickshell.env("DAWN_GREET_USER") || "";
        if (forced !== "")
            return forced;
        if (loginUser !== "")
            return loginUser;
        const env = Quickshell.env("USER") || "";
        return (env === "" || env === "greeter" || env === "root") ? "user" : env;
    }

    /// Hardcoded fallback for the greetd case. See `user` above.
    property string loginUser: ""

    /// The session to hand off to once PAM is satisfied. uwsm, matching how
    /// this machine's sessions are actually started — the argv is the Exec
    /// line of /usr/share/wayland-sessions/hyprland-uwsm.desktop verbatim.
    property var sessionCommand: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"]
    property string sessionName: "Hyprland"

    /// "idle" | "checking" | "granted" | "launching" | "denied"
    property string phase: "idle"
    property string message: ""

    readonly property bool busy: phase === "checking"

    signal granted()
    signal denied(string reason)

    property string _pending: ""

    // ── Timing ────────────────────────────────────────────────────────────
    //
    // A login screen that feels slow is almost never slow where you think it
    // is, and there is no way to attach a profiler to the thing standing
    // between you and your session. So it times itself, from the keystroke
    // that submits to the moment greetd takes over, and prints the segments.
    // `journalctl -u greetd -b` has them after a real boot.

    property double _t0: 0

    function _stamp(label) {
        const t = Date.now();
        const since = root._t0 > 0 ? (t - root._t0) : 0;
        console.log("[dawn-greet] +" + since + "ms " + label);
        return t;
    }

    function submit(password) {
        if (busy || phase === "granted" || phase === "launching")
            return;
        _t0 = Date.now();
        _pending = password;
        message = "";
        phase = "checking";
        _stamp("submit → " + (live ? "greetd createSession(" + user + ")" : "demo"));

        if (live)
            Greetd.createSession(user);
        else
            demoDelay.restart();
    }

    function reset() {
        if (phase === "granted" || phase === "launching")
            return;
        phase = "idle";
        message = "";
        _pending = "";
    }

    function _fail(reason) {
        _pending = "";
        phase = "denied";
        message = reason && reason.length > 0 ? reason : "Incorrect password";
        _stamp("denied: " + message);

        // greetd keeps the failed session open — the next createSession would
        // be refused with "session already exists" and every retry from here
        // on would fail for a reason that has nothing to do with the password
        // typed. Tearing it down is what makes a second attempt possible.
        if (live && Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();

        denied(message);
    }

    // ── greetd ────────────────────────────────────────────────────────────

    Connections {
        target: Greetd
        enabled: root.live

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) {
                root._fail(message);
                return;
            }
            // PAM may ask for anything; the only prompt this greeter can answer
            // is the one it already has an answer for. A hidden prompt is a
            // secret, and the secret we hold is the password. An *echoing*
            // prompt is something meant to be read back on screen — a username,
            // an OTP — and answering it with the password would put the
            // password somewhere it must never go, so it is acknowledged empty
            // and the conversation continues rather than hanging on a prompt
            // nobody can see.
            if (responseRequired)
                Greetd.respond(echoResponse ? "" : root._pending);
            else
                root.message = message;
        }

        function onAuthFailure(message) {
            root._fail(message);
        }

        function onReadyToLaunch() {
            root._pending = "";
            root._stamp("PAM satisfied");
            root.phase = "granted";
            root.granted();
        }

        function onLaunched() {
            root._stamp("greetd launched the session");
        }

        function onError(err) {
            root._fail(err);
        }
    }

    /// Hands the machine over. Called as soon as the wipe has covered the
    /// screen — one frame of cover, not the whole animation.
    ///
    /// This used to wait for the full 1160ms handover sequence to finish
    /// before saying a word to greetd, which meant the session did not begin
    /// starting until the animation was over. It is the other way round now:
    /// greetd is told first and the wipe finishes on top of a session that is
    /// already coming up. The animation costs nothing because it is no longer
    /// in series with anything.
    function launch() {
        if (phase === "launching")
            return;
        phase = "launching";

        if (live) {
            _stamp("→ greetd.launch " + sessionCommand.join(" "));
            // `quit: true` — exit as soon as greetd confirms, rather than
            // sitting on the session's own display waiting to be killed.
            Greetd.launch(sessionCommand, [], true);
        } else {
            _stamp("demo: would launch " + sessionCommand.join(" "));
            // Demo mode has no session to hand over to, and the wipe covering
            // the screen has no way to know that. Left alone it stays there
            // forever: a grey rectangle with exclusive keyboard focus and no
            // way out but killing qs from a TTY. Ending the process is the
            // honest equivalent of greetd taking the machine away.
            //
            // Not immediately, though. Under greetd we are killed part-way
            // through the wipe, which is correct there and useless here —
            // looking at the wipe is what demo mode is *for*. So it plays out
            // first. This delay exists only in demo and is not on the path to
            // anyone's desktop.
            demoQuit.restart();
        }
    }

    // ── Demo ──────────────────────────────────────────────────────────────

    /// Long enough for the wipe to finish on screen. See `launch()`.
    Timer {
        id: demoQuit
        interval: 900
        onTriggered: Qt.quit()
    }

    Timer {
        id: demoDelay
        // Long enough to see the busy ring, short enough not to be the thing
        // you are waiting on while tuning the handover.
        interval: 450
        onTriggered: {
            if (root._pending === "wrong") {
                root._fail("Incorrect password");
            } else {
                root._pending = "";
                root._stamp("demo: accepted");
                root.phase = "granted";
                root.granted();
            }
        }
    }
}
