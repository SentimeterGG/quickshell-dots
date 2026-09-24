import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import "../bar"
import "../.."

Scope {
    id: root
    property bool closed: true

    property real cpuUsage: 0
    property real memUsage: 0
    property real temperature: 0
    property var _prevCpuIdle: 0
    property var _prevCpuTotal: 0

    property string osName: "Linux"
    property string wmName: "Hyprland"
    property string uptimeStr: "..."
    property string userName: ""
    property string hostName: ""

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var idle = parseInt(p[4]) + parseInt(p[5]);
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0);
                if (root._prevCpuTotal > 0) {
                    var diffIdle = idle - root._prevCpuIdle;
                    var diffTotal = total - root._prevCpuTotal;
                    root.cpuUsage = Math.max(0, Math.min(100, Math.round(100 * (1 - diffIdle / diffTotal))));
                }
                root._prevCpuTotal = total;
                root._prevCpuIdle = idle;
            }
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var parts = data.trim().split(/\s+/);
                var total = parseInt(parts[1]) || 1;
                var used = parseInt(parts[2]) || 0;
                root.memUsage = Math.round(100 * used / total);
            }
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var millideg = parseInt(data.trim());
                root.temperature = Math.min(100, Math.round(millideg / 1000));
            }
        }
    }

    Timer {
        id: statsTimer
        interval: 2000
        running: !root.closed
        repeat: true
        triggeredOnStart: true
        onTriggered: () => {
            cpuProc.running = true;
            memProc.running = true;
            tempProc.running = true;
        }
    }

    Process {
        id: osProc
        command: ["sh", "-c", "grep ^PRETTY_NAME= /etc/os-release | cut -d= -f2 | tr -d '\"'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
                if (v)
                    root.osName = v;
            }
        }
    }

    Process {
        id: wmProc
        command: ["sh", "-c", "echo ${XDG_CURRENT_DESKTOP:-$XDG_SESSION_DESKTOP:-$DESKTOP_SESSION:-Hyprland}"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
                if (v)
                    root.uptimeStr = v;
            }
        }
    }

    // NOTE: one single-line command per process. SplitParser delivers
    // stdout line-by-line, so a multi-line command ("whoami; hostname")
    // would misattribute chunks (hostname overwrote userName).
    Process {
        id: userProc
        command: ["sh", "-c", "whoami"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
                if (v)
                    root.userName = v;
            }
        }
    }

    Process {
        id: hostProc
        command: ["sh", "-c", "hostname"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
                if (v)
                    root.hostName = v;
            }
        }
    }

    property bool bluetoothOn: false
    property string powerProfile: "Powersave"
    property bool darkMode: true
    property bool nightLight: false

    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -qi 'powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                root.bluetoothOn = data.trim() === "on";
            }
        }
    }

    Process {
        id: powerProc
        command: ["sh", "-c", "cpupower frequency-info 2>/dev/null | sed -n 's/.*governor \"\\([^\"]*\\)\".*/\\1/p' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var v = data.trim();
                if (!v)
                    return;
                var low = v.toLowerCase();
                if (low === "performance")
                    root.powerProfile = "Performance";
                else if (low === "powersave")
                    root.powerProfile = "Powersave";
                else
                    root.powerProfile = v.charAt(0).toUpperCase() + v.slice(1);
            }
        }
    }

    Process {
        id: toggleProc
        command: ["true"]
    }

    // Delayed re-poll after a governor change so `cpupower frequency-set`
    // has time to apply before we read the state back. Polling immediately
    // returns the stale governor and would revert the optimistic UI update,
    // making it look like the first click did nothing.
    Timer {
        id: powerVerifyTimer
        interval: 1500
        repeat: false
        onTriggered: powerProc.running = true
    }

    Timer {
        id: sysInfoTimer
        interval: 30000
        running: !root.closed
        repeat: true
        triggeredOnStart: true
        onTriggered: () => {
            uptimeProc.running = true;
            btProc.running = true;
            powerProc.running = true;
        }
    }

    // Static info never changes at runtime — fetch once, not every 30s.
    Component.onCompleted: {
        osProc.running = true;
        wmProc.running = true;
        userProc.running = true;
        hostProc.running = true;
    }

    onClosedChanged: {
        if (!closed) {
            // Refresh dynamic state immediately on open for lowest latency.
            uptimeProc.running = true;
            btProc.running = true;
            powerProc.running = true;
            cpuProc.running = true;
            memProc.running = true;
            tempProc.running = true;
        }
    }

    property var sinkLinkTracker: PwNodeLinkTracker {
        node: Pipewire.defaultAudioSink
    }

    Timer {
        id: closeTimer
        interval: Theme.animationSpeed
        onTriggered: () => {
            if (root.closed)
                quickSettings.visible = false;
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
            quickSettings.visible = true;
        } else {
            hidePanel();
        }
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        id: quickSettings
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
            right: true
            bottom: true
        }
        margins.top: topBar.height
        // iOS-style dim backdrop — soft fade instead of a hard cut
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
        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }

        // Dropdown card — iOS app-open feel:
        // drops from top with a long soft landing (OutExpo) + scale/fade
        Rectangle {
            id: launcherBox
            width: 850 - Theme.gap
            height: 500
            bottomLeftRadius: 16
            color: Theme.background
            y: root.closed ? -height - Theme.gap : 0
            x: parent.width - width - Theme.gap
            opacity: root.closed ? 0 : 1
            scale: root.closed ? 0.94 : 1
            transformOrigin: Item.TopRight
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
            RowLayout {
                anchors.fill: parent
                spacing: Theme.gap - 4
                anchors.margins: Theme.gap - 4
                Rectangle {
                    border.width: 1
                    border.color: Theme.border
                    radius: Theme.radius - 6
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surface
                    ColumnLayout {
                        id: justifyBetweenVertical
                        anchors.fill: parent
                        anchors.margins: Theme.gap - 4
                        spacing: Theme.gap - 4
                        ColumnLayout {
                            id: topPart
                            Layout.fillWidth: true
                            spacing: Theme.gap - 6
                            Text {
                                font: Theme.bodyFont
                                text: "Quick Control"
                                color: Theme.text
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Theme.gap - 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 65
                                    spacing: Theme.gap - 6
                                    // --- Internet card ---
                                    ToggleCard {
                                        id: internetCard

                                        readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
                                        readonly property var ethDev: Networking.devices.values.find(d => d.type === DeviceType.Wired)
                                        readonly property var activeNet: wifiDev?.networks.values.find(n => n.connected)
                                        readonly property bool isOnline: (ethDev?.connected ?? false) || (wifiDev?.connected ?? false)

                                        title: "Internet"
                                        subtitle: ethDev?.connected ? "Wired" : (activeNet?.ssid ?? activeNet?.name ?? "Offline")
                                        active: isOnline
                                        icon: {
                                            if (ethDev?.connected)
                                                return "󰌘";
                                            if (!wifiDev || !wifiDev.connected)
                                                return "󰤭";
                                            if (!activeNet)
                                                return "󰤭";
                                            var s = activeNet.signalStrength;
                                            if (s > 0.80)
                                                return "󰤨";
                                            if (s > 0.60)
                                                return "󰤥";
                                            if (s > 0.30)
                                                return "󰤢";
                                            return "󰤟";
                                        }
                                        onToggled: internetCard.active = !internetCard.active
                                    }

                                    // --- Bluetooth card ---
                                    ToggleCard {
                                        id: btCard
                                        title: "Bluetooth"
                                        subtitle: root.bluetoothOn ? "On" : "Off"
                                        active: root.bluetoothOn
                                        icon: btCard.active ? "󰂯" : "󰂲"
                                        onToggled: () => {
                                            btCard.active = !btCard.active;
                                            toggleProc.command = ["sh", "-c", btCard.active ? "bluetoothctl power on" : "bluetoothctl power off"];
                                            toggleProc.running = true;
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 65
                                    spacing: Theme.gap - 6
                                    // --- Power mode card ---
                                    ToggleCard {
                                        id: powerCard
                                        title: "Power"
                                        subtitle: root.powerProfile
                                        active: root.powerProfile === "Performance"
                                        icon: "󰓅"
                                        onToggled: () => {
                                            var next = root.powerProfile === "Performance" ? "powersave" : "performance";
                                            toggleProc.command = ["sh", "-c", "sudo cpupower frequency-set -g " + next];
                                            toggleProc.running = true;
                                            root.powerProfile = next === "performance" ? "Performance" : "Powersave";
                                            powerVerifyTimer.restart();
                                        }
                                    }

                                    // --- Airplane mode card ---
                                    ToggleCard {
                                        id: airplaneCard
                                        title: "Airplane"
                                        subtitle: airplaneCard.active ? "On" : "Off"
                                        icon: "󰀝"
                                        active: false
                                        onToggled: () => {
                                            airplaneCard.active = !airplaneCard.active;
                                            toggleProc.command = ["sh", "-c", airplaneCard.active ? "nmcli radio wifi off; bluetoothctl power off" : "nmcli radio wifi on; bluetoothctl power on"];
                                            toggleProc.running = true;
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 65
                                    spacing: Theme.gap - 6
                                    ToggleCard {
                                        id: darkModeCard
                                        title: "Dark Mode"
                                        subtitle: darkModeCard.active ? "On" : "Off"
                                        icon: darkModeCard.active ? "󰌵" : "󰏛"
                                        active: root.darkMode
                                        onToggled: () => {
                                            root.darkMode = !root.darkMode;
                                            darkModeCard.active = root.darkMode;
                                        }
                                    }

                                    ToggleCard {
                                        id: nightLightCard
                                        title: "Night Light"
                                        subtitle: nightLightCard.active ? "On" : "Off"
                                        icon: "󰖔"
                                        active: root.nightLight
                                        onToggled: () => {
                                            root.nightLight = !root.nightLight;
                                            nightLightCard.active = root.nightLight;
                                        }
                                    }
                                }
                                // --- Profile card ---
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 150
                                    radius: Theme.radius - 8
                                    color: Theme.background
                                    border.width: 1
                                    border.color: Theme.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        anchors.leftMargin: 30
                                        spacing: 32
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.preferredHeight: 100
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 100
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: Theme.border
                                            clip: true
                                            Text {
                                                anchors.centerIn: parent
                                                text: ""
                                                font.family: Theme.iconFont.family
                                                font.pointSize: 16
                                                color: Theme.textSecondary
                                            }
                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + Quickshell.env("HOME") + "/.face"
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready
                                                // clip:true on the parent Rectangle is
                                                // rectangular and ignores radius, so mask
                                                // the image itself into the circle.
                                                layer.enabled: visible
                                                layer.effect: OpacityMask {
                                                    maskSource: Rectangle {
                                                        width: 56
                                                        height: 56
                                                        radius: 28
                                                    }
                                                }
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 4
                                            Text {
                                                text: "Sentimers"
                                                font: Theme.bodyFont
                                                color: Theme.text
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "󰣇"
                                                    font.family: Theme.iconFont.family
                                                    font.pointSize: 11
                                                    color: Theme.textSecondary
                                                }
                                                Text {
                                                    text: root.osName
                                                    font: Theme.bodyFont
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true
                                                Text {
                                                    text: ""
                                                    font.family: Theme.iconFont.family
                                                    font.pointSize: 11
                                                    color: Theme.textSecondary
                                                }
                                                Text {
                                                    text: root.wmName
                                                    font: Theme.bodyFont
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true
                                                Text {
                                                    text: ""
                                                    font.family: Theme.iconFont.family
                                                    font.pointSize: 11
                                                    color: Theme.textSecondary
                                                }
                                                Text {
                                                    text: root.uptimeStr
                                                    font: Theme.bodyFont
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            id: bottomPart
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                            spacing: 0
                            Rectangle {
                                id: batteryBox
                                Layout.preferredWidth: batteryRow.implicitWidth + 24
                                Layout.preferredHeight: batteryRow.implicitHeight + 18
                                radius: Theme.radius - 8
                                color: Theme.background
                                border.width: 1
                                border.color: Theme.border

                                readonly property var battery: UPower.displayDevice
                                readonly property bool hasBattery: battery && battery.ready && battery.isPresent
                                readonly property real frac: {
                                    if (!hasBattery)
                                        return 0;
                                    var raw = battery.percentage;
                                    return raw > 1 ? raw / 100 : raw;
                                }
                                readonly property int pct: Math.round(frac * 100)
                                readonly property string battIcon: {
                                    if (!hasBattery)
                                        return "";
                                    if (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
                                        return "󱐋";
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
                                readonly property string battLabel: {
                                    if (!hasBattery)
                                        return "No battery";
                                    if (battery.state === UPowerDeviceState.Charging)
                                        return pct + "% • Charging";
                                    if (battery.state === UPowerDeviceState.FullyCharged)
                                        return pct + "% • Full";
                                    return pct + "%";
                                }

                                RowLayout {
                                    id: batteryRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: batteryBox.battIcon
                                        font.family: Theme.iconFont.family
                                        font.pointSize: (batteryBox.hasBattery && (batteryBox.battery.state === UPowerDeviceState.Charging || batteryBox.battery.state === UPowerDeviceState.PendingCharge)) ? 16 : 18
                                        color: Theme.text
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: batteryBox.battLabel
                                        font: Theme.bodyFont
                                        color: Theme.textSecondary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    spacing: Theme.gap - 4
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        border.width: 1
                        border.color: Theme.border
                        radius: Theme.radius - 6
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        color: Theme.surface
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.gap - 4
                            spacing: Theme.gap
                            Text {
                                font: Theme.bodyFont
                                text: "Perfomance Monitor"
                                color: Theme.text
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }
                            ColumnLayout {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                spacing: Theme.gap - 6
                                Repeater {
                                    model: 3
                                    RowLayout {
                                        readonly property var info: [
                                            {
                                                name: "CPU",
                                                color: "#97002c",
                                                unit: "%"
                                            },
                                            {
                                                name: "RAM",
                                                color: "#1b3e82",
                                                unit: "%"
                                            },
                                            {
                                                name: "Temp",
                                                color: "#d27c4b",
                                                unit: "°C"
                                            },
                                        ][index]
                                        readonly property real pct: [root.cpuUsage, root.memUsage, root.temperature][index]

                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        spacing: Theme.gap - 6
                                        Text {
                                            Layout.preferredWidth: 40
                                            font: Theme.bodyFont
                                            text: info.name
                                            color: Theme.text
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Theme.radius - 10
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: Theme.border
                                            clip: true
                                            Rectangle {
                                                width: parent.width * pct / 100
                                                height: parent.height
                                                radius: Theme.radius - 10
                                                color: info.color
                                            }
                                        }
                                        Text {
                                            Layout.preferredWidth: 32
                                            font: Theme.bodyFont
                                            text: Math.round(pct) + info.unit
                                            color: Theme.text
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        border.width: 1
                        border.color: Theme.border
                        radius: Theme.radius - 6
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surface
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.gap - 4
                            spacing: Theme.gap
                            Text {
                                font: Theme.bodyFont
                                text: "Volume Mixer"
                                color: Theme.text
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }
                            //Make it uses listview to make it scrollable
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignTop
                                spacing: Theme.gap - 6

                                //Keep this becuase this is system
                                RowLayout {
                                    Layout.fillWidth: true
                                    height: 30
                                    spacing: Theme.gap - 2
                                    PwObjectTracker {
                                        objects: [Pipewire.defaultAudioSink]
                                    }
                                    Text {
                                        text: Pipewire.defaultAudioSink?.audio?.muted ? "󰝟" : "󰕾"
                                        font.family: Theme.iconFont.family
                                        color: Theme.text
                                        font.pointSize: 14
                                    }
                                    Slider {
                                        id: sysVolumeSlider
                                        Layout.fillWidth: true
                                        from: 0.0
                                        to: 1.0
                                        value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                                        onMoved: () => {
                                            if (Pipewire.defaultAudioSink?.audio)
                                                Pipewire.defaultAudioSink.audio.volume = value;
                                        }
                                        handle: Rectangle {
                                            width: 6
                                            height: 34
                                            radius: 10
                                            y: -6
                                            x: sysVolumeSlider.leftPadding + sysVolumeSlider.visualPosition * sysVolumeSlider.availableWidth - 4
                                            color: "#888"
                                            border.color: Theme.surface
                                        }

                                        background: Rectangle {
                                            x: sysVolumeSlider.leftPadding
                                            y: sysVolumeSlider.topPadding + sysVolumeSlider.availableHeight / 2 - height / 2
                                            implicitWidth: 200
                                            implicitHeight: 22
                                            width: sysVolumeSlider.availableWidth
                                            height: implicitHeight
                                            radius: Theme.radius - 10
                                            color: "#00000000"
                                            border.width: 1
                                            border.color: Theme.border

                                            // Progress bar visual
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: sysVolumeSlider.visualPosition * parent.width
                                                color: Theme.muted
                                                radius: Theme.radius - 10
                                            }
                                        }
                                    }
                                    Text {
                                        text: Math.round(sysVolumeSlider.value * 100) + "%"
                                        color: Theme.text
                                        font: Theme.bodyFont
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Theme.border
                                }

                                //application Volume
                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: Theme.gap - 6
                                    visible: !root.closed
                                    activeFocusOnTab: false

                                    model: root.closed ? null : root.sinkLinkTracker.linkGroups

                                    delegate: RowLayout {
                                        width: ListView.view.width
                                        height: 30
                                        spacing: Theme.gap - 2
                                        PwObjectTracker {
                                            objects: [modelData.source]
                                        }
                                        Text {
                                            text: modelData.source.description || modelData.source.name || "Unknown"
                                            color: Theme.text
                                            font: Theme.bodyFont
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: 80
                                        }
                                        Slider {
                                            id: applicationSlider
                                            Layout.fillWidth: true
                                            from: 0.0
                                            to: 1.0
                                            value: modelData.source.audio?.volume ?? 0
                                            onMoved: () => {
                                                if (modelData.source.audio)
                                                    modelData.source.audio.volume = value;
                                            }
                                            handle: Rectangle {
                                                width: 6
                                                height: 34
                                                radius: 10
                                                y: -6
                                                x: applicationSlider.leftPadding + applicationSlider.visualPosition * applicationSlider.availableWidth - 4
                                                color: "#888"
                                                border.color: Theme.surface
                                            }
                                            background: Rectangle {
                                                x: applicationSlider.leftPadding
                                                y: applicationSlider.topPadding + applicationSlider.availableHeight / 2 - height / 2
                                                implicitWidth: 200
                                                implicitHeight: 22
                                                width: applicationSlider.availableWidth
                                                height: implicitHeight
                                                radius: Theme.gap - 10
                                                color: "#00000000"
                                                border.width: 1
                                                border.color: Theme.border

                                                // Progress bar visual
                                                Rectangle {
                                                    width: applicationSlider.visualPosition * parent.width
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    color: Theme.muted
                                                    radius: Theme.radius - 10
                                                }
                                            }
                                        }
                                        Text {
                                            text: Math.round(applicationSlider.value * 100) + "%"
                                            color: Theme.text
                                            font: Theme.bodyFont
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Inverted corners: seamless joint where launcherBox touches topBar
            InvertedCorner {
                joint: "bottomLeft"
                x: 0 - r
                y: 0
                opacity: launcherBox.opacity
            }
            InvertedCorner {
                joint: "bottomLeft"
                x: launcherBox.width - r
                y: launcherBox.height
                opacity: launcherBox.opacity
            }
        }
    }
}
