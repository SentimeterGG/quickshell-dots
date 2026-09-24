//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import "components/bar"
import "components/popup"

// qmllint disable uncreatable-type
Variants {
    model: Quickshell.screens
    delegate: Component {
        Item {
            id: screenRoot
            required property var modelData

            // ── TOP BAR (full widgets) ──────────────────────────────
            PanelWindow {
                id: topBar
                screen: screenRoot.modelData
                implicitHeight: 48
                exclusiveZone: 48
                color: Theme.background

                anchors {
                    left: true
                    top: true
                    right: true
                }

                RowLayout {
                    id: root

                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    anchors.fill: parent
                    uniformCellSizes: true

                    RowLayout {
                        id: leftSide

                        Button {
                            id: launcher

                            font.family: Theme.bodyFont.family
                            font.pointSize: 11
                            text: "󰣇"
                            Layout.preferredWidth: height
                            onClicked: launcherPopup.toggle()

                            background: Rectangle {
                                color: Theme.transparent
                            }
                        }

                        Separator {}
                        Workspace {}
                    }

                    Text {
                        id: clocks

                        property var date: new Date()

                        Layout.alignment: Qt.AlignCenter
                        font: Theme.clockFont
                        text: date.toLocaleString(Qt.locale(), "hh:mm AP")
                        color: Theme.text

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: parent.date = new Date()
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarPopup.toggle()
                        }
                    }

                    RowLayout {
                        id: rightSide

                        Layout.alignment: Qt.AlignRight
                        RoundButton {
                            id: trayButton
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            Layout.preferredWidth: height
                            Layout.fillHeight: true
                            background: Rectangle {
                                radius: Theme.radius - 10
                                color: Theme.surface
                            }
                            onClicked: trayPanel.toggle()
                            FlexboxLayout {
                                justifyContent: FlexboxLayout.JustifySpaceBetween
                                alignItems: FlexboxLayout.AlignCenter
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                Text {
                                    font: Theme.iconFont
                                    text: trayPanel.closed ? "" : ""
                                    color: Theme.text
                                }
                            }
                        }
                        RoundButton {
                            onClicked: quickSettingsPanel.toggle()
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            background: Rectangle {
                                radius: Theme.radius - 10
                                color: Theme.surface
                            }
                            Layout.preferredWidth: 90
                            Layout.fillHeight: true
                            FlexboxLayout {
                                justifyContent: FlexboxLayout.JustifySpaceBetween
                                alignItems: FlexboxLayout.AlignCenter
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                PwObjectTracker {
                                    objects: [Pipewire.defaultAudioSink]
                                }
                                Text {
                                    id: wifiIndicator
                                    text: {
                                        const wifi = Networking.devices.values.find(d => d.type === DeviceType.Wifi);
                                        const eth = Networking.devices.values.find(d => d.type === DeviceType.Wired);
                                        if (eth?.connected)
                                            return "󰌘";
                                        if (!wifi || !wifi.connected)
                                            return "󰤭";
                                        const net = wifi.networks.values.find(n => n.connected);
                                        if (!net)
                                            return "󰤭";
                                        const s = net.signalStrength;
                                        if (s > 0.80)
                                            return "󰤨";
                                        if (s > 0.60)
                                            return "󰤥";
                                        if (s > 0.30)
                                            return "󰤢";
                                        return "󰤟";
                                    }
                                    font: Theme.iconFont
                                    color: Theme.text
                                }
                                Text {
                                    id: soundIndicator
                                    text: {
                                        const sink = Pipewire.defaultAudioSink;
                                        if (!sink)
                                            return "󰕿";
                                        if (sink.audio.muted)
                                            return "󰝟";
                                        const v = sink.audio.volume;
                                        if (v > 0.80)
                                            return "󰕾";
                                        if (v > 0.20)
                                            return "󰖀";
                                        return "󰕿";
                                    }
                                    font.family: Theme.iconFont.family
                                    font.pointSize: 12
                                    color: Theme.text
                                }
                                Text {
                                    id: batteryIndicator
                                    text: {
                                        const bat = UPower.displayDevice;
                                        if (!bat || !bat.ready || !bat.isPresent)
                                            return "";
                                        if (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.PendingCharge)
                                            return "󱐋";
                                        if (bat.state === UPowerDeviceState.FullyCharged)
                                            return "";
                                        const raw = bat.percentage;
                                        const frac = raw > 1 ? raw / 100 : raw;
                                        if (frac > 0.75)
                                            return "";
                                        if (frac > 0.50)
                                            return "";
                                        if (frac > 0.25)
                                            return "";
                                        if (frac > 0.10)
                                            return "";
                                        return "";
                                    }
                                    font.family: Theme.iconFont.family
                                    font.pointSize: 11
                                    color: Theme.text
                                }
                            }
                        }
                        Separator {}

                        RoundButton {
                            id: poweroff

                            font: Theme.iconFont
                            text: " "
                            Layout.preferredWidth: height

                            background: Rectangle {
                                color: Theme.transparent
                            }
                            onClicked: powerPanel.toggle()
                        }
                    }
                }
            }

            // ── BOTTOM BAR (empty frame, widgets live on top) ───────
            PanelWindow {
                id: bottomBar
                screen: screenRoot.modelData
                implicitHeight: 16
                exclusiveZone: 16
                color: Theme.background

                anchors {
                    left: true
                    right: true
                    bottom: true
                }
            }

            // ── LEFT BAR (empty frame, inset between top/bottom) ─────
            PanelWindow {
                id: leftBar
                screen: screenRoot.modelData
                implicitWidth: 16
                exclusiveZone: 16
                color: Theme.background

                anchors {
                    top: true
                    bottom: true
                    left: true
                }
            }

            // ── RIGHT BAR (empty frame, inset between top/bottom) ────
            PanelWindow {
                id: rightBar
                screen: screenRoot.modelData
                implicitWidth: 16
                exclusiveZone: 16
                color: Theme.background

                anchors {
                    top: true
                    bottom: true
                    right: true
                }

                MouseArea {
                    id: rightClickZone
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor

                    property bool isOpen: sliderPopup.closed
                    onClicked: {
                        if (isOpen) {
                            sliderPopup.show();
                        } else {
                            sliderPopup.hidePanel();
                        }
                    }
                }

                // Subtle grip hint marking the preferred hover zone (centered)
                Rectangle {
                    id: gripHint
                    anchors.centerIn: parent
                    width: 4
                    height: 50
                    radius: 10
                    color: "#333"
                }
            }

            // ── FRAME CORNERS (rounded inner joints where bars meet) ─
            // Transparent fullscreen overlay. Bar windows are clipped to
            // their own rect, so the concave fillet at each inner junction
            // has to be drawn here, on the transparent gap. Takes no input.
            PanelWindow {
                id: frameCorners
                screen: screenRoot.modelData
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-frame-corners"

                mask: Region {}

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                readonly property real barT: topBar.height
                readonly property real barB: bottomBar.height
                readonly property real barL: leftBar.width
                readonly property real barR: rightBar.width

                // top-left inner joint (leftBar top end)
                InvertedCorner {
                    joint: "bottomRight"
                    x: frameCorners.barL
                    y: frameCorners.barT
                }
                // top-right inner joint
                InvertedCorner {
                    joint: "bottomLeft"
                    x: parent.width - frameCorners.barR - r
                    y: frameCorners.barT
                }
                // bottom-left inner joint
                InvertedCorner {
                    joint: "topRight"
                    x: frameCorners.barL
                    y: parent.height - frameCorners.barB - r
                }
                // bottom-right inner joint
                InvertedCorner {
                    joint: "topLeft"
                    x: parent.width - frameCorners.barR - r
                    y: parent.height - frameCorners.barB - r
                }
            }

            PanelWindow {
                id: calendarPopup
                screen: screenRoot.modelData
                visible: false
                focusable: true
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                WlrLayershell.namespace: "quickshell-calendar"

                exclusionMode: ExclusionMode.Ignore

                anchors {
                    top: true
                    left: true
                    bottom: true
                    right: true
                }
                margins.top: topBar.height

                property bool closed: true
                property bool cornersVisible: false

                Timer {
                    id: closeTimer
                    interval: Theme.animationSpeed
                    onTriggered: () => {
                        if (calendarPopup.closed)
                            calendarPopup.visible = false;
                    }
                }

                // Staggers the InvertedCorner pieces vs the slide animation:
                // opening -> appear 30ms in, hiding -> disappear 30ms early.
                Timer {
                    id: cornerTimer
                    onTriggered: calendarPopup.cornersVisible = !calendarPopup.closed
                }

                function hidePanel() {
                    calendarPopup.closed = true;
                    cornerTimer.interval = 175;
                    cornerTimer.restart();
                    closeTimer.start();
                }
                function toggle() {
                    calendarPopup.closed = !calendarPopup.closed;
                    if (!closed) {
                        closeTimer.stop();
                        calendarPopup.visible = true;
                        calendar.viewMonth = new Date().getMonth();
                        calendar.viewYear = new Date().getFullYear();
                        cornerTimer.interval = 30;
                        cornerTimer.restart();
                    } else {
                        calendarPopup.hidePanel();
                    }
                }

                // iOS-style dim backdrop
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: calendarPopup.closed ? 0 : 0.3
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationSpeed
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: calendarPopup.hidePanel()
                }

                CalendarPanel {
                    id: calendar
                    x: topBar.width / 2 - width / 2
                    y: !calendarPopup.closed ? 0 : -height - Theme.gap - topBar.height
                    width: 320
                    height: implicitHeight
                    opacity: calendarPopup.closed ? 0 : 1
                    scale: calendarPopup.closed ? 0.94 : 1
                    transformOrigin: Item.Top
                    Behavior on y {
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
                }

                // Inverted corners: seamless joint where popup touches topBar
                InvertedCorner {
                    joint: "bottomLeft"
                    x: calendar.x - r
                    y: calendar.y
                    visible: true
                }
                InvertedCorner {
                    joint: "bottomRight"
                    x: calendar.x + calendar.width
                    y: calendar.y
                    visible: true
                }
            }

            LauncherPanel {
                id: launcherPopup
            }
            PowerPanel {
                id: powerPanel
            }

            ScreenshotPanel {
                id: screenshotPanel
            }
            ScreenshotMenuPanel {
                id: screenshotMenuPanel
            }
            QuickSettingsPanel {
                id: quickSettingsPanel
            }
            TrayPanel {
                id: trayPanel
            }
            SliderPopup {
                id: sliderPopup
            }
            NotificationPanel {
                id: notificationPanel
            }
            EmojiPanel {
                id: emojiPanel
                targetScreen: screenRoot.modelData
            }

            // Only one popup at a time: whenever any popup opens,
            // everything else closes automatically.
            function closeOtherPopups(except) {
                if (calendarPopup !== except && !calendarPopup.closed)
                    calendarPopup.hidePanel();
                if (launcherPopup !== except && !launcherPopup.closed)
                    launcherPopup.hidePanel();
                if (powerPanel !== except && !powerPanel.closed)
                    powerPanel.hidePanel();
                if (screenshotPanel !== except && !screenshotPanel.closed)
                    screenshotPanel.hidePanel();
                if (screenshotMenuPanel !== except && !screenshotMenuPanel.closed)
                    screenshotMenuPanel.hidePanel();
                if (quickSettingsPanel !== except && !quickSettingsPanel.closed)
                    quickSettingsPanel.hidePanel();
                if (trayPanel !== except && !trayPanel.closed)
                    trayPanel.hidePanel();
                if (sliderPopup !== except && !sliderPopup.closed)
                    sliderPopup.hidePanel();
                if (emojiPanel !== except && !emojiPanel.closed)
                    emojiPanel.hidePanel();
            }
            Connections {
                target: calendarPopup
                function onClosedChanged() {
                    if (!calendarPopup.closed)
                        closeOtherPopups(calendarPopup);
                }
            }
            Connections {
                target: launcherPopup
                function onClosedChanged() {
                    if (!launcherPopup.closed)
                        closeOtherPopups(launcherPopup);
                }
            }
            Connections {
                target: powerPanel
                function onClosedChanged() {
                    if (!powerPanel.closed)
                        closeOtherPopups(powerPanel);
                }
            }
            Connections {
                target: screenshotPanel
                function onClosedChanged() {
                    if (!screenshotPanel.closed)
                        closeOtherPopups(screenshotPanel);
                }
            }
            Connections {
                target: screenshotMenuPanel
                function onClosedChanged() {
                    if (!screenshotMenuPanel.closed)
                        closeOtherPopups(screenshotMenuPanel);
                }
            }
            Connections {
                target: quickSettingsPanel
                function onClosedChanged() {
                    if (!quickSettingsPanel.closed)
                        closeOtherPopups(quickSettingsPanel);
                }
            }
            Connections {
                target: trayPanel
                function onClosedChanged() {
                    if (!trayPanel.closed)
                        closeOtherPopups(trayPanel);
                }
            }
            Connections {
                target: sliderPopup
                function onClosedChanged() {
                    if (!sliderPopup.closed)
                        closeOtherPopups(sliderPopup);
                }
            }
            Connections {
                target: emojiPanel
                function onClosedChanged() {
                    if (!emojiPanel.closed)
                        closeOtherPopups(emojiPanel);
                }
            }
        }
    }
}
