import CoreGraphics
import Testing

@testable import BrandIcons

@Suite("SVG document")
struct SVGDocumentTests {
    private let simpleIcons = """
    <svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">\
    <title>Netflix</title><path d="M5 0 L19 24 L5 24 Z"/></svg>
    """

    @Test("Reads the path and viewBox of an icon set response")
    func readsAnIcon() throws {
        let document = try #require(SVGDocument(svg: simpleIcons))
        #expect(document.pathData == "M5 0 L19 24 L5 24 Z")
        #expect(document.viewBox.equalTo(CGRect(x: 0, y: 0, width: 24, height: 24)))
        #expect(document.fill == nil)
    }

    @Test("Falls back to the 24 by 24 box when the document has none")
    func defaultViewBox() throws {
        let document = try #require(SVGDocument(svg: "<svg><path d=\"M0 0h24v24H0Z\"/></svg>"))
        #expect(document.viewBox.equalTo(SVGDocument.defaultViewBox))
    }

    @Test("A viewBox with a shifted origin is kept")
    func shiftedViewBox() throws {
        let document = try #require(
            SVGDocument(svg: "<svg viewBox='-4 -2 32 32'><path d='M0 0h1v1H0Z'/></svg>")
        )
        #expect(document.viewBox.equalTo(CGRect(x: -4, y: -2, width: 32, height: 32)))
    }

    @Test("A malformed viewBox falls back rather than producing an empty box")
    func malformedViewBox() throws {
        let document = try #require(
            SVGDocument(svg: "<svg viewBox=\"0 0 0 24\"><path d=\"M0 0h1v1H0Z\"/></svg>")
        )
        #expect(document.viewBox.equalTo(SVGDocument.defaultViewBox))
    }

    @Test("Single quoted attributes read the same as double quoted ones")
    func singleQuotes() throws {
        let document = try #require(SVGDocument(svg: "<svg><path d='M0 0h4v4H0Z'/></svg>"))
        #expect(document.pathData == "M0 0h4v4H0Z")
    }

    @Test("Several paths join into one shape")
    func severalPaths() throws {
        let document = try #require(
            SVGDocument(svg: "<svg><path d=\"M0 0h4v4H0Z\"/><path d=\"M8 8h4v4H8Z\"/></svg>")
        )
        #expect(document.pathData == "M0 0h4v4H0Z M8 8h4v4H8Z")
        #expect(SVGPathParser.path(from: document.pathData) != nil)
    }

    @Test("A fill on the root is read, in either hex length")
    func rootFill() throws {
        let long = try #require(
            SVGDocument(svg: "<svg fill=\"#1ED760\"><path d=\"M0 0h1v1H0Z\"/></svg>")
        )
        #expect(long.fill == BrandColor(hex: "#1ED760"))

        let short = try #require(
            SVGDocument(svg: "<svg fill=\"#FFF\"><path d=\"M0 0h1v1H0Z\"/></svg>")
        )
        #expect(short.fill == BrandColor.white)
    }

    @Test("A fill on the path is read when the root has none")
    func pathFill() throws {
        let document = try #require(
            SVGDocument(svg: "<svg><path fill=\"#E50914\" d=\"M0 0h1v1H0Z\"/></svg>")
        )
        #expect(document.fill == BrandColor(hex: "#E50914"))
    }

    @Test("A fill that is not a colour is ignored")
    func nonColourFill() throws {
        let document = try #require(
            SVGDocument(svg: "<svg fill=\"none\"><path d=\"M0 0h1v1H0Z\"/></svg>")
        )
        #expect(document.fill == nil)
    }

    @Test("An attribute whose name merely ends in d is not mistaken for the path")
    func attributeNameBoundaries() throws {
        let document = try #require(
            SVGDocument(svg: "<svg><path id=\"logo\" d=\"M0 0h4v4H0Z\"/></svg>")
        )
        #expect(document.pathData == "M0 0h4v4H0Z")
    }

    @Test("A document with nothing to draw is rejected")
    func nothingToDraw() {
        #expect(SVGDocument(svg: "") == nil)
        #expect(SVGDocument(svg: "<svg viewBox=\"0 0 24 24\"></svg>") == nil)
        #expect(SVGDocument(svg: "<svg><circle cx=\"1\" cy=\"1\" r=\"1\"/></svg>") == nil)
        #expect(SVGDocument(svg: "<svg><path d=\"\"/></svg>") == nil)
        #expect(SVGDocument(svg: "{\"not\": \"svg\"}") == nil)
    }

    @Test("A shape falls back to the caller's tint when the document has no fill")
    func shapeFallbackTint() throws {
        let document = try #require(SVGDocument(svg: simpleIcons))
        let tint = BrandColor(hex: "#E50914")
        let fallback = try #require(tint)
        guard case let .vector(_, _, resolved) = document.shape(fallbackTint: fallback) else {
            Issue.record("expected a vector shape")
            return
        }
        #expect(resolved == tint)
    }
}
