import QtQuick
import Quickshell

ShellRoot {
    // No popup after a successful hot reload; failures still show one.
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    }

    Launcher {}
    WallpaperSelector {}
    WorkspaceOsd {}
    StatusOsd {}
}
