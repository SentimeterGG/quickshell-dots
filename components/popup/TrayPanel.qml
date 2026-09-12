import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../bar"
import "../.."

Scope {
    id: root
    property bool closed: true

    // 4-column grid, box sizes itself to the icon count
    readonly property int trayColumns: 4
    readonly property real trayCell: 48
    readonly property int trayCount: SystemTray.items.values.length
    readonly property int trayCols: Math.max(1, Math.min(trayColumns, trayCount))
    readonly property int trayRows: Math.max(1, Math.ceil(Math.max(1, trayCount) / trayColumns))

    Timer {
        id: closeTimer
        interval: 500
        onTriggered: () => {
            if (root.closed)
                trayPopup.visible = false;
        }
    }

    function hidePanel() {
        root.closed = true;
        closeTimer.start();
    }
    function toggle() {
        root.closed = !root.closed;
        if (!closed) {
            closeTimer.stop();
            trayPopup.visible = true;
        } else {
            hidePanel();
        }
    }

    // qmllint disable uncreatable-type
    PanelWindow {
        id: trayPopup
        visible: false
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-tray"

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        margins.top: topBar.height

        // dim backdrop
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.closed ? 0 : 0.35
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }

        // Dropdown card, top-right, same feel as quick settings
        Rectangle {
            id: trayBox
            width: root.trayCols * root.trayCell + (Theme.gap - 10) * 2
            height: Math.max(trayContent.implicitHeight + (Theme.gap - 10) * 2, 25)
            radius: 16
            // square off the top edge that touches the bar so the
            // inverted corners blend seamlessly
            topLeftRadius: 0
            topRightRadius: 0
            color: Theme.background
            y: root.closed ? -height - Theme.gap : 0
            x: parent.width - width - Theme.gap - 115
            opacity: root.closed ? 0 : 1
            scale: root.closed ? 0.94 : 1
            transformOrigin: Item.Top
            Behavior on y {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: trayContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.gap - 10
                spacing: 10

                // Tray icons grid (4 per row, box grows with icon count)
                GridView {
                    id: trayGrid
                    Layout.preferredWidth: root.trayCols * root.trayCell
                    Layout.preferredHeight: root.trayRows * root.trayCell
                    visible: count > 0
                    clip: true
                    cellWidth: root.trayCell
                    cellHeight: root.trayCell
                    interactive: false

                    model: ScriptModel {
                        values: SystemTray.items.values
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: trayGrid.cellWidth
                        height: trayGrid.cellHeight

                        // Anchors the popup menu to this delegate and owns the QsMenuHandle
                        QsMenuAnchor {
                            id: menuAnchor
                            menu: modelData.menu
                        }

                        Rectangle {
                            id: iconBg
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            radius: 6
                            color: trayMouse.containsMouse ? Theme.bgSelected : Theme.background
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animationSpeed / 2
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                IconImage {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    source: modelData.icon

                                    ToolTip {
                                        visible: trayMouse.containsMouse
                                        text: modelData.tooltipTitle || modelData.title || modelData.id || "App"
                                        delay: 400
                                        font.family: Theme.bodyFont.family
                                        font.pointSize: 9
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    modelData.activate();
                                } else if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu)
                                        menuAnchor.open();
                                    else
                                        modelData.secondaryActivate();
                                }
                            }
                        }
                    }
                }
            }

            // Inverted corners: seamless joint where trayBox touches topBar
            InvertedCorner {
                joint: "bottomLeft"
                x: 0 - r
                y: 0
                opacity: trayBox.opacity
            }
            InvertedCorner {
                joint: "bottomRight"
                x: trayBox.width
                y: 0
                opacity: trayBox.opacity
            }
        }
    }
}
