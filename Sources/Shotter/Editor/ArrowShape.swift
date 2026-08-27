import AppKit

/// Geometry and drawing for arrows. `bend` is the signed sideways distance of
/// the arc's deepest point from the straight line between the two ends, so a
/// bend of 0 draws exactly the old straight arrow.
enum ArrowShape {
    private static let headLength: CGFloat = 18
    private static let headAngle: CGFloat = .pi / 7

    /// Quadratic control point that makes the curve pass through the deepest
    /// point of the drag arc.
    private static func controlPoint(start: NSPoint, end: NSPoint, bend: CGFloat) -> NSPoint {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0, bend != 0 else {
            return NSPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        let normal = NSPoint(x: -(end.y - start.y) / length, y: (end.x - start.x) / length)
        return NSPoint(
            x: (start.x + end.x) / 2 + normal.x * bend * 2,
            y: (start.y + end.y) / 2 + normal.y * bend * 2
        )
    }

    static func point(start: NSPoint, end: NSPoint, bend: CGFloat, t: CGFloat) -> NSPoint {
        let control = controlPoint(start: start, end: end, bend: bend)
        let inverse = 1 - t
        return NSPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    /// Points along the curve, used for hit-testing and bounds.
    static func sampledPoints(start: NSPoint, end: NSPoint, bend: CGFloat, count: Int = 24) -> [NSPoint] {
        (0...count).map { point(start: start, end: end, bend: bend, t: CGFloat($0) / CGFloat(count)) }
    }

    static func bounds(start: NSPoint, end: NSPoint, bend: CGFloat) -> NSRect {
        let points = sampledPoints(start: start, end: end, bend: bend)
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return Geometry.normalizedRect(from: start, to: end)
        }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Sideways distance of `path`'s deepest point from the straight line
    /// between its ends: how much the user curved the drag.
    static func bend(fromDragPath path: [NSPoint]) -> CGFloat {
        guard let start = path.first, let end = path.last else { return 0 }
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return 0 }
        let normal = NSPoint(x: -(end.y - start.y) / length, y: (end.x - start.x) / length)
        let offsets = path.map { ($0.x - start.x) * normal.x + ($0.y - start.y) * normal.y }
        return offsets.max(by: { abs($0) < abs($1) }) ?? 0
    }

    static func draw(start: NSPoint, end: NSPoint, bend: CGFloat, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        color.setFill()

        // Direction the head points in: the curve's tangent where it lands.
        let tangentFrom = point(start: start, end: end, bend: bend, t: 0.92)
        let angle = atan2(end.y - tangentFrom.y, end.x - tangentFrom.x)
        let arrowLength = hypot(end.x - start.x, end.y - start.y)
        let shaftInset = min(headLength * 0.72, max(0, arrowLength - lineWidth))

        let shaft = NSBezierPath()
        shaft.move(to: start)
        if bend == 0 {
            shaft.line(to: NSPoint(x: end.x - shaftInset * cos(angle), y: end.y - shaftInset * sin(angle)))
        } else {
            // Stop the curve short of the tip so the head isn't drawn over.
            let shaftEndT = arrowLength > 0 ? max(0.01, 1 - shaftInset / arrowLength) : 1
            for t in stride(from: CGFloat(0), through: shaftEndT, by: shaftEndT / 24) {
                shaft.line(to: point(start: start, end: end, bend: bend, t: t))
            }
        }
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.lineJoinStyle = .round
        shaft.stroke()

        let p1 = NSPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = NSPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: p1)
        head.line(to: p2)
        head.close()
        head.fill()
    }
}
