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

    // Custom right-click context menu state
    property bool contextOpen: false
    property var contextMenuHandle: null
    property Item contextAnchorItem: null
    property point contextClickPos: Qt.point(0, 0)

    onClosedChanged: {
        if (closed)
            closeContextMenu();
    }

    function openContextMenu(handle, anchorItem) {
        menuCloseTimer.stop();
        contextMenuHandle = handle;
        contextAnchorItem = anchorItem;
        contextClickPos = anchorItem.mapToItem(menuLayer, 0, anchorItem.height + 4);
        // Recreate the menu so submenu navigation always starts fresh.
        menuLoader.active = false;
        menuLoader.active = true;
        contextOpen = true;
    }

    function closeContextMenu() {
        if (!contextOpen && !menuCloseTimer.running)
            return;
        contextOpen = false;
        // Hide the layer (and destroy the menu) after the fade-out finishes.
        menuCloseTimer.start();
    }

    Timer {
        id: menuCloseTimer
        interval: 200
        onTriggered: {
            if (!root.contextOpen) {
                menuLoader.active = false;
                contextMenuHandle = null;
                contextAnchorItem = null;
            }
        }
    }

    // Position the menu card next to the clicked icon, flipping above
    // it and clamping to the layer when it would overflow.
    function positionContextMenu() {
        var item = menuLoader.item;
        if (!item || !contextAnchorItem)
            return;
        var menuW = item.implicitWidth + 16;
        var menuH = item.implicitHeight + 16;
        menuCard.x = Math.min(Math.max(contextClickPos.x, 8), Math.max(8, menuLayer.width - menuW - 8));
        var y = contextClickPos.y;
        var flipped = y + menuH > layer.height - 8;
        if (flipped)
            y = Math.max(8, contextAnchorItem.mapToItem(layer, 0, -menuH - 4).y);
        menuCard.y = y;
        menuCard.transformOrigin = flipped ? Item.BottomLeft : Item.TopLeft;
    }

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
            onClicked: {
                if (root.contextOpen)
                    root.closeContextMenu();
                else
                    root.toggle();
            }
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
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        width: trayGrid.cellWidth
                        height: trayGrid.cellHeight

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

                                    // ToolTip {
                                    //     visible: trayMouse.containsMouse
                                    //     text: modelData.tooltipTitle || modelData.title || modelData.id || "App"
                                    //     delay: 400
                                    //     font.family: Theme.bodyFont.family
                                    //     font.pointSize: 9
                                    // }
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
                                    if (modelData.onlyMenu && modelData.hasMenu)
                                        root.openContextMenu(modelData.menu, delegateRoot);
                                    else
                                        modelData.activate();
                                } else if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu)
                                        root.openContextMenu(modelData.menu, delegateRoot);
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

        // Custom context menu layer, above the card.
        Item {
            id: menuLayer
            anchors.fill: parent
            visible: root.contextOpen || menuCloseTimer.running

            // Clicking outside the menu dismisses it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.closeContextMenu()
            }

            Rectangle {
                id: menuCard
                width: (menuLoader.item ? menuLoader.item.implicitWidth : 200) + 16
                height: (menuLoader.item ? menuLoader.item.implicitHeight : 0) + 16
                radius: 12
                color: Theme.background
                border.color: Theme.border
                border.width: 1
                opacity: root.contextOpen ? 1 : 0
                scale: root.contextOpen ? 1 : 0.94
                transformOrigin: Item.TopLeft
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutExpo
                    }
                }
                // Smooth resize when navigating between submenu pages.
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                // Keep the card on-screen when a submenu grows taller.
                onHeightChanged: {
                    if (root.contextOpen && y + height > menuLayer.height - 8)
                        y = Math.max(8, menuLayer.height - 8 - height);
                }

                Loader {
                    id: menuLoader
                    anchors.fill: parent
                    anchors.margins: 8
                    active: false
                    sourceComponent: TrayContextMenu {
                        handle: root.contextMenuHandle
                        onCloseRequested: root.closeContextMenu()
                    }
                    onLoaded: root.positionContextMenu()
                }
            }
        }
    }
}
