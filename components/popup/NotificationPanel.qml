import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../bar"
import "../.."

Scope {
    id: root
    property bool closed: true
    onClosedChanged: {
        if (!closed) {
            // Opening: snap to final size so the slide-down runs at full
            // height instead of fighting a mid-flight shrink.
            heightDebounce.stop();
            heightAnim.stop();
            notifBox.animatedHeight = notifBox.targetHeight;
            notifBox.pendingHeight = notifBox.targetHeight;
        } else {
            // Closing: freeze height, let the y/scale slide own the motion.
            heightDebounce.stop();
            heightAnim.stop();
        }
    }

    // Owns the notification daemon endpoint. All tracked notifications
    // become rows in the list below via server.trackedNotifications.
    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            if (root.closed)
                root.toggle();
        }
    }

    function clearAll() {
        const items = [...notifServer.trackedNotifications.values];
        for (const n of items)
            n.dismiss();
    }

    Timer {
        id: closeTimer
        interval: 500
        onTriggered: () => {
            if (root.closed)
                notifPopup.visible = false;
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
            notifPopup.visible = true;
        } else {
            hidePanel();
        }
    }

    // qmllint disable uncreatable-type
    PanelWindow {
        id: notifPopup
        visible: false
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-notifications"

        exclusionMode: ExclusionMode.Ignore

        // Only the card itself is the window — no fullscreen surface, so
        // keyboard focus (OnDemand) and mouse input only apply when the
        // cursor is actually over the notification panel. Nothing outside
        // the card can steal focus or block clicks.
        anchors {
            top: true
            right: true
        }
        margins.top: topBar.height
        margins.right: Theme.gap

        implicitWidth: 400 + cornerTopLeft.r
        // Snap on grow (one surface resize), follow on shrink (no clipping).
        // Per-frame surface resizes were the main lag source.
        implicitHeight: Math.max(notifBox.windowHeight, notifBox.animatedHeight) + cornerBottomRight.r

        // Dropdown card, top-right — same feel as quick settings / tray
        Rectangle {
            id: notifBox
            width: 400
            property int targetHeight: Math.min(520, header.implicitHeight + listContent.implicitHeight + 24)
            property int animatedHeight: targetHeight
            property int pendingHeight: targetHeight
            property int windowHeight: targetHeight
            height: animatedHeight
            onTargetHeightChanged: {
                if (root.closed) {
                    heightAnim.stop();
                    heightDebounce.stop();
                    animatedHeight = targetHeight;
                    pendingHeight = targetHeight;
                    windowHeight = targetHeight;
                } else {
                    pendingHeight = targetHeight;
                    heightDebounce.restart();
                }
            }
            Timer {
                id: heightDebounce
                interval: 30
                onTriggered: {
                    if (Math.abs(notifBox.pendingHeight - notifBox.animatedHeight) > 2) {
                        const growing = notifBox.pendingHeight > notifBox.animatedHeight;
                        heightAnim.duration = growing ? 200 : 150;
                        heightAnim.to = notifBox.pendingHeight;
                        if (growing)
                            notifBox.windowHeight = notifBox.pendingHeight;  // resize surface once, up front
                        heightAnim.restart();
                    } else {
                        notifBox.animatedHeight = notifBox.pendingHeight;
                        notifBox.windowHeight = notifBox.pendingHeight;
                    }
                }
            }
            bottomLeftRadius: 16
            color: Theme.background
            y: root.closed ? -height - Theme.gap : 0
            x: cornerTopLeft.r
            opacity: root.closed ? 0 : 1
            scale: root.closed ? 0.94 : 1
            transformOrigin: Item.TopRight
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

            NumberAnimation {
                id: heightAnim
                target: notifBox
                property: "animatedHeight"
                duration: 500
                easing.type: Easing.OutExpo
                onStopped: notifBox.windowHeight = notifBox.pendingHeight  // resize surface once, at the end (shrink case)
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            InvertedCorner {
                id: cornerTopLeft
                joint: "bottomLeft"
                x: 0 - r
                y: 0
            }
            InvertedCorner {
                id: cornerBottomRight
                joint: "bottomLeft"
                x: notifBox.width - r
                y: notifBox.height
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12

                RowLayout {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8
                }

                // ── List of NotificationChild ──
                Item {
                    id: listContent
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    implicitHeight: notifList.count === 0 ? emptyState.implicitHeight : Math.min(440, notifList.contentHeight)

                    Text {
                        id: emptyState
                        anchors.centerIn: parent
                        text: "No notifications"
                        font: Theme.bodyFont
                        color: Theme.textSecondary
                        visible: notifList.count === 0
                    }

                    ListView {
                        id: notifList
                        anchors.fill: parent
                        clip: true
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds

                        model: notifServer.trackedNotifications

                        onCountChanged: {
                            if (count === 0 && !root.closed)
                                root.hidePanel();
                        }

                        delegate: NotificationChild {
                            required property var modelData
                            required property int index

                            notification: modelData
                            width: ListView.view.width
                        }

                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        // NOTE: no displaced Transition on purpose — during
                        // shrink it slides every delegate's y while the panel
                        // height is also animating, doubling the per-frame
                        // layout/paint work. Delegates settle instantly and
                        // the panel grow/shrink covers the motion.
                    }
                }
            }
        }
    }
}
