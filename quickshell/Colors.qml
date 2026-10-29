pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Material colors generated from the wallpaper by matugen
// (matugen/templates/quickshell-colors.json -> ~/.local/state/quickshell/colors.json).
// Read live, so changing the wallpaper recolors the shell without reloading it.
// The values below are fallbacks until matugen has run.
Singleton {
    id: root

    property color primary: "#ffb2ba"
    property color primaryText: "#561d27"
    property color primaryContainer: "#72333c"
    property color primaryContainerText: "#ffd9dc"
    property color secondary: "#e5bdc0"
    property color secondaryText: "#43292c"
    property color secondaryContainer: "#5c3f42"
    property color secondaryContainerText: "#ffd9dc"
    property color tertiary: "#e9bf8f"
    property color tertiaryText: "#442b07"
    property color error: "#ffb4ab"
    property color errorText: "#690005"
    property color surface: "#1a1112"
    property color surfaceText: "#f0dedf"
    property color surfaceVariant: "#524344"
    property color surfaceVariantText: "#d7c1c3"
    property color surfaceContainerLow: "#22191a"
    property color surfaceContainer: "#261d1e"
    property color surfaceContainerHigh: "#312828"
    property color surfaceContainerHighest: "#3d3233"
    property color outline: "#9f8c8d"
    property color outlineVariant: "#524344"
    property color shadow: "#000000"

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/colors.json`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const colors = JSON.parse(text());
                for (const key in colors)
                    if (key in root)
                        root[key] = colors[key];
            } catch (e) {
                console.warn(`Colors: can't parse ${path}: ${e}`);
            }
        }
    }
}
