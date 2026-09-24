import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../bar"
import "../../services"

Scope {
    id: root
    property bool closed: true

    // Brightness state (0..1). brightnessOk tracks whether brightnessctl works.
    property real brightness: 0
    property bool brightnessOk: false

    Process {
        id: brightGetProc
        command: ["sh", "-c", "brightnessctl -m | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                // machine format: device,class,current,percent%,max
                var parts = data.trim().split(",");
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3]);
                    if (!isNaN(pct)) {
                        root.brightness = Math.max(0, Math.min(1, pct / 100));
                        root.brightnessOk = true;
                    }
                }
            }
        }
    }

    Process {
        id: brightSetProc
        command: ["true"]
    }

    // Re-poll brightness while visible so external changes stay in sync
    Timer {
        id: brightPollTimer
        interval: 3000
        running: !root.closed
        repeat: true
        triggeredOnStart: true
        onTriggered: brightGetProc.running = true
    }

    // Grace for the mouse to travel from the bar into the popup
    Timer {
        id: hideDelay
        interval: 1000
        onTriggered: {
            // Never close mid-drag — re-check on the next tick instead.
            if (volSlider.pressed || brightSlider.pressed)
                hideDelay.restart();
            else
                root.hidePanel();
        }
    }

    // Covers the slide-out animation (see closeTimer fix)
    Timer {
        id: closeTimer
        interval: Theme.animationSpeed
        onTriggered: () => {
            if (root.closed)
                sliderPopup.visible = false;
        }
    }

    function show() {
        hideDelay.stop();
        closeTimer.stop();
        sliderPopup.visible = true;
        root.closed = false;
        brightGetProc.running = true;
    }
    function hidePanel() {
        hideDelay.stop();
        root.closed = true;
        closeTimer.restart();
    }

    // qmllint disable uncreatable-type
    PanelWindow {
        id: sliderPopup
        visible: false
        focusable: false
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-sliders"

        exclusionMode: ExclusionMode.Ignore

        // Fullscreen. No input mask: the click-catcher below needs to see
        // clicks anywhere outside the card so they force-close the popup.
        // (Tradeoff: while open, the first outside click is swallowed to
        // close, like the other popups.)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.closed ? 0 : 0.35
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationSpeed
                    easing.type: Easing.OutCubic
                }
            }
        }
        // Last resort: any press outside the card closes immediately.
        MouseArea {
            anchors.fill: parent
            onPressed: root.hidePanel()
        }

        // Fixed docked frame, clipped at the bar's edge. The card slides
        // inside it, so it looks like it emerges from *behind* the panel
        // even though the window stays on top (a lower layer would also
        // fall behind normal app windows, hiding the popup entirely).
        Item {
            id: sliderClip
            // Frame = card + one corner band above and below, so the whole
            // thing (card + joint corners) is exactly vertically centered
            // and nothing gets clipped.
            width: sliderContent.implicitWidth + (Theme.gap - 4) * 2
            height: sliderBox.height + cornerTop.r + cornerBottom.r
            x: parent.width - width - rightBar.width
            y: (parent.height - height) / 2 + 16
            clip: true

            InvertedCorner {
                id: cornerTop
                joint: "topLeft"
                x: sliderBox.x + parent.width - r
                y: 0
            }

            InvertedCorner {
                id: cornerBottom
                joint: "bottomLeft"
                x: sliderBox.x + parent.width - r
                y: parent.height - r
            }
            Rectangle {
                id: sliderBox
                width: parent.width
                height: sliderContent.implicitHeight + (Theme.gap - 4) * 2
                // Slides within the clipped frame: hidden = pushed past
                // the bar edge, open = docked. Offset by exactly one corner
                // band so the card sits centered between the two corners.
                x: root.closed ? parent.width + Theme.gap : 0
                y: cornerTop.r
                topLeftRadius: 16
                bottomLeftRadius: 16
                color: Theme.background
                opacity: root.closed ? 0 : 1
                scale: root.closed ? 0.94 : 1
                transformOrigin: Item.Right
                Behavior on x {
                    NumberAnimation {
                        duration: Theme.animationSpeed
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animationSpeed
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationSpeed / 2
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    id: sliderContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.gap - 4
                    spacing: 12

                    // ── Volume ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        PwObjectTracker {
                            objects: [Pipewire.defaultAudioSink]
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                const sink = Pipewire.defaultAudioSink;
                                if (!sink || sink.audio.muted)
                                    return "󰝟";
                                const v = sink.audio.volume;
                                if (v > 0.80)
                                    return "󰕾";
                                if (v > 0.20)
                                    return "󰖀";
                                return "󰕿";
                            }
                            font.family: Theme.iconFont.family
                            font.pointSize: 14
                            color: Theme.text
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (sink?.audio)
                                        sink.audio.muted = !sink.audio.muted;
                                }
                            }
                        }
                        Slider {
                            id: volSlider
                            orientation: Qt.Vertical
                            // Rotated so max is at the top: Qt maps vertical
                            // value downward, the flip puts 100% on top while
                            // keeping drags natural (up = louder).
                            rotation: 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillHeight: true
                            Layout.preferredHeight: 170
                            from: 0.0
                            to: 1.0
                            value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                            onMoved: () => {
                                const sink = Pipewire.defaultAudioSink?.audio;
                                if (sink) {
                                    sink.volume = value;
                                    if (value > 0 && sink.muted)
                                        sink.muted = false;
                                }
                            }
                            handle: Rectangle {
                                width: 30
                                height: 6
                                radius: 10
                                x: volSlider.leftPadding + (volSlider.availableWidth - width) / 2
                                y: volSlider.topPadding + volSlider.visualPosition * (volSlider.availableHeight - height)
                                color: "#888"
                                border.color: Theme.surface
                            }
                            background: Rectangle {
                                x: volSlider.leftPadding + volSlider.availableWidth / 2 - width / 2
                                y: volSlider.topPadding
                                implicitWidth: 22
                                width: implicitWidth
                                height: volSlider.availableHeight
                                radius: Theme.radius - 10
                                color: Theme.muted
                                border.width: 1
                                border.color: Theme.border
                                Rectangle {
                                    height: volSlider.visualPosition * parent.height
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    color: Theme.background
                                    radius: Theme.radius - 10
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round(volSlider.value * 100) + "%"
                            font: Theme.bodyFont
                            color: Theme.text
                        }
                    }

                    // ── Brightness ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.brightnessOk ? (root.brightness > 0.66 ? "󰃠" : root.brightness > 0.33 ? "󰃟" : "󰃞") : "󰃞"
                            font.family: Theme.iconFont.family
                            font.pointSize: 14
                            color: root.brightnessOk ? Theme.text : Theme.muted
                        }
                        Slider {
                            id: brightSlider
                            orientation: Qt.Vertical
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillHeight: true
                            Layout.preferredHeight: 170
                            enabled: root.brightnessOk
                            from: 0.05
                            to: 1.0
                            value: root.brightness
                            onMoved: () => {
                                root.brightness = value;
                                brightSetProc.command = ["brightnessctl", "set", Math.round(value * 100) + "%", "-q"];
                                brightSetProc.running = true;
                            }
                            handle: Rectangle {
                                width: 30
                                height: 6
                                radius: 10
                                x: brightSlider.leftPadding + (brightSlider.availableWidth - width) / 2
                                y: brightSlider.topPadding + brightSlider.visualPosition * (brightSlider.availableHeight - height)
                                color: "#888"
                                border.color: Theme.surface
                            }
                            background: Rectangle {
                                x: brightSlider.leftPadding + brightSlider.availableWidth / 2 - width / 2
                                y: brightSlider.topPadding
                                implicitWidth: 22
                                width: implicitWidth
                                height: brightSlider.availableHeight
                                radius: Theme.radius - 10
                                color: Theme.muted
                                border.width: 1
                                border.color: Theme.border
                                Rectangle {
                                    height: brightSlider.visualPosition * parent.height
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    color: Theme.background
                                    radius: Theme.radius - 10
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.brightnessOk ? Math.round(root.brightness * 100) + "%" : "N/A"
                            font: Theme.bodyFont
                            color: Theme.text
                        }
                    }
                }
            }
        }
    }
}
