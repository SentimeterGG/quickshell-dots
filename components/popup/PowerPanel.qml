import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../.."

Scope {
    id: root
    property bool closed: true
    function toggle() {
        closeTimer.stop();
        powerPanel.visible = true;
        root.closed = false;
    }
    Timer {
        id: closeTimer
        interval: Theme.animationSpeed
        onTriggered: () => {
            if (root.closed)
                powerPanel.visible = false;
        }
    }

    function hidePanel() {
        root.closed = true;
        closeTimer.start();
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        id: powerPanel
        visible: false
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        // Dark overlay backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: root.hidePanel()
        }
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: !root.closed ? 0.4 : 0
            Behavior on opacity {
                NumberAnimation {
                    easing: Easing.OutCubic
                    duration: Theme.animationSpeed
                }
            }
        }

        Process {
            id: processRunner
        }

        // Centered power menu box
        Rectangle {
            id: launcherBox
            anchors.centerIn: parent
            width: 630 + Theme.gap * 2
            height: 200 + Theme.gap * 2
            radius: 16
            color: Theme.background
            opacity: !root.closed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    easing: Easing.OutCubic
                    duration: Theme.animationSpeed / 2
                }
            }
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: [
                        {
                            icon: "\uf011",
                            label: "Power Off",
                            cmd: ["systemctl", "poweroff"]
                        },
                        {
                            icon: "\uf01e",
                            label: "Restart",
                            cmd: ["systemctl", "reboot"]
                        },
                        {
                            icon: "\uf2f5",
                            label: "Logout",
                            cmd: ["sh", "-c", "loginctl terminate-user $USER"]
                        }
                    ]

                    delegate: Item {
                        id: item
                        required property var modelData
                        implicitWidth: 200
                        implicitHeight: 200

                        Rectangle {
                            id: itemBg
                            anchors.fill: parent
                            radius: 12
                            color: mouseArea.containsMouse ? "#ffffff" : Theme.surface

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animationSpeed / 2
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont.family
                                    font.pointSize: 28
                                    color: mouseArea.containsMouse ? "#000000" : Theme.text
                                    Layout.alignment: Qt.AlignHCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.animationSpeed / 2
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.bodyFont.family
                                    font.pointSize: Theme.bodyFont.pointSize + 2
                                    color: mouseArea.containsMouse ? "#000000" : Theme.text
                                    Layout.alignment: Qt.AlignHCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.animationSpeed / 2
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                processRunner.exec(modelData.cmd);
                                powerPanel.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
