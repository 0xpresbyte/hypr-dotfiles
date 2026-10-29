import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// App launcher. Toggle with `qs ipc call launcher toggle` (bound to SUPER+R).
// Type to search, Up/Down (or Ctrl+J/K) to move, Enter to launch, Esc to close.
Scope {
    id: root

    property bool shown: false

    readonly property var apps: DesktopEntries.applications.values
        .filter(app => !app.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    property string query: ""
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return apps;
        return apps
            .map(app => ({ app, score: score(app, q) }))
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score)
            .map(r => r.app);
    }

    // Name prefix > word prefix > substring > other fields > fuzzy subsequence.
    function score(app, q) {
        const name = app.name.toLowerCase();
        if (name.startsWith(q)) return 100;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        const extra = [app.genericName, app.comment, ...app.keywords].join(" ").toLowerCase();
        if (extra.includes(q)) return 40;
        let i = 0;
        for (const c of name)
            if (c === q[i] && ++i === q.length) return 20;
        return 0;
    }

    function toggle() {
        shown = !shown;
    }

    function launch(app) {
        if (!app) return;
        app.execute();
        shown = false;
    }

    onShownChanged: if (shown) query = ""

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.shown = true; }
        function close(): void { root.shown = false; }
    }

    PanelWindow {
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"

        // Click outside the panel to close.
        MouseArea {
            anchors.fill: parent
            onClicked: root.shown = false
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 560
            height: column.implicitHeight + 24
            radius: 16
            color: Qt.alpha(Colors.surface, Theme.opacity)
            border.width: 1
            border.color: Colors.outlineVariant

            // Swallow clicks so they don't reach the close area.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: column
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                // Search box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    Text {
                        id: searchIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: ""
                        color: Colors.primary
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: input
                        anchors {
                            left: searchIcon.right
                            right: parent.right
                            leftMargin: 12
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        focus: root.shown
                        text: root.query
                        onTextChanged: {
                            root.query = text;
                            list.currentIndex = 0;
                        }
                        color: Colors.surfaceText
                        selectionColor: Colors.primaryContainer
                        selectedTextColor: Colors.primaryContainerText
                        font.pixelSize: 16
                        clip: true

                        Text {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "Search apps…"
                            color: Colors.outline
                            font: input.font
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) {
                                root.shown = false;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launch(root.results[list.currentIndex]);
                            } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) {
                                list.incrementCurrentIndex();
                            } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) {
                                list.decrementCurrentIndex();
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                // Results
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, 8 * 48)
                    clip: true
                    model: root.results
                    currentIndex: 0
                    highlightMoveDuration: 120
                    boundsBehavior: Flickable.StopAtBounds

                    highlight: Rectangle {
                        radius: 10
                        color: Colors.primaryContainer
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem

                        width: list.width
                        height: 48

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 12

                            IconImage {
                                implicitSize: 28
                                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    color: row.current ? Colors.primaryContainerText : Colors.surfaceText
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.genericName || row.modelData.comment
                                    color: row.current ? Colors.primaryContainerText : Colors.surfaceVariantText
                                    opacity: 0.7
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: root.launch(row.modelData)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    visible: root.results.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "No matches"
                    color: Colors.outline
                    font.pixelSize: 13
                }
            }
        }
    }
}
