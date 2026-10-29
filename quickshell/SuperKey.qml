pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Whether SUPER is held down. Hyprland reports press and release through the
// `quickshell:super` global shortcut (bound to Super_L in hypr/hyprland.lua).
// Used by WorkspaceOsd and StatusOsd.
Singleton {
    id: root

    property bool held: false

    GlobalShortcut {
        name: "super"
        description: "Show the workspace indicator and status panel while held"
        onPressed: {
            root.held = true;
            safety.restart();
        }
        onReleased: {
            root.held = false;
            safety.stop();
        }
    }

    // In case a release event is ever lost, don't stay "held" forever.
    Timer {
        id: safety
        interval: 15000
        onTriggered: root.held = false
    }
}
