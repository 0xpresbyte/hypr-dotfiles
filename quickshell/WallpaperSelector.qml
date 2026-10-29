import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Wallpaper picker for the images in the repo's wallpapers/ folder: a looping
// cover-flow carousel that slides up from the bottom of the screen. The centered
// card faces forward; cards on either side are turned 45° and the whole set
// spins like a revolver cylinder.
// Toggle with `qs ipc call wallpaper toggle` (bound to SUPER+W).
// Left/Right, H/L or the mouse wheel to spin; the focused card is applied
// automatically (wallpaper + matugen colors) once the spin settles.
// Enter, Esc or clicking outside closes.
Scope {
    id: root

    property bool shown: false
    property var images: []
    property string current: ""

    readonly property string script: `${Quickshell.env("HOME")}/.config/hypr/scripts/wallpaper.sh`

    // 0 = hidden, 1 = fully slid in. The window stays mapped while it animates out.
    property real progress: shown ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // Sets the wallpaper and regenerates matugen colors (skips the current one).
    function setWallpaper(path) {
        if (!path || path === current) return;
        Quickshell.execDetached([script, path]);
    }

    function apply(path) {
        preview.stop();
        setWallpaper(path);
        shown = false;
    }

    // Live preview: apply the focused card once the carousel rests on it,
    // so fast spinning doesn't run matugen for every card passed.
    Timer {
        id: preview
        interval: 120
        onTriggered: root.setWallpaper(root.images[wheel.currentIndex])
    }

    onShownChanged: {
        if (shown) {
            currentFile.reload();   // the file may not have existed when the shell loaded
            lister.running = true;
        } else {
            preview.stop();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.shown = !root.shown; }
        function open(): void { root.shown = true; }
        function close(): void { root.shown = false; }
        function next(): void { wheel.spin(1); }
        function prev(): void { wheel.spin(-1); }
    }

    // Image list comes from wallpaper.sh, which knows where the repo lives.
    Process {
        id: lister
        command: [root.script, "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.split("\n").filter(line => line !== "");
                wheel.currentIndex = Math.max(0, root.images.indexOf(root.current));
            }
        }
    }

    // The current wallpaper, as recorded by wallpaper.sh.
    FileView {
        id: currentFile
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/wallpaper/current`
        blockLoading: true
        watchChanges: true
        printErrors: false   // missing until wallpaper.sh has run once
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }

    PanelWindow {
        visible: root.progress > 0
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
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-wallpaper"

        // Dim the screen; click anywhere outside the cards to close.
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("black", 0.35 * root.progress)

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }
        }

        // Carousel area along the bottom, slid in by `progress`.
        Item {
            id: stage
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 40
            }
            height: cardHeight + 60

            readonly property real cardWidth: Math.min(340, parent.width * 0.2)
            readonly property real cardHeight: cardWidth * 9 / 16

            transform: Translate {
                y: (1 - root.progress) * (stage.height + 60)
            }

            PathView {
                id: wheel
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: stage.cardHeight
                model: root.images
                focus: root.shown
                pathItemCount: Math.min(5, root.images.length)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 320
                interactive: false   // spin with keys/wheel/click, not dragging

                // Only user spins schedule a preview; positioning on open must not.
                function spin(step) {
                    if (step > 0) incrementCurrentIndex();
                    else decrementCurrentIndex();
                    preview.restart();
                }
                function focusCard(index) {
                    currentIndex = index;
                    preview.restart();
                }

                Keys.onEscapePressed: root.shown = false
                Keys.onReturnPressed: root.apply(root.images[currentIndex])
                Keys.onEnterPressed: root.apply(root.images[currentIndex])
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) spin(-1);
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) spin(1);
                    else return;
                    event.accepted = true;
                }

                // Cards: 45° on each side, flat and full size in the middle.
                path: Path {
                    startX: 0
                    startY: wheel.height / 2
                    PathAttribute { name: "angle"; value: 45 }
                    PathAttribute { name: "itemScale"; value: 0.7 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0.35 }

                    PathLine { x: wheel.width * 0.33; y: wheel.height / 2 }
                    PathPercent { value: 0.3 }
                    PathAttribute { name: "angle"; value: 45 }
                    PathAttribute { name: "itemScale"; value: 0.82 }
                    PathAttribute { name: "itemZ"; value: 5 }
                    PathAttribute { name: "itemOpacity"; value: 0.75 }

                    PathLine { x: wheel.width * 0.5; y: wheel.height / 2 }
                    PathPercent { value: 0.5 }
                    PathAttribute { name: "angle"; value: 0 }
                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }

                    PathLine { x: wheel.width * 0.67; y: wheel.height / 2 }
                    PathPercent { value: 0.7 }
                    PathAttribute { name: "angle"; value: -45 }
                    PathAttribute { name: "itemScale"; value: 0.82 }
                    PathAttribute { name: "itemZ"; value: 5 }
                    PathAttribute { name: "itemOpacity"; value: 0.75 }

                    PathLine { x: wheel.width; y: wheel.height / 2 }
                    PathPercent { value: 1.0 }
                    PathAttribute { name: "angle"; value: -45 }
                    PathAttribute { name: "itemScale"; value: 0.7 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0.35 }
                }

                delegate: ClippingRectangle {
                    id: card
                    required property string modelData
                    required property int index

                    width: stage.cardWidth
                    height: stage.cardHeight
                    radius: 14
                    color: "transparent"
                    z: PathView.itemZ ?? 0
                    scale: PathView.itemScale ?? 1
                    opacity: PathView.itemOpacity ?? 1

                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: card.PathView.angle ?? 0
                    }

                    Image {
                        anchors.fill: parent
                        source: `file://${card.modelData}`
                        sourceSize.width: 800
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.index === wheel.currentIndex ? root.apply(card.modelData) : wheel.focusCard(card.index)
                    }
                }

                // Mouse wheel spins the cylinder.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheelEvent => {
                        wheel.spin(wheelEvent.angleDelta.y > 0 || wheelEvent.angleDelta.x > 0 ? -1 : 1);
                    }
                }
            }

            // Name of the selected wallpaper, with a dot if it's the one in use.
            Text {
                anchors {
                    top: wheel.bottom
                    topMargin: 24
                    horizontalCenter: parent.horizontalCenter
                }
                readonly property string selected: root.images[wheel.currentIndex] ?? ""
                text: root.images.length === 0
                    ? "No images in wallpapers/"
                    : (selected === root.current ? "  " : "") + selected.split("/").pop()
                color: Colors.surfaceText
                font.pixelSize: 13
                style: Text.Outline
                styleColor: Qt.alpha("black", 0.4)
            }
        }
    }
}
