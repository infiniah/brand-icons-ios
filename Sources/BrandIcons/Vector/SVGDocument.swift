import CoreGraphics
import Foundation

/// The parts of an SVG file this package can draw.
///
/// This reads the small, regular kind of SVG that icon services return: a `viewBox` and one
/// or more plain `<path>` elements. It is not an SVG renderer. Gradients, masks, strokes,
/// text and nested transforms are ignored, so a file that needs them would draw wrongly
/// rather than not at all, and a caller handed one is better off with a raster.
public struct SVGDocument: Hashable, Sendable {
    /// Every `<path>` element's data, joined. Drawn as one shape.
    public let pathData: String

    /// The coordinate space ``pathData`` is drawn in.
    public let viewBox: CGRect

    /// The `fill` declared on the root element or on the first path, when it names a colour.
    public let fill: BrandColor?

    /// Parses an SVG document. Returns nil when it has no path to draw.
    public init?(svg: String) {
        let paths = SVGDocument.tagBodies(named: "path", in: svg)
        let data = paths
            .compactMap { SVGDocument.attribute("d", in: $0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !data.isEmpty else { return nil }

        let root = SVGDocument.tagBodies(named: "svg", in: svg).first

        pathData = data.joined(separator: " ")
        viewBox = root.flatMap(SVGDocument.viewBox) ?? SVGDocument.defaultViewBox
        fill = SVGDocument.fill(in: root) ?? SVGDocument.fill(in: paths.first)
    }

    /// The 24 by 24 box icon sets converge on, used when a document omits its own.
    public static let defaultViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    /// The document as a drawable shape.
    ///
    /// - Parameter tint: Used when the document carries no usable ``fill`` of its own.
    public func shape(fallbackTint tint: BrandColor) -> BrandIconShape {
        .vector(path: pathData, viewBox: viewBox, tint: fill ?? tint)
    }

    private static func viewBox(in body: Substring) -> CGRect? {
        guard let raw = attribute("viewBox", in: body) else { return nil }
        let numbers = raw
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .compactMap { Double($0) }
        guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    private static func fill(in body: Substring?) -> BrandColor? {
        guard let body, let raw = attribute("fill", in: body) else { return nil }
        return BrandColor(hex: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// The attribute text of every `<name ...>` opening tag, in document order.
    private static func tagBodies(named name: String, in svg: String) -> [Substring] {
        var bodies: [Substring] = []
        var cursor = svg.startIndex
        let opening = "<" + name

        while let found = svg.range(of: opening, range: cursor..<svg.endIndex) {
            cursor = found.upperBound
            guard let boundary = svg[found.upperBound...].first,
                  boundary.isWhitespace || boundary == "/" || boundary == ">"
            else { continue }
            guard let close = svg[found.upperBound...].firstIndex(of: ">") else { break }
            bodies.append(svg[found.upperBound..<close])
            cursor = close
        }
        return bodies
    }

    /// The quoted value of one attribute within a tag's attribute text.
    private static func attribute(_ name: String, in body: Substring) -> String? {
        var cursor = body.startIndex

        while let found = body.range(of: name, range: cursor..<body.endIndex) {
            cursor = found.upperBound

            if found.lowerBound > body.startIndex {
                let preceding = body[body.index(before: found.lowerBound)]
                guard preceding.isWhitespace else { continue }
            }

            var index = found.upperBound
            while index < body.endIndex, body[index].isWhitespace { index = body.index(after: index) }
            guard index < body.endIndex, body[index] == "=" else { continue }

            index = body.index(after: index)
            while index < body.endIndex, body[index].isWhitespace { index = body.index(after: index) }
            guard index < body.endIndex else { return nil }

            let quote = body[index]
            guard quote == "\"" || quote == "'" else { continue }

            index = body.index(after: index)
            guard let end = body[index...].firstIndex(of: quote) else { return nil }
            return String(body[index..<end])
        }
        return nil
    }
}
