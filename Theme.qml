pragma Singleton
import QtQuick

QtObject {
    property string fontFamily: "SF Pro Text"
    property font bodyFont: Qt.font({
        "family": fontFamily,
        "pointSize": 11,
        "weight": 700
    })
    property font barFont: Qt.font({
        "family": fontFamily,
        "pointSize": 10,
        "weight": 700
    })
    property font iconFont: Qt.font({
        "family": "JetBrainsMono Nerd Font",
        "pointSize": 10,
        "weight": 500
    })
    property font clockFont: Qt.font({
        "family": fontFamily,
        "pointSize": 11,
        "letterSpacing": 1,
        "weight": 700
    })
    property color background: "#111111"
    property int gap: 16
    property int radius: 16
    property color separator: "#333"
    property color text: "#eee"
    property color accent: "#fff"
    property color muted: "#666"
    property color surface: "#222222"
    property color border: "#333"
    property color textSecondary: "#aaa"
    property color bgSelected: "#333"
    property color transparent: "#00000000"
    property int animationSpeed: 500
}
