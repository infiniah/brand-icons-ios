import CoreGraphics
import Foundation
import Testing
@testable import BrandIcons

/// Holds the reference port to the geometry contract the other three are held to.
///
/// The corpus proves the ports agree about *which* brand a name means. This proves they draw the
/// same shape, which a parser that mishandles an arc gets wrong at a perfect confidence score.
@Suite("Golden geometry verification")
struct GoldenGeometryTests {
    struct Row: Decodable {
        let slug: String
        /// Which colour layer this row pins. Absent for a mark's flattened path.
        let layer: Int?
        let kinds: String
        let bounds: [Double]
        let points: [Double]
    }

    static let reference: [Row] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/golden-geometry.json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else { return [] }
        return rows
    }()

    @Test("Parses every reference mark to the same elements")
    func elements() throws {
        #expect(!Self.reference.isEmpty)
        for row in Self.reference {
            let mark = try #require(BundledCatalog.mark(slug: row.slug), "missing \(row.slug)")
            let data = row.layer.map { mark.layers[$0].path } ?? mark.pathData
            let path = try #require(SVGPathParser.path(from: data), "unparsed \(row.slug)")

            var kinds = ""
            var points: [Double] = []
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
                    points.append(Double(element.points[index].x))
                    points.append(Double(element.points[index].y))
                }
            }

            #expect(kinds == row.kinds, "element kinds for \(row.slug)")
            #expect(points.count == row.points.count, "point count for \(row.slug)")
            for (index, value) in points.enumerated() where index < row.points.count {
                #expect(abs(value - row.points[index]) < 0.01, "\(row.slug) point \(index)")
            }
        }
    }

    @Test("Parses every mark and every layer in the catalogue")
    func everything() {
        var failed: [String] = []
        var paths = 0
        for mark in BundledCatalog.all {
            // A mark with colour layers carries no flattened path, so there is nothing to parse.
            if !mark.pathData.isEmpty {
                paths += 1
                if SVGPathParser.path(from: mark.pathData) == nil {
                    failed.append("\(mark.slug): mono")
                }
            }
            for (index, layer) in mark.layers.enumerated() {
                paths += 1
                if SVGPathParser.path(from: layer.path) == nil {
                    failed.append("\(mark.slug): layer \(index)")
                }
            }
        }
        #expect(failed.isEmpty, "paths that did not parse: \(failed.prefix(10))")
        #expect(paths > 4000)
    }
}
