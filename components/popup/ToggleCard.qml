import QtQuick
import QtQuick.Layouts
import "../.."

// Reusable toggle card: white background while active, with a trailing
// chevron button on the right side.
//
// Usage:
//   ToggleCard {
//       title: "Power"
//       subtitle: root.powerProfile
//       icon: "󰓅"
//       active: root.powerProfile === "Performance"
//       onToggled: {
//           // run your toggle command here
//       }
//       onChevronClicked: {
//           // open a details page here (optional, no-op by default)
//       }
//   }
Rectangle {
    id: card

    property bool active: false
    property string icon: ""
    property string title: ""
    property string subtitle: ""

    signal toggled
    signal chevronClicked

    readonly property color fg: active ? "#111111" : Theme.text
    readonly property color subFg: active ? "#555555" : Theme.textSecondary

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Theme.radius - 8
    color: active ? "#ffffff" : Theme.background
    border.width: 1
    border.color: Theme.border

    Behavior on color {
        ColorAnimation {
            duration: Theme.animationSpeed
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 0
        anchors.leftMargin: 16
        anchors.rightMargin: 0
        spacing: 16

        Text {
            text: card.icon
            font.family: Theme.iconFont.family
            font.pointSize: 18
            color: card.fg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: card.title
                font: Theme.bodyFont
                color: card.fg
            }

            Text {
                text: card.subtitle
                font: Theme.bodyFont
                color: card.subFg
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            radius: 13
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: Theme.iconFont.family
                font.pointSize: 12
                color: card.subFg
            }

            MouseArea {
                anchors.fill: parent
                onClicked: card.chevronClicked()
            }
        }
    }
}
