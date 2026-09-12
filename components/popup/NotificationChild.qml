import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."

Rectangle {
    id: root

    // The real Quickshell notification object (NotificationServer.trackedNotifications entry).
    // Exposes: appName, appIcon, summary, body, image, actions, urgency, dismiss(), etc.
    required property var notification
    property bool expanded: false

    radius: Theme.radius - 6
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    // Let ListView / layouts size us; content drives implicit height.
    // NOTE: no Behavior here on purpose — the panel (notifBox.animatedHeight)
    // owns the grow/shrink animation. Animating the delegate too makes
    // contentHeight tick every frame, which restarts the parent animation
    // and causes the lag.
    implicitWidth: 360
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.leftMargin: 16
        spacing: 6

        // ── Header row: app icon + appName + summary + expand chevron ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // App icon (fallback to bell glyph)
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.border
                }
                IconImage {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: Quickshell.iconPath(root.notification?.appIcon ?? "", true)
                    visible: (root.notification?.appIcon ?? "") !== ""
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: Theme.iconFont.family
                    font.pointSize: 12
                    color: Theme.textSecondary
                    visible: (root.notification?.appIcon ?? "") === ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Text {
                        text: root.notification?.summary ?? ""
                        font: Theme.bodyFont
                        color: Theme.text
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        visible: text !== ""
                    }
                    Text {
                        id: separator
                        text: "∙"
                        font: Theme.bodyFont
                        // font.pointSize: 9
                        color: Theme.textSecondary
                        maximumLineCount: 1
                    }
                    
                    Text {
                        text: root.notification?.appName ?? "Notification"
                        font.family: Theme.bodyFont
                        font.pointSize: 10
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                // ── Body: 1 truncated line when collapsed, full wrapped text when expanded ──
                Text {
                    id: bodyText
                    Layout.fillWidth: true
                    visible: (root.notification?.body ?? "") !== ""
                    text: root.notification?.body ?? ""
                    font: Theme.bodyFont
                    color: Theme.textSecondary

                    // Collapsed: single truncated line. Expanded: full wrap.
                    maximumLineCount: root.expanded ? 99 : 1
                    elide: root.expanded ? Text.ElideNone : Text.ElideRight
                    wrapMode: root.expanded ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                }
            }

            // Expand / collapse chevron
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: expandMouse.containsMouse ? Theme.bgSelected : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationSpeed / 2
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.iconFont.family
                    font.pointSize: 12
                    color: Theme.text
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.animationSpeed / 2
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                MouseArea {
                    id: expandMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }

            // Dismiss button
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: dismissMouse.containsMouse ? Theme.bgSelected : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationSpeed / 2
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.iconFont.family
                    font.pointSize: 10
                    color: Theme.textSecondary
                }
                MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notification?.dismiss()
                }
            }
        }

        // ── Actions: only visible when expanded (and actions exist) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.expanded && (root.notification?.actions.length ?? 0) > 0

            Repeater {
                model: root.notification?.actions ?? []

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: actionMouse.containsMouse ? Theme.bgSelected : Theme.background
                    border.width: 1
                    border.color: Theme.border

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animationSpeed / 2
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: modelData.text || ("Action " + (index + 1))
                        font: Theme.bodyFont
                        color: Theme.text
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    // Click anywhere on the card to expand / collapse
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Don't steal clicks from buttons / actions stacked above
        z: -1
        onClicked: root.expanded = !root.expanded
    }
}
