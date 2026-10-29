import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Vertical workspace indicator on the left edge. Holding SUPER slides it in and
// keeps it there until SUPER is released (see SuperKey.qml).
// The active workspace has a ring around its dot; on a switch the ring stretches
// from the old dot to the new one, then shrinks back to a circle there.
// Below the numbers, the `magic` special workspace (SUPER+S) has its own slot:
// dim when empty, bright when it holds windows, ringed while it's open.
// Switching workspaces or toggling magic without SUPER shows it briefly.
// Clicks pass through it.
Scope {
    id: root

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 1
    // Always show 1-5, more if a higher workspace exists or is active (max 10).
    readonly property int count: Math.min(10, Math.max(5, active,
        ...Hyprland.workspaces.values.map(ws => ws.id)))

    readonly property bool held: SuperKey.held
    property bool shown: false
    property real progress: shown ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // `magic` special workspace state
    readonly property bool magicOpen: Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name === "special:magic"
    readonly property bool magicUsed: Hyprland.toplevels.values.some(t => t.workspace?.name === "special:magic")

    function flash() {
        shown = true;
        if (!held) hideTimer.restart();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                Hyprland.refreshMonitors();
                Hyprland.refreshToplevels();
                root.flash();
            } else if (event.name === "movewindowv2" || event.name === "closewindow") {
                Hyprland.refreshToplevels();
                // movewindowv2 data: "address,workspaceId,workspaceName"
                if (event.data.endsWith(",special:magic")) root.flash();
            }
        }
    }

    function occupied(id) {
        return Hyprland.workspaces.values.some(ws => ws.id === id && ws.lastIpcObject?.windows > 0);
    }

    onActiveChanged: {
        Hyprland.refreshWorkspaces();   // keep window counts current for the dots
        // If the indicator is still sliding in, wait for it so the ring's move is visible.
        if (progress >= 1) ring.moveTo(active);
        else moveDelay.restart();
        flash();
    }

    Timer {
        id: moveDelay
        interval: 200
        onTriggered: ring.moveTo(root.active)
    }

    onHeldChanged: {
        if (held) {
            Hyprland.refreshWorkspaces();
            shown = true;
            hideTimer.stop();
        } else {
            shown = false;
        }
    }

    Timer {
        id: hideTimer
        interval: 1100
        onTriggered: root.shown = false
    }

    PanelWindow {
        visible: root.progress > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        anchors.left: true   // vertically centered on the left edge
        margins.left: 14
        implicitWidth: pill.width + 16
        implicitHeight: pill.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-workspaces"
        mask: Region {}   // click-through

        Rectangle {
            id: pill

            readonly property int dot: 8
            readonly property int step: 22          // distance between dot centers
            readonly property int pad: 15           // from pill edge to first/last dot center

            function centerOf(id) {
                return pad + (id - 1) * step;
            }

            // The magic slot sits one step below the last workspace, past a divider.
            readonly property real magicCenter: centerOf(root.count) + step + 6

            anchors.left: parent.left
            width: 30
            height: magicCenter + pad
            radius: width / 2
            color: Qt.alpha(Colors.surface, Theme.opacity)
            border.width: 1
            border.color: Colors.outlineVariant

            opacity: root.progress
            transform: Translate {
                x: (1 - root.progress) * -24
            }

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Highlight ring. `head` and `tail` are the centers of its two ends:
            // equal at rest (a circle), apart while moving (a capsule).
            Rectangle {
                id: ring

                readonly property real size: pill.dot + 12
                // Plain values, not bindings: only moveTo() changes them.
                property real head: 0
                property real tail: 0
                Component.onCompleted: head = tail = pill.centerOf(root.active)

                function moveTo(id) {
                    worm.stop();
                    headAnim.to = pill.centerOf(id);
                    tailAnim.to = pill.centerOf(id);
                    worm.start();
                }

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.min(head, tail) - size / 2
                width: size
                height: Math.abs(head - tail) + size
                radius: size / 2
                color: Qt.alpha(Colors.primary, 0.18)
                border.width: 2
                border.color: Colors.primary

                // Eat toward the target, then pull the tail in to a circle.
                SequentialAnimation {
                    id: worm
                    NumberAnimation {
                        id: headAnim
                        target: ring
                        property: "head"
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: tailAnim
                        target: ring
                        property: "tail"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Workspace dots, 1 at the top
            Repeater {
                model: root.count

                Rectangle {
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool current: wsId === root.active

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pill.centerOf(wsId) - height / 2
                    width: pill.dot
                    height: pill.dot
                    radius: pill.dot / 2
                    color: current ? Colors.primary : root.occupied(wsId) ? Colors.surfaceText : Colors.outline
                    opacity: current || root.occupied(wsId) ? 1 : 0.45

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }
            }

            // Divider between workspaces and magic
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (pill.centerOf(root.count) + pill.magicCenter) / 2
                width: 12
                height: 1
                color: Colors.outlineVariant
            }

            // Magic: its own ring while open, then the icon.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: pill.magicCenter - height / 2
                width: pill.dot + 12
                height: width
                radius: width / 2
                color: Qt.alpha(Colors.tertiary, 0.18)
                border.width: 2
                border.color: Colors.tertiary
                opacity: root.magicOpen ? 1 : 0
                scale: root.magicOpen ? 1 : 0.6

                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: pill.magicCenter - height / 2
                text: "\uf0d0"   // magic wand
                font.pixelSize: 11
                color: root.magicOpen ? Colors.tertiary : root.magicUsed ? Colors.surfaceText : Colors.outline
                opacity: root.magicOpen || root.magicUsed ? 1 : 0.45

                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
