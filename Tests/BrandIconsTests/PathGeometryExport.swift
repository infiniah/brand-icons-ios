import CoreGraphics
import Foundation
import Testing
@testable import BrandIcons

/// Writes the geometry every port's path parser must reproduce.
///
/// The golden corpus proves the ports agree about *which* brand a name means. It says nothing
/// about whether they draw the same shape, and a parser that mishandles an arc or a smooth
/// curve produces a mangled icon at a perfect confidence score. This pins the other half.
///
/// Run with `BRANDICONS_EXPORT_GOLDEN=1 swift test --filter PathGeometryExport`.
@Suite("Path geometry")
struct PathGeometryExport {
    /// Chosen to exercise the grammar, not to be a popularity list: `duolingo` is the longest
    /// path in the catalogue, and the arc and smooth curve cases are the ones a port gets wrong.
    /// Chosen for grammar coverage, and all monochrome.
    ///
    /// A mark with colour artwork carries no flattened path, so it has nothing single to pin here.
    /// The parser is what this fixture exists to hold still, and these exercise arcs, both smooth
    /// curve forms, quadratics and the shorthand line commands between them.
    static let slugs = [
        "elsevier", "phpbb", "composer", "newjapanprowrestling", "unilever",
        "interactiondesignfoundation", "porsche", "postcss", "gutenberg", "unitednations",
        "virgin", "openbsd", "libuv", "ritzcarlton", "bentley", "maxplanckgesellschaft",
        "packagist", "shikimori", "worldhealthorganization", "safari"
    ]

    @Test("Export the reference geometry")
    func export() throws {
        guard ProcessInfo.processInfo.environment["BRANDICONS_EXPORT_GOLDEN"] == "1" else { return }

        struct Row: Encodable {
            let slug: String
            let kinds: String
            let bounds: [Double]
            /// Every control and end point, in element order, rounded to three decimals.
            ///
            /// The coordinates themselves rather than a hash of them: the ports use different
            /// float widths, so a comparison needs a tolerance, and a tolerance needs the
            /// numbers. It also means a failure names the element that moved instead of
            /// reporting that something, somewhere, differs.
            let points: [Double]
        }

        var rows: [Row] = []
        for slug in Self.slugs {
            let mark = try #require(BundledCatalog.mark(slug: slug), "missing \(slug)")
            let path = try #require(SVGPathParser.path(from: mark.pathData), "unparsed \(slug)")

            var kinds = ""
            var coordinates: [Double] = []
            path.applyWithBlock { pointer in
                let element = pointer.pointee
                let count: Int
                switch element.type {
                case .moveToPoint: kinds += "M"; count = 1
                case .addLineToPoint: kinds += "L"; count = 1
                case .addQuadCurveToPoint: kinds += "Q"; count = 2
                case .addCurveToPoint: kinds += "C"; count = 3
                case .closeSubpath: kinds += "Z"; count = 0
                @unknown default: kinds += "?"; count = 0
                }
                for index in 0..<count {
                    let point = element.points[index]
                    coordinates.append((Double(point.x) * 1000).rounded() / 1000)
                    coordinates.append((Double(point.y) * 1000).rounded() / 1000)
                }
            }

            let box = path.boundingBoxOfPath
            rows.append(
                Row(
                    slug: slug,
                    kinds: kinds,
                    bounds: [box.minX, box.minY, box.width, box.height]
                        .map { (Double($0) * 1000).rounded() / 1000 },
                    points: coordinates
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/golden-geometry.json")
        try encoder.encode(rows).write(to: url)
        print("GEOMETRY WRITTEN: \(url.path)")
    }

}
