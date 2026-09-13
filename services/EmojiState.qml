pragma Singleton

import Quickshell

// Shared coordination for the per-screen EmojiPanel instances.
// Sway has no cursorpos query, so on IPC toggle every instance arms
// its (invisible) fullscreen layer and the first one to see a pointer
// event claims ownership; losers stand down via their arm timer.
Singleton {
    id: root

    property bool open: false
    property int generation: 0
    property string owner: ""

    function requestOpen() {
        generation++;
        owner = "";
        open = true;
    }

    // Returns true if screenName owns (or takes) the open picker.
    function claim(screenName: string): bool {
        if (!open)
            return false;
        if (owner === "")
            owner = screenName;
        return owner === screenName;
    }

    function close() {
        open = false;
        owner = "";
    }
}
