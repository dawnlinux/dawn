import QtQuick
import Quickshell
import Quickshell.Wayland

/*
 * dawn-greet — the login screen.
 *
 * Laid out after macOS: the wallpaper runs edge to edge with nothing on top of
 * it but type. Date, then a very large thin clock, both centred in the upper
 * third; the user, their name and the password field centred in the lower. No
 * card, no panel — legibility comes from a scrim over the photograph, which is
 * why that scrim is the most load-bearing eight lines in the file.
 *
 * The motion is still dawn's. The password field arrives as the island's 124×28
 * notch and unfolds on the island's spring, and being let in ends with the same
 * wipe the island uses to hand over.
 *
 * Runs as a greetd greeter; see README.md, including the way back. To work on
 * it inside an ordinary session:
 *
 *     qs -p ~/.config/quickshell/dawn-greet/shell.qml
 *
 * `Greetd.available` is false there, so Auth falls into demo mode: any password
 * except the literal word "wrong". Escape quits.
 */
ShellRoot {
    id: shell

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "dawn-greet"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // A login screen covers the screen, full stop — without this it is
            // shrunk by whatever bar is running, which while developing is the
            // island's own notch pushing the greeter down the display.
            exclusiveZone: -1

            color: Theme.background

            // Compared by name, not identity: `modelData` and the entry in
            // `Quickshell.screens` are not guaranteed to be the same wrapper
            // object, so `===` silently reports false on every screen.
            readonly property bool primary:
                Quickshell.screens.length <= 1
                || modelData.name === Quickshell.screens[0].name

            // ── Wallpaper ─────────────────────────────────────────────────

            Image {
                id: paper
                anchors.fill: parent
                source: Wall.source
                visible: Wall.available && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Decoded at panel size, not the file's. These are 4K photos
                // and the greeter has one job before you can fix anything.
                sourceSize.width: win.width
                sourceSize.height: win.height

                // Settles in and lifts very slightly as the greeter opens, so
                // the wallpaper feels placed rather than pasted.
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

                scale: entranceDone ? 1.0 : 1.045
                Behavior on scale { NumberAnimation { duration: 2600; easing.type: Easing.OutCubic } }
            }

            property bool entranceDone: false

            /// Only when there is no wallpaper to be had — a greeter that comes
            /// up black because a path moved is a greeter you cannot log in to.
            Aurora {
                anchors.fill: parent
                visible: !paper.visible
                tintA: Theme.auroraA
                tintB: Theme.auroraB
                tintC: Theme.auroraC
            }

            // ── Scrim ─────────────────────────────────────────────────────
            //
            // Without a card behind the type, this is the only thing making it
            // readable over an arbitrary photograph. Darker at top and bottom
            // where the text sits, nearly clear through the middle so the
            // wallpaper is still the picture you chose.

            Rectangle {
                anchors.fill: parent
                visible: paper.visible
                gradient: Gradient {
                    GradientStop { position: 0.00; color: "#8c000000" }
                    GradientStop { position: 0.32; color: "#40000000" }
                    GradientStop { position: 0.58; color: "#4d000000" }
                    GradientStop { position: 1.00; color: "#a6000000" }
                }
            }

            // ── Clock ─────────────────────────────────────────────────────

            Column {
                id: clockBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.11
                spacing: -14
                visible: win.primary

                opacity: win.entranceDone ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 760; easing.type: Easing.OutCubic } }

                y: win.entranceDone ? 0 : 18
                Behavior on y { NumberAnimation { duration: 760; easing.type: Easing.OutCubic } }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.now, "dddd, d MMMM")
                    color: "#ffffff"
                    font.family: Theme.family
                    font.pixelSize: Theme.date
                    font.weight: Theme.semibold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.now, "H:mm")
                    color: "#ffffff"
                    font.family: Theme.family
                    font.pixelSize: Theme.clock
                    font.weight: Theme.light
                    font.letterSpacing: -4
                    font.features: Theme.tabular
                }
            }

            QtObject {
                id: clock
                property var now: new Date()
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.now = new Date()
            }

            // ── User ──────────────────────────────────────────────────────

            UserPanel {
                id: user
                visible: win.primary
                userName: Auth.user
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.70
                onSubmitted: function (password) { Auth.submit(password); }
            }

            // ── Power, top right ──────────────────────────────────────────

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 28
                anchors.topMargin: 22
                spacing: 18
                visible: win.primary
                opacity: win.entranceDone ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 760 } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Auth.demo ? "demo — any password except “wrong”" : Auth.sessionName
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Theme.family
                    font.pixelSize: Theme.caption
                }

                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, powerHover.hovered ? 0.22 : 0.0)
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.family: Theme.family
                        font.pixelSize: 15
                    }

                    HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (!Auth.demo)
                                Quickshell.execDetached(["sh", "-c", "systemctl poweroff"]);
                        }
                    }
                }
            }

            // ── Handover ──────────────────────────────────────────────────
            //
            // The island's wipe: a pill at the notch's size that overruns the
            // screen. It ends on the shell's own surface colour, which is what
            // the session comes up on, so the seam is invisible.
            //
            // The ordering here is the whole reason login feels fast. This
            // sequence used to dwell 460ms at pill size, spend 700ms growing,
            // and only *then* tell greetd to start the session — 1160ms in
            // which nothing was happening except an animation. Now the wipe
            // covers on the island's own spring, and the moment the screen is
            // covered greetd is told to go. The rest of the animation, and all
            // of the session's startup, happen underneath a screen that is
            // already the colour the session comes up on. Nothing is in series
            // with anything any more.

            Rectangle {
                id: wipe
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2
                width: wiping ? parent.width * 1.7 : Theme.pillWidth
                height: wiping ? parent.height * 1.7 : Theme.pillHeight
                radius: wiping ? Theme.cardRadius : height / 2
                color: Theme.surface
                opacity: win.wipeArmed ? 1 : 0
                visible: opacity > 0.01
                antialiasing: true
                z: 100

                property bool wiping: false

                // The island's spring rather than the old heavy one. It
                // overshoots, which on something whose job is to be larger
                // than the screen is invisible, and it covers in about a
                // third of the time.
                Behavior on width {
                    SpringAnimation {
                        spring: Theme.springStiffness; damping: Theme.springDamping
                        mass: Theme.springMass; epsilon: 0.4
                    }
                }
                Behavior on height {
                    SpringAnimation {
                        spring: Theme.springStiffness; damping: Theme.springDamping
                        mass: Theme.springMass; epsilon: 0.4
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 110 } }

                // ── When the handover does not happen ──────────────────
                //
                // Everything above assumes greetd takes the machine away. If
                // it does not — a session command that is not there, a uwsm
                // that exits, greetd refusing the launch — the wipe is still
                // sitting on the screen with exclusive keyboard focus, and
                // what you get is a mute grey rectangle and no way out. That
                // is not a failure mode a login screen may have.

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: win.handoverStalled
                    opacity: win.handoverStalled ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "The session did not start."
                        color: Theme.text
                        font.family: Theme.family
                        font.pixelSize: Theme.body
                        font.weight: Theme.medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: Auth.sessionCommand.join(" ")
                        color: Theme.textTertiary
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.caption
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: Auth.demo
                              ? "Demo mode — there is no session to start. Esc quits."
                              : "Switch to a TTY with Ctrl+Alt+F2 and check journalctl -u greetd -b."
                        color: Theme.textQuaternary
                        font.family: Theme.family
                        font.pixelSize: Theme.caption
                    }
                }
            }

            property bool wipeArmed: false
            property bool handoverStalled: false

            /// If we are still here this long after handing over, we were not
            /// taken away and something is wrong. Generous: a cold uwsm start
            /// on a slow disk is allowed to be slow.
            Timer {
                id: stallWatch
                interval: 8000
                onTriggered: {
                    win.handoverStalled = true;
                    console.warn("[dawn-greet] still alive 8s after launch — handover failed");
                }
            }

            SequentialAnimation {
                id: handover
                // Cover, on the island's spring…
                PropertyAction { target: win; property: "wipeArmed"; value: true }
                PropertyAction { target: wipe; property: "wiping"; value: true }
                // …and the moment the screen is actually covered, go. The
                // pause is one beat of cover, not a beat of waiting.
                PauseAnimation { duration: 240 }
                ScriptAction {
                    script: {
                        Auth.launch();
                        if (win.primary)
                            stallWatch.restart();
                    }
                }
            }

            // ── Entrance ──────────────────────────────────────────────────

            SequentialAnimation {
                id: entrance
                running: win.primary
                PauseAnimation { duration: 220 }
                PropertyAction { target: win; property: "entranceDone"; value: true }
                PauseAnimation { duration: 380 }
                PropertyAction { target: user; property: "phase"; value: "in" }
                PauseAnimation { duration: 420 }
                ScriptAction { script: user.focusField() }
            }

            Connections {
                target: Auth
                function onGranted() { handover.restart(); }
                function onDenied(reason) { user.refuse(); }
            }

            // Escape quits, but only in demo mode: a greeter you can close is a
            // login screen you can walk past.
            //
            // This was a `Keys.onEscapePressed` on an Item filling the window,
            // which never fired once. Key events travel up the *focus chain* —
            // from the focused item through its ancestors — and that Item was
            // a sibling of UserPanel, not an ancestor of the password field
            // that `focusField()` had just focused. So Escape went to the
            // TextInput, which ignored it, and that was the end of it. A
            // Shortcut with application context is not routed through the
            // focus chain at all, which is the property actually wanted here.
            //
            // One per screen would be an ambiguous shortcut and none of them
            // would fire, hence the `win.primary` guard.
            Shortcut {
                sequences: ["Escape"]
                context: Qt.ApplicationShortcut
                enabled: Auth.demo && win.primary
                onActivated: Qt.quit()
            }
        }
    }
}
