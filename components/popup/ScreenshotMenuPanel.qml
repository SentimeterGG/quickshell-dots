pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../.."

Scope {
    id: root
    property bool closed: true

    IpcHandler {
        target: "screenshot-menu"

        function toggle() {
            root.toggle();
        }
    }
    function toggle() {
        closeTimer.stop();
        panel.visible = true;
        root.closed = false;
    }
    Timer {
        id: closeTimer
        interval: Theme.animationSpeed
        onTriggered: () => {
            if (root.closed)
                panel.visible = false;
        }
    }

    function hidePanel() {
        root.closed = true;
        closeTimer.start();
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        id: panel
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

        // Centered menu box
        Rectangle {
            id: menuBox
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
                            icon: "󰹑",
                            label: "FullScreen",
                            grimshotType: "screen"
                        },
                        {
                            icon: "",
                            label: "Area",
                            grimshotType: "area"
                        },
                        {
                            icon: "",
                            label: "Window",
                            grimshotType: "window"
                        },
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
                                // Use the exec method to instantly reset, configure, and start the process safely
                                Quickshell.execDetached(["sh", "-c", "grimshot copy " + modelData.grimshotType + " && qs ipc call screenshot toggle"]);

                                // Instantly hide the panel UI so grimshot doesn't capture the menu itself
                                panel.visible = false;
                                root.closed = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
