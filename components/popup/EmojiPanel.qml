import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import "../bar"
import "../.."
import "EmojiData.js" as EmojiData

// Emoji chooser triggered via IPC (`qs ipc call emoji toggle`).
// Top-left dropdown like LauncherPanel: the card slides down from
// behind the bar with a seamless inverted-corner joint.
// Every per-screen instance arms on toggle and the first one to see
// a pointer event claims ownership (see EmojiState); Sway offers no
// cursorpos query, so the focused output (via swaymsg) is the
// fallback for choosing which screen shows the card. Picking copies
// to clipboard and types via wtype after focus returns to the app.
Scope {
    id: root

    property bool closed: true
    required property ShellScreen targetScreen

    // Arming: layer mapped invisibly, waiting for a pointer event.
    // Claimed: this instance owns the open picker.
    property bool armed: false
    property bool claimed: false
    property bool cardVisible: false

    // Browser state
    property int currentCat: -1 // -1 = Recent, else EmojiData category
    property var filtered: []
    property var recents: []
    property string hoverName: ""
    property string statusLine: ""
    property var tabNames: ["Recent"].concat(EmojiData.CATEGORIES)

    readonly property int cardW: 384
    readonly property int cardH: 452

    IpcHandler {
        target: "emoji"

        function toggle() {
            root.toggle();
        }
    }

    function screenName(): string {
        return root.targetScreen.name;
    }

    function toggle() {
        // Shared state decides: a second toggle closes, otherwise arm.
        if (EmojiState.open) {
            hidePanel();
            return;
        }
        EmojiState.requestOpen();
        closed = false;
        armed = true;
        claimed = false;
        cardVisible = false;
        emojiPopup.visible = true;
        armTimer.start();
    }

    function hidePanel() {
        if (closed && !armed)
            return;
        closed = true;
        armed = false;
        claimed = false;
        cardVisible = false;
        closeTimer.start();
        if (EmojiState.owner === screenName())
            EmojiState.close();
    }

    // First pointer event on the armed layer takes ownership;
    // the card itself lives top-left, launcher-style.
    function claimAt() {
        if (!armed || claimed)
            return;
        if (!EmojiState.claim(screenName()))
            return;
        claimed = true;
        cardVisible = true;
    }

    function refreshModel() {
        var q = searchField.text.trim();
        if (q !== "")
            filtered = EmojiData.search(q);
        else if (currentCat === -1)
            filtered = root.recents.map(function (c) {
                return EmojiData.lookup(c);
            });
        else
            filtered = EmojiData.byCategory(currentCat);
        emojiGrid.currentIndex = filtered.length > 0 ? 0 : -1;
        updateStatus();
    }

    function updateStatus() {
        var q = searchField.text.trim();
        if (q !== "")
            statusLine = filtered.length === 1 ? "1 match · Enter to insert" : filtered.length + " matches · Enter inserts first";
        else if (currentCat === -1)
            statusLine = "Recent · type to search · Esc to close";
        else
            statusLine = EmojiData.categoryName(currentCat) + " · type to search · Esc to close";
    }

    function emptyHint(): string {
        if (searchField.text.trim() !== "")
            return "No matches";
        if (currentCat === -1)
            return "No recent emojis yet";
        return "Nothing here";
    }

    function pick(ch: string) {
        if (!ch)
            return;
        var i = root.recents.indexOf(ch);
        if (i !== -1)
            root.recents.splice(i, 1);
        root.recents.unshift(ch);
        while (root.recents.length > 20)
            root.recents.pop();
        persistRecents();
        Quickshell.clipboardText = ch;
        hidePanel();
        pendingChar = ch;
        typeTimer.start();
    }

    function persistRecents() {
        var args = root.recents.map(function (c) {
            return "'" + c + "'";
        }).join(" ");
        ioProc.exec(["sh", "-c", "mkdir -p \"$HOME\"/.cache/quickshell && printf '%s\\n' " + args + " > \"$HOME\"/.cache/quickshell/emoji-recent"]);
    }

    property string pendingChar: ""
    property string outputsJson: ""

    Timer {
        id: armTimer
        interval: 250
        onTriggered: {
            if (claimed)
                return;
            // Someone else claimed: stand down.
            if (EmojiState.owner !== "") {
                root.disarm();
                return;
            }
            // No pointer event arrived (e.g. perfectly still cursor
            // whose enter carried no motion): fall back to the focused
            // output via swaymsg instead of blind centering.
            if (!outputsProc.running) {
                root.outputsJson = "";
                outputsProc.running = true;
            }
        }
    }

    function disarm() {
        armed = false;
        closed = true;
        emojiPopup.visible = false;
    }

    // Last resort when no pointer event and no focused output
    // could be found. Only the primary screen shows; others hide.
    function centerFallback() {
        if (screenName() !== Quickshell.screens[0].name) {
            disarm();
            return;
        }
        if (!EmojiState.claim(screenName())) {
            disarm();
            return;
        }
        claimed = true;
        cardVisible = true;
    }

    // Name of the Sway-focused output, or null.
    function focusedOutputName() {
        var arr = null;
        try {
            arr = JSON.parse(root.outputsJson);
        } catch (e) {
            return null;
        }
        if (!arr || !arr.length)
            return null;
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].focused)
                return arr[i].name;
        }
        return null;
    }

    function focusFallback() {
        if (!armed || claimed)
            return;
        if (EmojiState.owner !== "") {
            disarm();
            return;
        }
        var name = focusedOutputName();
        if (!name) {
            centerFallback();
            return;
        }
        if (name !== screenName()) {
            disarm();
            return;
        }
        if (!EmojiState.claim(screenName())) {
            disarm();
            return;
        }
        claimed = true;
        cardVisible = true;
    }

    Timer {
        id: closeTimer
        interval: Theme.animationSpeed
        onTriggered: {
            if (root.closed)
                emojiPopup.visible = false;
        }
    }

    Timer {
        id: typeTimer
        interval: 120
        onTriggered: {
            if (root.pendingChar !== "")
                ioProc.exec(["wtype", root.pendingChar]);
            root.pendingChar = "";
        }
    }

    Process {
        id: ioProc
    }

    Process {
        id: outputsProc
        command: ["sh", "-c", "swaymsg -t get_outputs 2>/dev/null"]
        stdout: SplitParser {
            // Re-add the stripped newline so the chunks reassemble
            // into valid JSON regardless of split points.
            onRead: data => {
                if (data)
                    root.outputsJson += data + "\n";
            }
        }
        onExited: {
            if (root.claimed)
                return;
            if (root.armed && EmojiState.owner === "")
                root.focusFallback();
            else
                root.disarm();
        }
    }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat \"$HOME\"/.cache/quickshell/emoji-recent 2>/dev/null"]
        stdout: SplitParser {
            // SplitParser may deliver one line or many per chunk,
            // so split and accumulate instead of replacing.
            onRead: data => {
                if (!data)
                    return;
                var lines = data.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var ch = lines[i].trim();
                    if (ch && root.recents.indexOf(ch) === -1 && root.recents.length < 20)
                        root.recents = root.recents.concat([ch]);
                }
            }
        }
    }

    Component.onCompleted: loadProc.running = true

    onCardVisibleChanged: {
        if (cardVisible) {
            searchField.text = "";
            currentCat = -1;
            hoverName = "";
            refreshModel();
            searchField.forceActiveFocus();
        }
    }

    // qmllint disable uncreatable-type
    PanelWindow {
        id: emojiPopup
        screen: root.targetScreen
        visible: false
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.claimed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-emoji"

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }
        margins.top: topBar.height

        // Dim backdrop, only on the claiming screen.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.claimed ? 0.35 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationSpeed
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Fullscreen catcher: click outside closes; the first pointer
        // event claims ownership for this screen.
        // NOTE: motion alone is not enough — a perfectly still cursor
        // generates enter but no motion, so claim on enter too.
        MouseArea {
            id: catcher
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onContainsMouseChanged: {
                if (containsMouse)
                    root.claimAt();
            }
            onMouseXChanged: root.claimAt()
            onMouseYChanged: root.claimAt()
            onClicked: {
                if (root.cardVisible)
                    root.hidePanel();
            }
        }

        // Top-left dropdown card, launcher-style: slides down from
        // behind the bar with a seamless inverted-corner joint.
        Rectangle {
            id: emojiCard
            width: root.cardW
            height: root.cardH
            bottomRightRadius: 16
            color: Theme.background
            x: Theme.gap
            y: root.cardVisible ? 0 : -height - Theme.gap
            visible: root.cardVisible || closeTimer.running
            opacity: root.cardVisible ? 1 : 0
            scale: root.cardVisible ? 1 : 0.94
            transformOrigin: Item.TopLeft
            Behavior on y {
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
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animationSpeed
                    easing.type: Easing.OutExpo
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    placeholderText: "Search emoji…"
                    font: Theme.bodyFont
                    color: Theme.text
                    placeholderTextColor: Theme.muted
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        radius: 10
                        color: Theme.surface
                        border.width: 1
                        border.color: searchField.activeFocus ? Theme.textSecondary : Theme.border
                    }
                    onTextChanged: root.refreshModel()
                    Keys.onEscapePressed: root.hidePanel()
                    Keys.onDownPressed: {
                        if (emojiGrid.count > 0) {
                            emojiGrid.currentIndex = 0;
                            emojiGrid.forceActiveFocus();
                        }
                    }
                    Keys.onReturnPressed: {
                        if (root.filtered.length > 0)
                            root.pick(root.filtered[0].char);
                    }
                    Keys.onEnterPressed: {
                        if (root.filtered.length > 0)
                            root.pick(root.filtered[0].char);
                    }
                }

                ListView {
                    id: tabRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.tabNames

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: tabLabel.implicitWidth + 20
                        height: 30
                        radius: 15
                        color: root.currentCat === index - 1 ? Theme.text : (tabMouse.containsMouse ? Theme.bgSelected : "transparent")

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            font: Theme.bodyFont
                            color: root.currentCat === index - 1 ? Theme.background : Theme.textSecondary
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentCat = index - 1;
                                root.hoverName = "";
                                root.refreshModel();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: emojiGrid
                        anchors.fill: parent
                        clip: true
                        cellWidth: 45
                        cellHeight: 50
                        boundsBehavior: Flickable.StopAtBounds

                        model: root.filtered

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 45
                            height: 50
                            radius: 10
                            color: GridView.isCurrentItem && emojiGrid.activeFocus ? Theme.bgSelected : (cellMouse.containsMouse ? Theme.surface : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.char
                                font.pointSize: 24
                            }
                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(modelData.char)
                                onContainsMouseChanged: root.hoverName = containsMouse ? modelData.name : "";
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < root.filtered.length)
                                root.hoverName = "";
                            root.updateStatus();
                        }

                        Keys.onEscapePressed: root.hidePanel()
                        Keys.onReturnPressed: {
                            if (currentIndex >= 0 && currentIndex < root.filtered.length)
                                root.pick(root.filtered[currentIndex].char);
                        }
                        Keys.onEnterPressed: {
                            if (currentIndex >= 0 && currentIndex < root.filtered.length)
                                root.pick(root.filtered[currentIndex].char);
                        }
                        Keys.onPressed: event => {
                            var cols = 8;
                            if (event.key === Qt.Key_Left) {
                                currentIndex = Math.max(0, currentIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                currentIndex = Math.min(count - 1, currentIndex + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (currentIndex - cols < 0) {
                                    searchField.forceActiveFocus();
                                } else {
                                    currentIndex -= cols;
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                currentIndex = Math.min(count - 1, currentIndex + cols);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backspace) {
                                searchField.text = searchField.text.slice(0, -1);
                                searchField.forceActiveFocus();
                                searchField.cursorPosition = searchField.text.length;
                                event.accepted = true;
                            } else if (event.text !== "" && !event.modifiers) {
                                searchField.text += event.text;
                                searchField.forceActiveFocus();
                                searchField.cursorPosition = searchField.text.length;
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.emptyHint()
                        font: Theme.bodyFont
                        color: Theme.muted
                        visible: root.filtered.length === 0
                    }
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: root.hoverName !== "" ? root.hoverName : root.statusLine
                    font.family: Theme.bodyFont.family
                    font.pointSize: 10
                    color: Theme.textSecondary
                }
            }
        }

        // Inverted corners: seamless joint where emojiCard touches topBar
        InvertedCorner {
            joint: "bottomRight"
            x: emojiCard.width + emojiCard.x
            y: emojiCard.y
            opacity: emojiCard.opacity
        }
        InvertedCorner {
            joint: "bottomRight"
            x: emojiCard.x
            y: emojiCard.height + emojiCard.y
            opacity: emojiCard.opacity
        }
    }
}
