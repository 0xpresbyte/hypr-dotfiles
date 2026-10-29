pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared look settings from ~/.config/theme/settings.conf (theme/ in the repo),
// the same file Ghostty includes. Updates live when the file changes.
Singleton {
    id: root

    property real opacity: 0.75

    function read(key, fallback) {
        const match = file.text().match(new RegExp(`^\\s*${key}\\s*=\\s*([0-9.]+)`, "m"));
        return match ? parseFloat(match[1]) : fallback;
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/theme/settings.conf`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.opacity = root.read("background-opacity", 0.75)
    }
}
