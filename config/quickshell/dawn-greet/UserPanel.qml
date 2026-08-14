import QtQuick
import Quickshell

/*
 * Avatar, name, password — floating on the wallpaper, no card.
 *
 * macOS puts nothing behind this: the wallpaper runs edge to edge and the
 * controls sit directly on it. That is the whole look, and it is why the scrim
 * in shell.qml matters more than any panel would — legibility has to come from
 * the background being darkened, not from a box.
 *
 * The island's DNA survives in the one place it still fits: the password field
 * is the notch. It arrives as the 124×28 pill and unfolds into the field, on
 * the same spring the island morphs with. Everything else here is Apple's
 * layout; the motion is dawn's.
 */
Item {
    id: root

    required property string userName

    /// "hidden" → "in" (avatar settled, field unfolding) → "out"
    property string phase: "hidden"

    readonly property bool shown: phase === "in"

    signal submitted(string password)

    implicitWidth: Theme.fieldWidth
    implicitHeight: Theme.avatarSize + 96

    // ── Avatar ────────────────────────────────────────────────────────────

    Item {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Theme.avatarSize
        height: Theme.avatarSize

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.82
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on scale {
            SpringAnimation { spring: 8; damping: 0.5; mass: 0.8; epsilon: 0.002 }
        }

        // Busy ring. The only moving thing while PAM is thinking, so waiting
        // has an obvious subject.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Auth.busy ? Qt.rgba(1, 1, 1, 0.85)
                        : (root.denied ? Theme.danger : Qt.rgba(1, 1, 1, 0.0))
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            Rectangle {
                visible: Auth.busy
                width: 13; height: 13; radius: 6.5
                x: parent.width / 2 - 6.5
                y: -6.5
                // Punched in the average of the wallpaper rather than a flat
                // colour would be nicer; at this size nobody can tell.
                color: "#00000000"
            }

            RotationAnimator on rotation {
                running: Auth.busy
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 1100
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.28)
            antialiasing: true

            Text {
                anchors.centerIn: parent
                text: root.userName.charAt(0).toUpperCase()
                color: "#ffffff"
                font.family: Theme.family
                font.pixelSize: 30
                font.weight: Theme.medium
            }
        }
    }

    readonly property bool denied: Auth.phase === "denied"

    // ── Name ──────────────────────────────────────────────────────────────

    Text {
        id: nameLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: avatar.bottom
        anchors.topMargin: 12
        text: root.userName
        color: "#ffffff"
        font.family: Theme.family
        font.pixelSize: Theme.name
        font.weight: Theme.semibold

        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // ── Password ──────────────────────────────────────────────────────────
    //
    // The notch, unfolding. Width springs from the island's 124 to the field's
    // width; height from 28 to 34. Small numbers, but it is the same gesture
    // the shell makes all day and the eye recognises it.

    Item {
        id: fieldWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: nameLabel.bottom
        anchors.topMargin: 16
        width: Theme.fieldWidth
        height: Theme.fieldHeight

        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: root.shown ? Theme.fieldWidth : Theme.pillWidth
            height: root.shown ? Theme.fieldHeight : Theme.pillHeight
            radius: height / 2
            antialiasing: true

            color: Qt.rgba(1, 1, 1, root.denied ? 0.10 : 0.15)
            border.width: 1
            border.color: root.denied ? Theme.danger
                        : (input.activeFocus ? Qt.rgba(1, 1, 1, 0.45)
                                             : Qt.rgba(1, 1, 1, 0.22))

            Behavior on color { ColorAnimation { duration: Theme.quick } }
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
            Behavior on width {
                SpringAnimation {
                    spring: Theme.springStiffness; damping: Theme.springDamping
                    mass: Theme.springMass; epsilon: Theme.springEpsilon
                }
            }
            Behavior on height {
                SpringAnimation {
                    spring: Theme.springStiffness; damping: Theme.springDamping
                    mass: Theme.springMass; epsilon: Theme.springEpsilon
                }
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 30
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true

                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                enabled: root.shown && !Auth.busy && Auth.phase !== "granted"

                color: "#ffffff"
                font.family: Theme.family
                font.pixelSize: Theme.body
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: "#ffffff"

                onTextChanged: {
                    if (!root._clearing && Auth.phase === "denied")
                        Auth.reset();
                }
                onAccepted: root.submit()

                Text {
                    anchors.centerIn: parent
                    visible: input.text === "" && !Auth.busy
                    text: root.denied ? "Try again" : "Enter Password"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font: input.font
                }
            }

            // The go arrow, as macOS has. Only once there is something to send.
            Item {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                opacity: input.text.length > 0 && !Auth.busy ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.content } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, arrowHover.hovered ? 0.34 : 0.22)
                    antialiasing: true
                    Behavior on color { ColorAnimation { duration: Theme.quick } }

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "#ffffff"
                        font.family: Theme.family
                        font.pixelSize: 13
                    }
                }

                HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.submit() }
            }
        }
    }

    // ── Refusal ───────────────────────────────────────────────────────────

    property bool _clearing: false
    property real shakeOffset: 0
    x: baseX + shakeOffset
    property real baseX: 0

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:   9; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:  -7; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:   4; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:   0; duration: 95; easing.type: Easing.OutBack }
    }

    function submit() {
        if (input.text.length === 0)
            return;
        root.submitted(input.text);
    }

    function clearField() {
        _clearing = true;
        input.text = "";
        _clearing = false;
    }

    function refuse() {
        shake.restart();
        clearField();
        input.forceActiveFocus();
    }

    function focusField() {
        input.forceActiveFocus();
    }
}
