import CoreGraphics
import Foundation
import Testing

@testable import BrandIcons

@Suite("SVG path parser")
struct SVGPathParserTests {
    @Test("Draws the four commands a rectangle needs")
    func rectangle() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 H24 V24 H0 Z"))
        #expect(!path.isEmpty)
        #expect(path.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 24, height: 24))
    }

    @Test("Relative commands accumulate from the current point")
    func relativeCommands() throws {
        let absolute = try #require(SVGPathParser.path(from: "M2 2 L6 2 L6 6 L2 6 Z"))
        let relative = try #require(SVGPathParser.path(from: "m2 2 l4 0 l0 4 l-4 0 z"))
        #expect(absolute.boundingBoxOfPath == relative.boundingBoxOfPath)
    }

    @Test("A command letter given once applies to every following operand set")
    func implicitRepeats() throws {
        let repeated = try #require(SVGPathParser.path(from: "M0 0 L4 0 4 4 0 4 Z"))
        let spelled = try #require(SVGPathParser.path(from: "M0 0 L4 0 L4 4 L0 4 Z"))
        #expect(repeated.boundingBoxOfPath == spelled.boundingBoxOfPath)
    }

    @Test("Repeated moveto operands draw lines rather than moves")
    func repeatedMoveDrawsLines() throws {
        let implicit = try #require(SVGPathParser.path(from: "M0 0 4 0 4 4"))
        let explicit = try #require(SVGPathParser.path(from: "M0 0 L4 0 L4 4"))
        #expect(implicit.boundingBoxOfPath == explicit.boundingBoxOfPath)
    }

    @Test("A smooth cubic reflects the previous control point")
    func smoothCubic() throws {
        let smooth = try #require(SVGPathParser.path(from: "M0 0 C2 -4 6 -4 8 0 S14 4 16 0"))
        let spelled = try #require(SVGPathParser.path(from: "M0 0 C2 -4 6 -4 8 0 C10 4 14 4 16 0"))
        #expect(smooth.boundingBoxOfPath.equalTo(spelled.boundingBoxOfPath))
    }

    @Test("A lone smooth cubic uses the current point as its first control")
    func smoothCubicWithoutPrevious() throws {
        let smooth = try #require(SVGPathParser.path(from: "M0 0 S4 8 8 0"))
        let spelled = try #require(SVGPathParser.path(from: "M0 0 C0 0 4 8 8 0"))
        #expect(smooth.boundingBoxOfPath.equalTo(spelled.boundingBoxOfPath))
    }

    @Test("A smooth quadratic reflects the previous control point")
    func smoothQuadratic() throws {
        let smooth = try #require(SVGPathParser.path(from: "M0 0 Q4 -8 8 0 T16 0"))
        let spelled = try #require(SVGPathParser.path(from: "M0 0 Q4 -8 8 0 Q12 8 16 0"))
        #expect(smooth.boundingBoxOfPath.equalTo(spelled.boundingBoxOfPath))
    }

    @Test("An arc sweeps a half circle rather than cutting the corner")
    func arc() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 A5 5 0 0 1 10 0"))
        let box = path.boundingBoxOfPath
        #expect(abs(box.minX - 0) < 0.01)
        #expect(abs(box.maxX - 10) < 0.01)
        #expect(abs(box.height - 5) < 0.01)
    }

    @Test("The large arc flag picks the longer of the two sweeps")
    func largeArcFlag() throws {
        let small = try #require(SVGPathParser.path(from: "M0 0 A8 8 0 0 1 10 0"))
        let large = try #require(SVGPathParser.path(from: "M0 0 A8 8 0 1 1 10 0"))
        #expect(abs(small.boundingBoxOfPath.height - (8 - sqrt(39.0))) < 0.01)
        #expect(abs(large.boundingBoxOfPath.height - (8 + sqrt(39.0))) < 0.01)
    }

    @Test("An arc with a zero radius degenerates to a straight line")
    func degenerateArc() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 A0 0 0 0 1 10 0"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 10, height: 0)))
    }

    @Test("Arc flags need no separator, and neither do signed numbers")
    func compactNotation() throws {
        let compact = try #require(SVGPathParser.path(from: "M0 0a5 5 0 015 5"))
        let spaced = try #require(SVGPathParser.path(from: "M0 0 a5 5 0 0 1 5 5"))
        #expect(compact.boundingBoxOfPath.equalTo(spaced.boundingBoxOfPath))
    }

    @Test("Two decimal points in a row separate two numbers")
    func runOnDecimals() throws {
        let run = try #require(SVGPathParser.path(from: "M0 0l.5.5"))
        let spaced = try #require(SVGPathParser.path(from: "M0 0 l 0.5 0.5"))
        #expect(run.boundingBoxOfPath.equalTo(spaced.boundingBoxOfPath))
    }

    @Test("Every character the grammar calls whitespace separates numbers")
    func separators() throws {
        let spaced = try #require(SVGPathParser.path(from: "M0 0 L4 0 L4 4"))
        for separator in ["\u{0C}", "\u{0B}", "\t", "\n", "\r", ",", "  "] {
            let joined = "M0\(separator)0\(separator)L4\(separator)0\(separator)L4\(separator)4"
            let path = try #require(SVGPathParser.path(from: joined), "\(joined.debugDescription)")
            #expect(path.boundingBoxOfPath.equalTo(spaced.boundingBoxOfPath))
        }
    }

    @Test("Exponent notation parses as one number")
    func exponents() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 L1e1 5e-1"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 10, height: 0.5)))
    }

    @Test("A closed subpath returns to its own start, not the origin")
    func closeReturnsToSubpathStart() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 H2 V2 Z M10 10 H12 V12 Z l-2 0"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 12, height: 12)))
    }

    @Test("Every bundled mark parses into a path inside its own viewBox")
    func bundledMarksStayInsideTheirViewBox() throws {
        #expect(!BundledCatalog.all.isEmpty)

        for mark in BundledCatalog.all {
            let path = SVGPathParser.path(from: mark.pathData)
            let parsed = try #require(path, "\(mark.slug) did not parse")
            #expect(!parsed.isEmpty, "\(mark.slug) parsed into nothing")

            let box = parsed.boundingBoxOfPath
            #expect(box.width > 0, "\(mark.slug) has no width")
            #expect(box.height > 0, "\(mark.slug) has no height")

            // Simple Icons art is drawn to a 24 unit grid and a couple of paths overshoot it by
            // hundredths of a unit. The colour sets are drawn to their own canvases and a handful
            // overshoot by a few percent, so they get the same tenth the generator admits them
            // under. Anything worse than that is rejected before it reaches the catalogue, and a
            // mis-parsed path lands hundreds of units out rather than a few.
            let tolerance = mark.layers.isEmpty
                ? 0.1
                : max(0.1, 0.1 * max(mark.viewBox.width, mark.viewBox.height))
            #expect(box.minX >= mark.viewBox.minX - tolerance, "\(mark.slug) overflows left")
            #expect(box.minY >= mark.viewBox.minY - tolerance, "\(mark.slug) overflows top")
            #expect(box.maxX <= mark.viewBox.maxX + tolerance, "\(mark.slug) overflows right")
            #expect(box.maxY <= mark.viewBox.maxY + tolerance, "\(mark.slug) overflows bottom")
        }
    }

    @Test(
        "Marks that lean on the trickier commands parse",
        arguments: ["spotify", "netflix", "github", "1password", "cloudflare", "discord"]
    )
    func namedMarks(slug: String) throws {
        let mark = try #require(BundledCatalog.mark(slug: slug))
        let path = try #require(SVGPathParser.path(from: mark.pathData))
        #expect(!path.isEmpty)
        #expect(path.boundingBoxOfPath.width > 1)
    }
}
