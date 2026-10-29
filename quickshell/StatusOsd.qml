import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Status panel at the top-right: system tray, battery and clock. Like the
// workspace indicator, it slides in while SUPER is held (SuperKey.qml) and
// slides out as soon as SUPER is released. While held, SUPER+H/L select a tray
// icon; releasing SUPER opens that app in the `magic` special workspace.
Scope {
    id: root

    readonly property bool shown: SuperKey.held
    readonly property var magic: Magic   // create the singleton now so its IPC target exists
    property real progress: shown ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // Tray icon picked with SUPER+H/L (-1 = none).
    property int selected: -1

    function step(delta) {
        const count = SystemTray.items.values.length;
        if (!shown || count === 0) return;
        selected = selected < 0 ? (delta > 0 ? 0 : count - 1) : (selected + delta + count) % count;
    }

    function openInMagic(item) {
        Magic.open([item.id, item.title, item.tooltipTitle], () => item.activate());
    }

    onShownChanged: {
        if (shown) {
            battery.refresh();
        } else {
            const item = SystemTray.items.values[selected];
            if (item) openInMagic(item);
        }
        selected = -1;
    }

    GlobalShortcut {
        name: "trayPrev"
        description: "Select the previous tray icon while SUPER is held"
        onPressed: root.step(-1)
    }

    GlobalShortcut {
        name: "trayNext"
        description: "Select the next tray icon while SUPER is held"
        onPressed: root.step(1)
    }

    // Battery, read from sysfs (UPower isn't required).
    QtObject {
        id: battery

        readonly property string dir: "/sys/class/power_supply/BAT0"
        property int percent: -1
        property string status: ""
        property real energyNow: 0
        property real energyFull: 0
        property real powerNow: 0

        readonly property bool present: percent >= 0
        readonly property bool charging: status === "Charging"
        readonly property bool full: status === "Full" || status === "Not charging"

        // Hours left: to empty while discharging, to full while charging.
        readonly property real hoursLeft: powerNow <= 0 ? 0
            : charging ? (energyFull - energyNow) / powerNow
            : full ? 0 : energyNow / powerNow

        readonly property string icon: charging ? ""
            : percent >= 90 ? "" : percent >= 65 ? ""
            : percent >= 40 ? "" : percent >= 15 ? "" : ""

        function refresh() {
            capacityFile.reload();
            statusFile.reload();
            energyNowFile.reload();
            energyFullFile.reload();
            powerNowFile.reload();
        }
    }

    FileView { id: capacityFile; path: `${battery.dir}/capacity`; printErrors: false; onLoaded: battery.percent = parseInt(text()) }
    FileView { id: statusFile; path: `${battery.dir}/status`; printErrors: false; onLoaded: battery.status = text().trim() }
    FileView { id: energyNowFile; path: `${battery.dir}/energy_now`; printErrors: false; onLoaded: battery.energyNow = parseFloat(text()) }
    FileView { id: energyFullFile; path: `${battery.dir}/energy_full`; printErrors: false; onLoaded: battery.energyFull = parseFloat(text()) }
    FileView { id: powerNowFile; path: `${battery.dir}/power_now`; printErrors: false; onLoaded: battery.powerNow = parseFloat(text()) }

    // sysfs files don't notify on change; refresh while visible.
    Timer {
        interval: 5000
        running: root.shown
        repeat: true
        onTriggered: battery.refresh()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PanelWindow {
        id: window
        visible: root.progress > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        anchors {
            top: true
            right: true
        }
        margins {
            top: 14
            right: 14
        }
        implicitWidth: panel.width + 24
        implicitHeight: panel.height + 8
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-status"

        Rectangle {
            id: panel
            anchors {
                top: parent.top
                right: parent.right
            }
            width: row.implicitWidth + 28
            height: 38
            radius: height / 2
            color: Qt.alpha(Colors.surface, Theme.opacity)
            border.width: 1
            border.color: Colors.outlineVariant

            opacity: root.progress
            transform: Translate {
                x: (1 - root.progress) * 24
            }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 14

                // System tray
                RowLayout {
                    visible: SystemTray.items.values.length > 0
                    spacing: 10

                    Repeater {
                        model: SystemTray.items

                        IconImage {
                            id: trayIcon
                            required property SystemTrayItem modelData
                            required property int index
                            implicitSize: 16
                            source: modelData.icon

                            // Selection ring (SUPER+H/L), drawn behind the icon.
                            Rectangle {
                                z: -1
                                anchors.centerIn: parent
                                width: parent.width + 12
                                height: width
                                radius: width / 2
                                color: Qt.alpha(Colors.primary, 0.18)
                                border.width: 2
                                border.color: Colors.primary
                                opacity: trayIcon.index === root.selected ? 1 : 0
                                scale: trayIcon.index === root.selected ? 1 : 0.6

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    const item = trayIcon.modelData;
                                    const menuAt = () => {
                                        const pos = trayIcon.mapToItem(window.contentItem, 0, trayIcon.height + 8);
                                        item.display(window, pos.x, pos.y);
                                    };
                                    if (mouse.button === Qt.MiddleButton) item.secondaryActivate();
                                    else if (mouse.button === Qt.RightButton || item.onlyMenu) { if (item.hasMenu) menuAt(); }
                                    // Left click: pop the app's window into the `magic` special workspace.
                                    else root.openInMagic(item);
                                }
                                onWheel: wheel => trayIcon.modelData.scroll(wheel.angleDelta.y / 120, false)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: SystemTray.items.values.length > 0
                    implicitWidth: 1
                    implicitHeight: 16
                    color: Colors.outlineVariant
                }

                // Battery
                RowLayout {
                    visible: battery.present
                    spacing: 6

                    Text {
                        text: battery.icon
                        color: battery.charging ? Colors.tertiary
                            : battery.percent <= 15 ? Colors.error : Colors.primary
                        font.pixelSize: 14
                    }
                    Text {
                        text: `${battery.percent}%`
                        color: Colors.surfaceText
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        visible: battery.hoursLeft > 0
                        text: {
                            const mins = Math.round(battery.hoursLeft * 60);
                            return `${Math.floor(mins / 60)}h ${mins % 60}m`;
                        }
                        color: Colors.surfaceVariantText
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    visible: battery.present
                    implicitWidth: 1
                    implicitHeight: 16
                    color: Colors.outlineVariant
                }

                // Clock
                RowLayout {
                    spacing: 8

                    Text {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Colors.surfaceText
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Colors.surfaceVariantText
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
