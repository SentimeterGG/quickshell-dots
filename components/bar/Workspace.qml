import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.I3
import "../.."

RowLayout {
    id: workspace

    Repeater {
        model: 9

        RoundButton {
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            font: Theme.barFont
            Layout.fillHeight: true
            Layout.preferredWidth: height
            onClicked: I3.dispatch("workspace number " + (index + 1))
            text: index + 1
            palette.buttonText: I3.focusedWorkspace && I3.focusedWorkspace.number === index + 1 ? "black" : Theme.white
            background: Rectangle {
                radius: Theme.radius - 8
                color: I3.focusedWorkspace && I3.focusedWorkspace.number === index + 1 ? "white" : Theme.surface
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
