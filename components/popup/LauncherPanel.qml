import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../bar"
import "../.."
import "../../services"

Scope {
    id: root

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.toggle();
        }
    }

    property int selectedIndex: 0
    property bool closed: true

    ScriptModel {
        id: filteredApps
        objectProp: "id"
        values: {
            const all = [...DesktopEntries.applications.values];
            const q = searchInput.text.trim().toLowerCase();
            if (q === "")
                return all.sort((a, b) => a.name.localeCompare(b.name));
            return all.filter(d => (d.name && d.name.toLowerCase().includes(q)) || (d.genericName && d.genericName.toLowerCase().includes(q)) || (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) || (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))).sort((a, b) => {
                const an = a.name.toLowerCase();
                const bn = b.name.toLowerCase();
                const aStarts = an.startsWith(q);
                const bStarts = bn.startsWith(q);
                if (aStarts && !bStarts)
                    return -1;
                if (!aStarts && bStarts)
                    return 1;
                return an.localeCompare(bn);
            });
        }
    }

    function launchApp(entry) {
        entry.execute();
        root.toggle();
    }

    Timer {
        id: closeTimer
        // Must cover the full close animation (iOS-spring duration below)
        interval: Theme.animationSpeed
        onTriggered: () => {
            if (root.closed)
                launcherPanel.visible = false;
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
            launcherPanel.visible = true;
            searchInput.text = "";
            selectedIndex = -1;
            searchInput.forceActiveFocus();
        } else {
            hidePanel();
        }
    }
    PanelWindow {
        id: launcherPanel
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

        // Centered launcher box — iOS app-open feel:
        // fast start, long soft landing (OutExpo) + subtle scale/fade
        Rectangle {
            id: launcherBox
            width: 704 - Theme.gap
            height: 480
            bottomRightRadius: 16
            color: Theme.background
            y: root.closed ? -height - Theme.gap : 0
            x: Theme.gap
            opacity: root.closed ? 0 : 1
            scale: root.closed ? 0.94 : 1
            transformOrigin: Item.TopLeft
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
                // Keep fade slightly quicker than slide so it feels
                // fluid on open, but still visible during close.
                // Must stay animated — without this, opacity snaps
                // to 0 instantly and the x slide is invisible.
                NumberAnimation {
                    duration: Theme.animationSpeed
                    easing.type: Easing.OutExpo
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.gap - 4
                spacing: 12
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: 300
                    spacing: 12

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: Theme.radius - 6
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.text
                                font: Theme.bodyFont
                                clip: true
                                focus: true
                                Accessible.role: Accessible.EditableText
                                Accessible.name: "Search applications"

                                Text {
                                    anchors.fill: parent
                                    text: "Type to search..."
                                    color: Theme.muted
                                    font: parent.font
                                    visible: !parent.text
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onTextChanged: root.selectedIndex = text === "" ? -1 : 0

                                Keys.onEscapePressed: root.toggle()

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Down) {
                                        event.accepted = true;
                                        root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                                        resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                    } else if (event.key === Qt.Key_Up) {
                                        event.accepted = true;
                                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                                        resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        event.accepted = true;
                                        if (root.selectedIndex >= 0) {
                                            const entry = filteredApps.values[root.selectedIndex];
                                            if (entry)
                                                root.launchApp(entry);
                                        }
                                    } else if (event.key === Qt.Key_Tab) {
                                        event.accepted = true;
                                        root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                                        resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                    }
                                }
                            }
                        }
                    }

                    // Results count
                    Text {
                        text: resultsList.count + " application" + (resultsList.count !== 1 ? "s" : "")
                        color: Theme.muted
                        font: Theme.bodyFont
                    }

                    // App list
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: filteredApps
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        // Single source of truth: root.selectedIndex.
                        // Never assign resultsList.currentIndex imperatively or this binding breaks.
                        currentIndex: root.selectedIndex

                        onCountChanged: {
                            if (count === 0) {
                                root.selectedIndex = -1;
                            } else if (searchInput.text !== "" && (root.selectedIndex < 0 || root.selectedIndex >= count)) {
                                root.selectedIndex = 0;
                                positionViewAtBeginning();
                            }
                        }

                        // NOTE: no ListView `highlight:` component on purpose.
                        // The built-in highlight animates toward currentIndex and lags
                        // behind during fast filtering, which is exactly the
                        // "highlight on FireAlpaca, white text on Flatseal" split.
                        // Selection background is drawn in the delegate instead,
                        // using the same condition as the text color.

                        delegate: Rectangle {
                            id: delegateRoot
                            required property var modelData
                            required property int index

                            Accessible.role: Accessible.Button
                            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

                            width: resultsList.width
                            height: 44
                            radius: 8
                            color: root.selectedIndex === delegateRoot.index ? Theme.bgSelected : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animationSpeed / 2
                                }
                            }

                            Rectangle {
                                width: 3
                                height: 24
                                radius: 2
                                color: Theme.accent
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.selectedIndex === delegateRoot.index
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // App icon
                                Item {
                                    width: 28
                                    height: 28
                                    Layout.alignment: Qt.AlignVCenter

                                    IconImage {
                                        anchors.fill: parent
                                        source: Quickshell.iconPath(delegateRoot.modelData.icon ?? "", true)
                                        visible: (delegateRoot.modelData.icon ?? "") !== ""
                                    }

                                    // Fallback icon
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Theme.muted
                                        font: Theme.bodyFont
                                        visible: (delegateRoot.modelData.icon ?? "") === ""
                                    }
                                }

                                // App info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    Text {
                                        text: delegateRoot.modelData.name ?? ""
                                        color: root.selectedIndex === delegateRoot.index ? Theme.text : Theme.muted
                                        font.family: Theme.bodyFont.family
                                        font.pointSize: Theme.bodyFont.pointSize
                                        font.bold: root.selectedIndex === delegateRoot.index
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchApp(delegateRoot.modelData)
                                onEntered: root.selectedIndex = delegateRoot.index
                            }
                        }

                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            text: "  No applications found"
                            color: Theme.muted
                            font.pixelSize: 14
                            font.family: Theme.bodyFont.family
                            visible: resultsList.count === 0 && searchInput.text !== ""
                        }
                    }

                    // Footer hint
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Row {
                            spacing: 4
                            Rectangle {
                                width: hintUp.width + 8
                                height: 18
                                radius: 4
                                color: Theme.surface
                                Text {
                                    id: hintUp
                                    anchors.centerIn: parent
                                    text: "↑↓"
                                    color: Theme.muted
                                    font.pixelSize: 10
                                    font.family: Theme.bodyFont.family
                                }
                            }
                            Text {
                                text: "navigate"
                                color: Theme.muted
                                font.pixelSize: 10
                                font.family: Theme.bodyFont.family
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4
                            Rectangle {
                                width: hintEnter.width + 8
                                height: 18
                                radius: 4
                                color: Theme.surface
                                Text {
                                    id: hintEnter
                                    anchors.centerIn: parent
                                    text: "⏎"
                                    color: Theme.muted
                                    font.pixelSize: 10
                                    font.family: Theme.bodyFont.family
                                }
                            }
                            Text {
                                text: "launch"
                                color: Theme.muted
                                font.pixelSize: 10
                                font.family: Theme.bodyFont.family
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4
                            Rectangle {
                                width: hintEsc.width + 8
                                height: 18
                                radius: 4
                                color: Theme.surface
                                Text {
                                    id: hintEsc
                                    anchors.centerIn: parent
                                    text: "esc"
                                    color: Theme.muted
                                    font.pixelSize: 10
                                    font.family: Theme.bodyFont.family
                                }
                            }
                            Text {
                                text: "close"
                                color: Theme.muted
                                font.pixelSize: 10
                                font.family: Theme.bodyFont.family
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius - 8
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 14
                            Text {
                                font: Theme.bodyFont
                                text: "Pinned"
                                color: Theme.text
                            }
                            GridLayout {
                                id: pinnedApps
                                rows: 4
                                columns: 3
                                Layout.fillWidth: true
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        {
                                            id: "firefox",
                                            name: "Firefox"
                                        },
                                        {
                                            id: "foot",
                                            name: "Terminal"
                                        },
                                        {
                                            id: "sober",
                                            name: "Sober"
                                        },
                                        {
                                            id: "osu-lazer",
                                            name: "Osu"
                                        },
                                        {
                                            id: "qtfm",
                                            name: "QtFm"
                                        },
                                        {
                                            id: "nvim",
                                            name: "Neovim"
                                        },
                                    ]
                                    Rectangle {
                                        id: pinDelegate
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: width
                                        radius: 8
                                        color: pinMouse.containsMouse ? Theme.bgSelected : Theme.surface
                                        border.width: pinMouse.containsMouse ? 1 : 0
                                        border.color: Theme.border
                                        Behavior on color {
                                            ColorAnimation {
                                                easing: Easing.OutCubic
                                                duration: Theme.animationSpeed
                                            }
                                        }

                                        property var entry: {
                                            const apps = [...DesktopEntries.applications.values];

                                            // 1. Try to find an exact match for the ID (e.g., "foot" or "foot.desktop")
                                            let match = apps.find(app => {
                                                const appId = app.id.toLowerCase();
                                                const targetId = modelData.id.toLowerCase();
                                                return appId === targetId || appId === targetId + ".desktop";
                                            });

                                            // 2. Fallback to a looser include match ONLY if an exact match wasn't found
                                            if (!match) {
                                                match = apps.find(app => app.id.toLowerCase().includes(modelData.id.toLowerCase()));
                                            }

                                            return match || null;
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 12
                                            // Ensure the internal column stretches nicely
                                            width: parent.width - 16

                                            IconImage {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                // Fallback to a blank string if entry or icon isn't found
                                                source: (pinDelegate.entry && pinDelegate.entry.icon) ? Quickshell.iconPath(pinDelegate.entry.icon, true) : ""
                                                visible: source !== ""
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                // If the system entry isn't found, it falls back to your hardcoded name ("Firefox", "Terminal", etc.)
                                                text: pinDelegate.entry ? (pinDelegate.entry.name ?? modelData.name) : modelData.name
                                                color: Theme.text
                                                font.family: Theme.bodyFont.family
                                                font.pointSize: Theme.bodyFont.pointSize
                                                elide: Text.ElideRight // Prevents long names from breaking layout
                                            }
                                        }

                                        MouseArea {
                                            id: pinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (pinDelegate.entry) {
                                                    root.launchApp(pinDelegate.entry);
                                                } else {
                                                    console.log("Could not launch: " + modelData.name + " (Entry not found)");
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                id: mediaControlRect
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radius - 6
                                color: Theme.border
                                border.width: 1
                                border.color: Theme.muted

                                // --- Image Catcher Logic ---
                                // This property holds the actual URL we will feed to the Image
                                property string _artUrl: ""

                                // The Binding "catches" the URL when it's valid.
                                // When it becomes "", the `when` condition becomes false.
                                // Because restoreMode is RestoreNone, it KEEPS the last valid URL instead of clearing!
                                Binding on _artUrl {
                                    value: Players.active ? Players.active.trackArtUrl : ""
                                    when: Players.active !== null && Players.active.trackArtUrl !== ""
                                    restoreMode: Binding.RestoreNone
                                }

                                readonly property bool _artReady: backgroundImage.status === Image.Ready

                                Image {
                                    id: backgroundImage
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    autoTransform: true
                                    visible: false
                                    cache: false // MPRIS often reuses URLs with different content
                                    source: mediaControlRect._artUrl // Bind to our "caught" URL
                                }

                                Rectangle {
                                    id: maskStencil
                                    anchors.fill: parent
                                    radius: mediaControlRect.radius
                                    color: "black"
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: backgroundImage
                                    maskSource: maskStencil
                                    cached: false
                                    visible: mediaControlRect._artReady
                                    opacity: mediaControlRect._artReady ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.animationSpeed / 2
                                            easing: Easing.OutCubic
                                        }
                                    }
                                }

                                // Dark overlay
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#000000"
                                    radius: parent.radius
                                    border.width: 1
                                    border.color: Theme.border
                                    opacity: 0.6
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: Players.active?.trackTitle ?? "No Media Playing"
                                            color: mediaControlRect._artReady ? "#FFFFFF" : Theme.text
                                            font.bold: true
                                            font.pointSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: Players.active?.trackArtist ?? "Unknown Artist"
                                            color: mediaControlRect._artReady ? "#FFFFFF" : Theme.text
                                            opacity: 0.7
                                            font.pointSize: 9
                                            elide: Text.ElideRight
                                            Layout.bottomMargin: 12
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        spacing: Theme.gap - 6

                                        FrameAnimation {
                                            id: positionPoker
                                            running: Players.active !== null && Players.active.playbackState === MprisPlaybackState.Playing && Players.active.canSeek
                                            onTriggered: {
                                                if (Players.active)
                                                    Players.active.positionChanged();
                                            }
                                        }

                                        Slider {
                                            id: musicSlider
                                            Layout.fillWidth: true
                                            enabled: Players.active?.canSeek ?? false

                                            from: 0
                                            to: 1

                                            value: {
                                                if (Players.active === null || !Players.active.canSeek)
                                                    return 0;
                                                var len = Players.active.length;
                                                if (len <= 0)
                                                    return 0;
                                                var ratio = Players.active.position / len;
                                                return Math.min(1, Math.max(0, ratio));
                                            }
                                            onMoved: {
                                                if (Players.active && Players.active.canSeek) {
                                                    Players.active.position = value * Players.active.length;
                                                }
                                            }

                                            spacing: Theme.gap - 6

                                            handle: Rectangle {
                                                radius: 100
                                                width: 10
                                                height: width
                                                x: musicSlider.leftPadding + musicSlider.visualPosition * (musicSlider.availableWidth - width)
                                                y: musicSlider.topPadding + musicSlider.availableHeight / 2 - height / 2
                                            }

                                            background: Rectangle {
                                                x: musicSlider.leftPadding
                                                y: musicSlider.topPadding + musicSlider.availableHeight / 2 - height / 2
                                                implicitWidth: 200
                                                implicitHeight: 6
                                                width: musicSlider.availableWidth
                                                height: implicitHeight
                                                radius: Math.max(0, Theme.radius - 10)
                                                color: "#00000000"
                                                border.width: 1
                                                border.color: Theme.border

                                                Rectangle {
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: musicSlider.visualPosition * parent.width
                                                    color: Theme.text
                                                    radius: parent.radius
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                                            spacing: 7

                                            RoundButton {
                                                text: "⏮"
                                                enabled: Players.active?.canGoPrevious ?? false
                                                onClicked: Players.active?.previous()
                                                Layout.preferredWidth: height
                                                palette.buttonText: "white"

                                                background: Rectangle {
                                                    color: Theme.muted
                                                    opacity: parent.pressed ? 1 : 0
                                                    radius: 100
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: Theme.animationSpeed / 2
                                                            easing: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }

                                            RoundButton {
                                                id: playButton
                                                text: Players.active?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                                                enabled: Players.active?.canTogglePlaying ?? false
                                                onClicked: Players.active?.togglePlaying()
                                                palette.buttonText: "#000"
                                                Layout.preferredWidth: height

                                                background: Rectangle {
                                                    color: "#fff"
                                                    radius: 100
                                                }
                                            }

                                            RoundButton {
                                                text: "⏭"
                                                enabled: Players.active?.canGoNext ?? false
                                                onClicked: Players.active?.next()
                                                Layout.preferredWidth: height
                                                palette.buttonText: "white"
                                                background: Rectangle {
                                                    color: Theme.muted
                                                    opacity: parent.pressed ? 1 : 0
                                                    radius: 100
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: Theme.animationSpeed / 2
                                                            easing: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }
                                        }
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
            joint: "bottomRight"
            x: launcherBox.width + launcherBox.x
            y: launcherBox.y
            opacity: launcherBox.opacity
        }
        InvertedCorner {
            joint: "bottomRight"
            x: launcherBox.x
            y: launcherBox.height + launcherBox.y
            opacity: launcherBox.opacity
        }
    }
}
