import CoreGraphics
import Testing

@testable import BrandIcons

@Suite("SVG path parser, hostile input")
struct SVGPathParserHostileInputTests {
    @Test(
        "Malformed data returns nil rather than a partial shape",
        arguments: [
            "",
            "   ",
            "\n\t",
            "Z",
            "L10 10",
            "10 10 20 20",
            "M",
            "M0",
            "M0 0 L",
            "M0 0 L5",
            "M0 0 C1 1 2 2 3",
            "M0 0 Q1 1 2",
            "M0 0 A5 5 0 1",
            "M0 0 A5 5 0 2 1 10 0",
            "M0 0 X10 10",
            "M0 0 L10 10 !",
            "M0 0 L abc",
            "M0 0 L.. 5",
            "M0 0 L1e 5",
            "M0 0 Z 5 5",
            "M0 0 H",
            "M0 0 V",
            "M0 0 T",
            "M0 0 S1 1 2",
        ]
    )
    func malformedReturnsNil(pathData: String) {
        #expect(SVGPathParser.path(from: pathData) == nil)
    }

    @Test("Numbers after a close command do not loop forever")
    func closeIsNotRepeatable() {
        #expect(SVGPathParser.path(from: "M0 0 L1 1 Z 5 5 5 5") == nil)
    }

    @Test("Repeated closes leave one closed subpath rather than tripping CoreGraphics")
    func repeatedCloses() throws {
        let path = try #require(SVGPathParser.path(from: "M0 0 H4 V4 Z Z Z"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 4, height: 4)))
    }

    @Test("Drawing after a close starts a fresh subpath from the close point")
    func drawingAfterClose() throws {
        let path = try #require(SVGPathParser.path(from: "M2 2 H6 V6 Z L2 10"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 2, y: 2, width: 4, height: 8)))
    }

    @Test("A path of nothing but a move draws nothing but does not fail")
    func moveOnly() throws {
        let path = try #require(SVGPathParser.path(from: "M5 5"))
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 5, y: 5, width: 0, height: 0)))
    }

    @Test("Very long input parses without stack growth")
    func longInput() throws {
        let segments = (0..<5_000).map { "L\($0 % 24) \($0 % 24)" }.joined(separator: " ")
        let path = try #require(SVGPathParser.path(from: "M0 0 " + segments))
        #expect(!path.isEmpty)
    }

    @Test("Nonsense that is not path data at all returns nil")
    func notPathData() {
        #expect(SVGPathParser.path(from: "<svg><path d=\"M0 0\"/></svg>") == nil)
        #expect(SVGPathParser.path(from: "{\"path\": \"M0 0\"}") == nil)
    }
}
