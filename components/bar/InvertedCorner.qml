import QtQuick
import "../.."

// Concave corner filler for seamless bar <-> popup joints.
// Fills an r x r square with Theme.background minus a quarter-circle
// cutout, so the popup looks merged with the bar instead of floating.
//
// joint values (which square corner is cut out):
//   "bottomLeft"  - top-bar popup, left joint  (gap is bottom-left)
//   "bottomRight" - top-bar popup, right joint (gap is bottom-right)
//   "topLeft"     - bottom-bar popup, left joint
//   "topRight"    - bottom-bar popup, right joint
Canvas {
    id: corner

    property string joint: "bottomLeft"
    property color fill: Theme.background
    property real r: 25
    width: r
    height: r

    onFillChanged: requestPaint()
    onRChanged: requestPaint()
    onJointChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = corner.fill;
        ctx.beginPath();
        if (joint === "bottomLeft") {
            // cutout centre at (0, r)
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.lineTo(r, r);
            ctx.arc(0, r, r, 0, -Math.PI / 2, true);
        } else if (joint === "bottomRight") {
            // cutout centre at (r, r)
            ctx.moveTo(r, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, -Math.PI / 2, false);
        } else if (joint === "topLeft") {
            // cutout centre at (0, 0)
            ctx.moveTo(r, 0);
            ctx.lineTo(r, r);
            ctx.lineTo(0, r);
            ctx.arc(0, 0, r, Math.PI / 2, 0, true);
        } else {
            // "topRight", cutout centre at (r, 0)
            ctx.moveTo(0, 0);
            ctx.lineTo(0, r);
            ctx.lineTo(r, r);
            ctx.arc(r, 0, r, Math.PI / 2, Math.PI, false);
        }
        ctx.closePath();
        ctx.fill();
    }
}
