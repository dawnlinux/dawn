import QtQuick
import "root:/"
import "root:/theme"

/*
 * Cross-fades between island contents.
 *
 * Two slots rather than one Loader, so the outgoing view is still on screen
 * while the incoming one arrives. A hard swap reads as a glitch; an overlap of
 * ~200ms reads as the island *becoming* the new thing.
 *
 * The incoming slot also reports its implicit size as `contentWidth/Height`,
 * which is what the island animates its shape towards. Content drives shape,
 * never the other way round.
 */
Item {
    id: root

    /// The view to show. Assign a Component; null clears.
    property Component content: null

    /// Live size request from whichever slot is in front.
    readonly property real contentWidth: front ? front.implicitWidth : 0
    readonly property real contentHeight: front ? front.implicitHeight : 0

    property Loader front: slotA
    property Loader back: slotB

    /// Suppress the transition for the very first assignment, so the shell
    /// does not visibly animate on startup.
    property bool primed: false

    onContentChanged: root.swap()

    function swap() {
        const incoming = back;
        const outgoing = front;

        enterAnim.stop();
        exitAnim.stop();

        incoming.sourceComponent = content;

        if (!primed || !Config.animationsEnabled) {
            primed = true;
            incoming.opacity = content ? 1 : 0;
            incoming.yOffset = 0;
            incoming.scale = 1;
            outgoing.opacity = 0;
            outgoing.sourceComponent = null;
            front = incoming;
            back = outgoing;
            return;
        }

        // Outgoing: sink slightly and fade.
        exitAnim.target = outgoing;
        exitAnim.start();

        // Incoming: start low, small and invisible, then settle.
        incoming.opacity = 0;
        incoming.yOffset = Anim.enterOffset;
        incoming.scale = Anim.enterScale;
        if (content) {
            enterAnim.target = incoming;
            enterAnim.start();
        }

        front = incoming;
        back = outgoing;
        reaper.restart();
    }

    // Frees the outgoing view once it is fully hidden.
    Timer {
        id: reaper
        interval: Anim.content + 80
        onTriggered: if (root.back) root.back.sourceComponent = null
    }

    component Slot: Loader {
        property real yOffset: 0
        asynchronous: false
        visible: opacity > 0.01
        width: implicitWidth
        height: implicitHeight
        x: (root.width - width) / 2
        y: (root.height - height) / 2 + yOffset
        opacity: 0
        transformOrigin: Item.Center
    }

    Slot { id: slotA }
    Slot { id: slotB }

    ParallelAnimation {
        id: enterAnim
        property Item target: null
        NumberAnimation {
            target: enterAnim.target; property: "opacity"; to: 1
            duration: Anim.content; easing.type: Anim.contentEasing
        }
        NumberAnimation {
            target: enterAnim.target; property: "yOffset"; to: 0
            duration: Anim.content; easing.type: Anim.contentEasing
        }
        NumberAnimation {
            target: enterAnim.target; property: "scale"; to: 1
            duration: Anim.content; easing.type: Anim.contentEasing
        }
    }

    ParallelAnimation {
        id: exitAnim
        property Item target: null
        NumberAnimation {
            target: exitAnim.target; property: "opacity"; to: 0
            duration: Anim.fade; easing.type: Anim.contentEasing
        }
        NumberAnimation {
            target: exitAnim.target; property: "yOffset"; to: Anim.exitOffset
            duration: Anim.fade; easing.type: Anim.contentEasing
        }
        NumberAnimation {
            target: exitAnim.target; property: "scale"; to: Anim.enterScale
            duration: Anim.fade; easing.type: Anim.contentEasing
        }
    }
}
