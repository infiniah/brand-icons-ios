import CoreGraphics
import Foundation

/// One SVG elliptical arc, converted to the cubic Béziers `CGPath` can draw.
///
/// The endpoint parameters an `A` command carries are turned into a centre, a start angle
/// and a sweep, following the SVG 1.1 implementation notes (section F.6). Out of range
/// radii are corrected the way the specification requires rather than rejected, because
/// real path data contains them.
struct EllipticalArc {
    struct Segment {
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint
    }

    let start: CGPoint
    let end: CGPoint
    let radii: CGSize
    let rotation: CGFloat
    let isLargeArc: Bool
    let isSweep: Bool

    /// The arc as cubic segments.
    ///
    /// Empty when the arc degenerates: identical endpoints draw nothing, and a zero radius
    /// is a straight line, which the caller draws instead.
    var segments: [Segment] {
        var rx = abs(radii.width)
        var ry = abs(radii.height)
        guard rx > 0, ry > 0, start != end else { return [] }

        let cosPhi = cos(rotation)
        let sinPhi = sin(rotation)

        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy

        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            let correction = sqrt(lambda)
            rx *= correction
            ry *= correction
        }

        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        guard denominator > 0 else { return [] }
        let numerator = max(0, rx * rx * ry * ry - denominator)
        let coefficient = (isLargeArc == isSweep ? -1 : 1) * sqrt(numerator / denominator)

        let cx1 = coefficient * rx * y1 / ry
        let cy1 = -coefficient * ry * x1 / rx
        let center = CGPoint(
            x: cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2,
            y: sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2
        )

        let unitStart = CGPoint(x: (x1 - cx1) / rx, y: (y1 - cy1) / ry)
        let unitEnd = CGPoint(x: (-x1 - cx1) / rx, y: (-y1 - cy1) / ry)

        let startAngle = Self.angle(from: CGPoint(x: 1, y: 0), to: unitStart)
        var sweep = Self.angle(from: unitStart, to: unitEnd)
        if !isSweep, sweep > 0 {
            sweep -= 2 * .pi
        } else if isSweep, sweep < 0 {
            sweep += 2 * .pi
        }

        let count = max(1, Int(ceil(abs(sweep) / (.pi / 2))))
        let step = sweep / CGFloat(count)
        let controlScale = 4.0 / 3.0 * tan(step / 4)

        func placed(_ point: CGPoint) -> CGPoint {
            let scaledX = point.x * rx
            let scaledY = point.y * ry
            return CGPoint(
                x: cosPhi * scaledX - sinPhi * scaledY + center.x,
                y: sinPhi * scaledX + cosPhi * scaledY + center.y
            )
        }

        return (0..<count).map { index in
            let from = startAngle + CGFloat(index) * step
            let to = from + step
            let unitFrom = CGPoint(x: cos(from), y: sin(from))
            let unitTo = CGPoint(x: cos(to), y: sin(to))
            return Segment(
                control1: placed(
                    CGPoint(
                        x: unitFrom.x - controlScale * sin(from),
                        y: unitFrom.y + controlScale * cos(from)
                    )
                ),
                control2: placed(
                    CGPoint(
                        x: unitTo.x + controlScale * sin(to),
                        y: unitTo.y - controlScale * cos(to)
                    )
                ),
                end: index == count - 1 ? end : placed(unitTo)
            )
        }
    }

    private static func angle(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dot = first.x * second.x + first.y * second.y
        let magnitude = sqrt(
            (first.x * first.x + first.y * first.y) * (second.x * second.x + second.y * second.y)
        )
        guard magnitude > 0 else { return 0 }
        let sign: CGFloat = (first.x * second.y - first.y * second.x) < 0 ? -1 : 1
        return sign * acos(min(1, max(-1, dot / magnitude)))
    }
}
