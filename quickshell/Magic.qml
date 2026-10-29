pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Pops an app's window into the `magic` special workspace (the scratchpad on
// SUPER+S in hypr/hyprland.lua) and shows it; if it's already there, toggles it.
// Used by the tray in StatusOsd.qml. Also: `qs ipc call magic toggle <name>`.
Singleton {
    id: root

    readonly property string workspace: "special:magic"

    // Pending request: names to match and how many lookups are left.
    property var names: []
    property var activate: null
    property int attempts: 0

    // names: strings to match against window classes/titles (e.g. tray id, title).
    // activate: called when no window exists yet, to make the app open one.
    function open(matchNames, activateFn) {
        names = matchNames.filter(n => n).map(n => n.toLowerCase());
        activate = activateFn ?? null;
        attempts = 10;
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        lookup.restart();
    }

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }

    function magicShown() {
        return Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name === workspace;
    }

    function findWindow() {
        return Hyprland.toplevels.values.find(w => {
            const cls = (w.lastIpcObject?.class ?? "").toLowerCase();
            const title = (w.title ?? "").toLowerCase();
            return cls && names.some(n => cls.includes(n) || n.includes(cls) || title === n);
        });
    }

    function bring(win) {
        if (win.lastIpcObject?.workspace?.name === workspace) {
            dispatch(`hl.dsp.workspace.toggle_special("magic")`);
            return;
        }
        dispatch(`hl.dsp.window.move({ workspace = "${workspace}", window = "address:0x${win.address}", follow = false })`);
        if (!magicShown())
            dispatch(`hl.dsp.workspace.toggle_special("magic")`);
    }

    // Window info arrives asynchronously after a refresh, so look up on a timer.
    // If the app has no window yet, activate it once and keep looking (~2s).
    Timer {
        id: lookup
        interval: 200
        onTriggered: {
            const win = root.findWindow();
            if (win) {
                root.bring(win);
                return;
            }
            if (root.attempts === 10 && root.activate)
                root.activate();
            if (--root.attempts > 0) {
                Hyprland.refreshToplevels();
                restart();
            }
        }
    }

    IpcHandler {
        target: "magic"
        function toggle(name: string): void { root.open([name], null); }
    }
}
