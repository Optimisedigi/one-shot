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

        // Aim the head along the curve's own tangent at the tip. Aiming it
        // along the straight chord back to the shaft swings the rear corners
        // off the line once the bend gets tight.
        let tangentFrom = point(start: start, end: end, bend: bend, t: 0.9)
        let angle = atan2(end.y - tangentFrom.y, end.x - tangentFrom.x)
        // The head's notch sits this far back along that tangent. The shaft
        // runs into the notch, so the two stay joined at any bend.
        let notch = NSPoint(
            x: end.x - headLength * cos(headAngle) * cos(angle),
            y: end.y - headLength * cos(headAngle) * sin(angle)
        )

        let shaft = NSBezierPath()
        shaft.move(to: start)
        if bend == 0 {
            shaft.line(to: notch)
        } else {
            // Follow the curve to exactly one head-length short of the tip,
            // then a straight run into the notch. The head covers that run, so
            // the line and the head stay joined however tight the bend is.
            let joinT = shaftJoinT(start: start, end: end, bend: bend)
            let join = point(start: start, end: end, bend: bend, t: joinT)
            let steps = 32
            for index in 1...steps {
                let t = joinT * CGFloat(index) / CGFloat(steps)
                shaft.line(to: point(start: start, end: end, bend: bend, t: t))
            }
            shaft.line(to: join)
            shaft.line(to: notch)
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

    /// Parameter one head-length back from the tip, measured along the curve
    /// and interpolated between samples so it doesn't fall short of the head.
    /// A straight-line cutoff misses that point once the bend pulls the tip
    /// back toward the shaft, which is the gap in a tight curve.
    private static func shaftJoinT(start: NSPoint, end: NSPoint, bend: CGFloat) -> CGFloat {
        let steps = 64
        var traveled = CGFloat(0)
        var previous = end
        for index in stride(from: steps - 1, through: 0, by: -1) {
            let t = CGFloat(index) / CGFloat(steps)
            let sample = point(start: start, end: end, bend: bend, t: t)
            let segment = hypot(sample.x - previous.x, sample.y - previous.y)
            if traveled + segment >= headLength {
                let remaining = headLength - traveled
                let fraction = segment > 0 ? remaining / segment : 0
                return t + (CGFloat(index + 1) / CGFloat(steps) - t) * (1 - fraction)
            }
            traveled += segment
            previous = sample
        }
        return 0
    }
}
