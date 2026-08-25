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
    /// One path to pin, either a mark's flattened path or one of its colour layers.
    struct Reference {
        let slug: String
        let layer: Int?

        init(_ slug: String, layer: Int? = nil) {
            self.slug = slug
            self.layer = layer
        }
    }

    /// Chosen to exercise the grammar, not to be a popularity list. The arc and the two smooth
    /// curve forms are what a port gets wrong, and these carry every command between them.
    ///
    /// The last two are colour layers rather than flattened paths. Almost every mark in the
    /// catalogue now carries colour artwork, and no flattened path in it uses the smooth
    /// quadratic `T`, so pinning only the monochrome ones leaves a command untested.
    static let references = [
        Reference("webgl"), Reference("safari"), Reference("udotsdotnews"),
        Reference("polars"), Reference("pm2"), Reference("linux"), Reference("ollama"),
        Reference("grafana"), Reference("daisyui"), Reference("jquery"),
        Reference("dungeonsanddragons"), Reference("zectrix"), Reference("epicgames"),
        Reference("apachekafka"), Reference("swc"), Reference("styledcomponents"),
        Reference("cisco"), Reference("json"), Reference("pinia"), Reference("gimp"),
        Reference("imagetoolbox", layer: 0), Reference("sessionize", layer: 0)
    ]

    @Test("Export the reference geometry")
    func export() throws {
        guard ProcessInfo.processInfo.environment["BRANDICONS_EXPORT_GOLDEN"] == "1" else { return }

        struct Row: Encodable {
            let slug: String
            /// Which colour layer this row pins, or nil for the mark's flattened path.
            let layer: Int?
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
        for reference in Self.references {
            let slug = reference.slug
            let mark = try #require(BundledCatalog.mark(slug: slug), "missing \(slug)")
            let data = reference.layer.map { mark.layers[$0].path } ?? mark.pathData
            let path = try #require(SVGPathParser.path(from: data), "unparsed \(slug)")

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
                    layer: reference.layer,
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
