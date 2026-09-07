import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../.."

Rectangle {
    id: root

    property date viewedDate: new Date()
    property int viewMonth: viewedDate.getMonth()
    property int viewYear: viewedDate.getFullYear()
    property int todayDay: new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()

    function daysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstWeekday(month, year) {
        let d = new Date(year, month, 1).getDay();
        return d === 0 ? 6 : d - 1;
    }

    color: Theme.background
    bottomLeftRadius: 20
    bottomRightRadius: 20

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        height: Theme.radius
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            RoundButton {
                text: "\u2190"
                font: Theme.bodyFont
                flat: true
                palette.buttonText: Theme.text
                onClicked: {
                    viewMonth--;
                    if (viewMonth < 0) {
                        viewMonth = 11;
                        viewYear--;
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font: Theme.bodyFont
                color: Theme.text
                text: {
                    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                    return months[viewMonth] + " " + viewYear;
                }
            }

            RoundButton {
                text: "\u2192"
                font: Theme.bodyFont
                flat: true
                palette.buttonText: Theme.text
                onClicked: {
                    viewMonth++;
                    if (viewMonth > 11) {
                        viewMonth = 0;
                        viewYear++;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font: Theme.bodyFont
                    color: Theme.muted
                }
            }
        }

        Grid {
            id: grid

            property int firstDay: firstWeekday(viewMonth, viewYear)
            property int daysCurr: daysInMonth(viewMonth, viewYear)
            property int daysPrev: daysInMonth(viewMonth - 1 < 0 ? 11 : viewMonth - 1, viewMonth - 1 < 0 ? viewYear - 1 : viewYear)
            property int totalCells: Math.ceil((firstDay + daysCurr) / 7) * 7
            property real cellWidth: (width - columnSpacing * (columns - 1)) / columns
            property real cellHeight: cellWidth

            columns: 7
            columnSpacing: 4
            rowSpacing: 4
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: grid.totalCells

                Rectangle {
                    property int dayNum: {
                        if (index < grid.firstDay)
                            return grid.daysPrev - grid.firstDay + index + 1;
                        else if (index < grid.firstDay + grid.daysCurr)
                            return index - grid.firstDay + 1;
                        else
                            return index - (grid.firstDay + grid.daysCurr) + 1;
                    }
                    property bool isCurrentMonth: index >= grid.firstDay && index < grid.firstDay + grid.daysCurr
                    property bool isToday: isCurrentMonth && dayNum === todayDay && viewMonth === todayMonth && viewYear === todayYear

                    width: grid.cellWidth
                    height: grid.cellHeight
                    radius: 8
                    color: isToday ? "#ffffff" : (isCurrentMonth ? Theme.surface : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: parent.dayNum
                        font: Theme.bodyFont
                        color: isToday ? "#000000" : (isCurrentMonth ? Theme.text : Theme.muted)
                    }
                }
            }
        }
    }
}
