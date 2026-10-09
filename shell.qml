//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import "components/bar"
import "components/popup"

// qmllint disable uncreatable-type
ShellRoot {
    id: shellRoot

    // ── GLOBAL POPUPS (one instance total, built lazily on first open) ──
    // Bars stay per-screen in the Variants below; everything else lives
    // here once, so extra monitors cost ~nothing and there is a single
    // NotificationServer instead of one daemon per screen.
    Loader {
        id: launcherLoader
        active: false
        sourceComponent: LauncherPanel {}
    }
    Loader {
        id: powerLoader
        active: false
        sourceComponent: PowerPanel {}
    }
    Loader {
        id: screenshotLoader
        active: false
        sourceComponent: ScreenshotPanel {}
    }
    Loader {
        id: screenshotMenuLoader
        active: false
        sourceComponent: ScreenshotMenuPanel {}
    }
    Loader {
        id: quickSettingsLoader
        active: false
        sourceComponent: QuickSettingsPanel {}
    }
    Loader {
        id: trayLoader
        active: false
        sourceComponent: TrayPanel {}
    }
    Loader {
        id: sliderLoader
        active: false
        sourceComponent: SliderPopup {}
    }
    Loader {
        id: notificationLoader
        active: false
        sourceComponent: NotificationPanel {}
    }

    // IPC entry points live here so they work before first open.
    // (The matching handlers were removed from the popup files to
    // avoid double-toggling once the component loads.)
    IpcHandler {
        target: "launcher"
        function toggle() {
            shellRoot.toggleLauncher();
        }
    }
    IpcHandler {
        target: "screenshot"
        function toggle() {
            shellRoot.toggleScreenshot();
        }
    }
    IpcHandler {
        target: "screenshot-menu"
        function toggle() {
            shellRoot.toggleScreenshotMenu();
        }
    }

    function openPopup(loader) {
        if (!loader.active)
            loader.active = true;
        return loader.item;
    }
    function toggleLauncher() {
        openPopup(launcherLoader).toggle();
    }
    function togglePower() {
        openPopup(powerLoader).toggle();
    }
    function toggleScreenshot() {
        openPopup(screenshotLoader).toggle();
    }
    function toggleScreenshotMenu() {
        openPopup(screenshotMenuLoader).toggle();
    }
    function toggleQuickSettings() {
        openPopup(quickSettingsLoader).toggle();
    }
    function toggleTray() {
        openPopup(trayLoader).toggle();
    }
    function toggleNotifications() {
        openPopup(notificationLoader).toggle();
    }
    function toggleSlider() {
        const p = openPopup(sliderLoader);
        if (p.closed)
            p.show();
        else
            p.hidePanel();
    }

    // Only one popup at a time, across all screens. Closing the others
    // bumps popupEpoch so each screen drops its own calendar/emoji too.
    property int popupEpoch: 0
    function closeOtherPopups(except) {
        const loaders = [launcherLoader, powerLoader, screenshotLoader, screenshotMenuLoader, quickSettingsLoader, trayLoader, sliderLoader, notificationLoader];
        for (const l of loaders) {
            const p = l.active ? l.item : null;
            if (p && p !== except && !p.closed)
                p.hidePanel();
        }
        popupEpoch++;
    }

    // Whenever a global popup opens, close the rest.
    Connections {
        target: launcherLoader.active ? launcherLoader.item : null
        function onClosedChanged() {
            if (!launcherLoader.item.closed)
                shellRoot.closeOtherPopups(launcherLoader.item);
        }
    }
    Connections {
        target: powerLoader.active ? powerLoader.item : null
        function onClosedChanged() {
            if (!powerLoader.item.closed)
                shellRoot.closeOtherPopups(powerLoader.item);
        }
    }
    Connections {
        target: screenshotLoader.active ? screenshotLoader.item : null
        function onClosedChanged() {
            if (!screenshotLoader.item.closed)
                shellRoot.closeOtherPopups(screenshotLoader.item);
        }
    }
    Connections {
        target: screenshotMenuLoader.active ? screenshotMenuLoader.item : null
        function onClosedChanged() {
            if (!screenshotMenuLoader.item.closed)
                shellRoot.closeOtherPopups(screenshotMenuLoader.item);
        }
    }
    Connections {
        target: quickSettingsLoader.active ? quickSettingsLoader.item : null
        function onClosedChanged() {
            if (!quickSettingsLoader.item.closed)
                shellRoot.closeOtherPopups(quickSettingsLoader.item);
        }
    }
    Connections {
        target: trayLoader.active ? trayLoader.item : null
        function onClosedChanged() {
            if (!trayLoader.item.closed)
                shellRoot.closeOtherPopups(trayLoader.item);
        }
    }
    Connections {
        target: sliderLoader.active ? sliderLoader.item : null
        function onClosedChanged() {
            if (!sliderLoader.item.closed)
                shellRoot.closeOtherPopups(sliderLoader.item);
        }
    }
    Connections {
        target: notificationLoader.active ? notificationLoader.item : null
        function onClosedChanged() {
            if (!notificationLoader.item.closed)
                shellRoot.closeOtherPopups(notificationLoader.item);
        }
    }

    // ── PER-SCREEN BARS ──
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                id: screenRoot
                required property var modelData
                // Guards this screen's epoch watcher while it is the opener.
                property bool epochGuard: false

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
                            onClicked: shellRoot.toggleLauncher()

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
                            onClicked: shellRoot.toggleTray()
                            FlexboxLayout {
                                justifyContent: FlexboxLayout.JustifySpaceBetween
                                alignItems: FlexboxLayout.AlignCenter
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                Text {
                                    font: Theme.iconFont
                                    text: (trayLoader.active && !trayLoader.item.closed) ? "" : ""
                                    color: Theme.text
                                }
                            }
                        }
                        RoundButton {
                            onClicked: shellRoot.toggleQuickSettings()
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
                            onClicked: shellRoot.togglePower()
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
                    onClicked: shellRoot.toggleSlider()
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

            EmojiPanel {
                id: emojiPanel
                targetScreen: screenRoot.modelData
            }

            // This screen's own popups yield whenever anything opens anywhere
            // (shellRoot.popupEpoch bumps in closeOtherPopups).
            Connections {
                target: shellRoot
                function onPopupEpochChanged() {
                    if (screenRoot.epochGuard)
                        return;
                    if (!calendarPopup.closed)
                        calendarPopup.hidePanel();
                    if (!emojiPanel.closed)
                        emojiPanel.hidePanel();
                }
            }
            Connections {
                target: calendarPopup
                function onClosedChanged() {
                    if (!calendarPopup.closed) {
                        screenRoot.epochGuard = true;
                        shellRoot.closeOtherPopups(null);
                        screenRoot.epochGuard = false;
                    }
                }
            }
            Connections {
                target: emojiPanel
                function onClosedChanged() {
                    if (!emojiPanel.closed) {
                        screenRoot.epochGuard = true;
                        shellRoot.closeOtherPopups(null);
                        screenRoot.epochGuard = false;
                    }
                }
            }
        }
    }
}}
