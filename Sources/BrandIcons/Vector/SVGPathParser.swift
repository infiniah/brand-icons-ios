import CoreGraphics
import Foundation

/// Turns SVG path data into a `CGPath`.
///
/// The whole command set is supported: absolute and relative forms, commands whose letter
/// is given once and whose operands repeat, elliptical arcs, and the smooth curve forms
/// `S` and `T` that reflect the previous control point.
///
/// The resulting path is in the source coordinate space, where y grows downwards. That is
/// what UIKit and SwiftUI expect, so no flip is applied. AppKit callers drawing into a
/// y-up context need one.
///
/// ```swift
/// let path = SVGPathParser.path(from: "M0 0h24v24H0Z")
/// ```
public enum SVGPathParser {
    /// The path drawn by `pathData`, or nil when it is empty, malformed, or draws nothing.
    ///
    /// Parsing is strict: unreadable data returns nil rather than a partial shape, because
    /// half an icon is worse than none. Malformed input never throws or traps.
    public static func path(from pathData: String) -> CGPath? {
        var scanner = SVGPathScanner(pathData)
        let path = CGMutablePath()

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var cubicControl: CGPoint?
        var quadraticControl: CGPoint?
        var lastCommand: SVGPathCommand?
        var isSubpathOpen = false

        while true {
            let command: SVGPathCommand
            if let next = scanner.nextCommand() {
                command = next
            } else if scanner.isAtEnd {
                break
            } else if let repeated = lastCommand?.repeated, scanner.hasNumber {
                command = repeated
            } else {
                return nil
            }

            if lastCommand == nil, command.kind != .move { return nil }

            func absolute(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                command.isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            func openSubpath() {
                guard !isSubpathOpen else { return }
                path.move(to: current)
                isSubpathOpen = true
            }

            switch command.kind {
            case .move:
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return nil }
                current = absolute(x, y)
                subpathStart = current
                path.move(to: current)
                isSubpathOpen = true
                cubicControl = nil
                quadraticControl = nil

            case .close:
                if isSubpathOpen {
                    path.closeSubpath()
                    isSubpathOpen = false
                }
                current = subpathStart
                cubicControl = nil
                quadraticControl = nil

            case .line:
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return nil }
                openSubpath()
                current = absolute(x, y)
                path.addLine(to: current)
                cubicControl = nil
                quadraticControl = nil

            case .horizontalLine:
                guard let x = scanner.nextNumber() else { return nil }
                openSubpath()
                current = CGPoint(x: command.isRelative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                cubicControl = nil
                quadraticControl = nil

            case .verticalLine:
                guard let y = scanner.nextNumber() else { return nil }
                openSubpath()
                current = CGPoint(x: current.x, y: command.isRelative ? current.y + y : y)
                path.addLine(to: current)
                cubicControl = nil
                quadraticControl = nil

            case .cubic:
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber()
                else { return nil }
                openSubpath()
                let control1 = absolute(x1, y1)
                let control2 = absolute(x2, y2)
                current = absolute(x, y)
                path.addCurve(to: current, control1: control1, control2: control2)
                cubicControl = control2
                quadraticControl = nil

            case .smoothCubic:
                guard let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber()
                else { return nil }
                openSubpath()
                let control1 = Self.reflection(of: cubicControl, through: current)
                let control2 = absolute(x2, y2)
                current = absolute(x, y)
                path.addCurve(to: current, control1: control1, control2: control2)
                cubicControl = control2
                quadraticControl = nil

            case .quadratic:
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber()
                else { return nil }
                openSubpath()
                let control = absolute(x1, y1)
                current = absolute(x, y)
                path.addQuadCurve(to: current, control: control)
                quadraticControl = control
                cubicControl = nil

            case .smoothQuadratic:
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return nil }
                openSubpath()
                let control = Self.reflection(of: quadraticControl, through: current)
                current = absolute(x, y)
                path.addQuadCurve(to: current, control: control)
                quadraticControl = control
                cubicControl = nil

            case .arc:
                guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                      let degrees = scanner.nextNumber(),
                      let isLargeArc = scanner.nextFlag(), let isSweep = scanner.nextFlag(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber()
                else { return nil }
                openSubpath()
                let end = absolute(x, y)
                let arc = EllipticalArc(
                    start: current,
                    end: end,
                    radii: CGSize(width: rx, height: ry),
                    rotation: degrees * .pi / 180,
                    isLargeArc: isLargeArc,
                    isSweep: isSweep
                )
                let segments = arc.segments
                if segments.isEmpty {
                    if current != end { path.addLine(to: end) }
                } else {
                    for segment in segments {
                        path.addCurve(
                            to: segment.end,
                            control1: segment.control1,
                            control2: segment.control2
                        )
                    }
                }
                current = end
                cubicControl = nil
                quadraticControl = nil
            }

            lastCommand = command
        }

        return path.isEmpty ? nil : path.copy()
    }

    /// The previous control point mirrored through the current point.
    ///
    /// With no previous curve the specification says the control point coincides with the
    /// current point, which makes a lone `S` behave like a plain cubic.
    private static func reflection(of control: CGPoint?, through point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }
}
