pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "../.."

// Custom right-click context menu for system tray icons.
// Styled with Theme to match the shell. Nested submenus are
// handled with a StackView: entries with children push a new
// page, the back button pops it.
StackView {
    id: root

    required property QsMenuHandle handle

    signal closeRequested

    implicitWidth: 220
    implicitHeight: currentItem ? currentItem.implicitHeight : 0

    initialItem: SubMenu {
        handle: root.handle
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    Component {
        id: subMenuComp

        SubMenu {}
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
        property bool isSubMenu: false

        spacing: 2

        QsMenuOpener {
            id: menuOpener
            menu: menu.handle
        }

        Loader {
            active: menu.isSubMenu
            sourceComponent: Rectangle {
                implicitWidth: 220
                implicitHeight: 28
                radius: 8
                color: backMouse.containsMouse ? Theme.bgSelected : Theme.transparent

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹ Back"
                    font: Theme.bodyFont
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pop()
                }
            }
        }

        Repeater {
            model: menuOpener.children

            delegate: Item {
                required property QsMenuEntry modelData

                implicitWidth: 220
                implicitHeight: modelData.isSeparator ? 9 : 30

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    visible: modelData.isSeparator
                    color: Theme.separator
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    visible: !modelData.isSeparator
                    color: entryMouse.containsMouse ? Theme.bgSelected : Theme.transparent

                    IconImage {
                        id: entryIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        visible: modelData.icon !== ""
                        source: modelData.icon
                    }

                    Text {
                        anchors.left: entryIcon.visible ? entryIcon.right : parent.left
                        anchors.leftMargin: 8
                        anchors.right: expandMark.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: (modelData.checkState === Qt.Checked ? "✓ " : "") + modelData.text
                        font: Theme.bodyFont
                        color: modelData.enabled ? Theme.text : Theme.muted
                    }

                    Text {
                        id: expandMark
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        font: Theme.bodyFont
                        color: Theme.muted
                        visible: modelData.hasChildren
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!modelData.enabled)
                                return;
                            if (modelData.hasChildren) {
                                root.push(subMenuComp.createObject(root, {
                                    "handle": modelData,
                                    "isSubMenu": true
                                }));
                            } else {
                                modelData.triggered();
                                root.closeRequested();
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: 220
            height: visible ? 26 : 0
            visible: menuOpener.children.values.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "No actions"
            font: Theme.bodyFont
            color: Theme.muted
        }
    }
}
