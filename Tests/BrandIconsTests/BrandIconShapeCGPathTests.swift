import CoreGraphics
import Foundation
import Testing

@testable import BrandIcons

@Suite("Brand icon shape to CGPath")
struct BrandIconShapeCGPathTests {
    private let square = BrandIconShape.vector(
        path: "M0 0 H24 V24 H0 Z",
        viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
        tint: .black
    )

    @Test("A vector shape parses in its own coordinate space")
    func ownSpace() throws {
        let path = try #require(square.cgPath)
        #expect(path.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 24, height: 24)))
    }

    @Test("A raster shape has no path")
    func rasterHasNoPath() {
        #expect(BrandIconShape.raster(data: Data([0x89, 0x50])).cgPath == nil)
        #expect(
            BrandIconShape.raster(data: Data())
                .cgPath(fitting: CGRect(x: 0, y: 0, width: 10, height: 10)) == nil
        )
    }

    @Test("Unreadable path data yields no path")
    func unreadableData() {
        let broken = BrandIconShape.vector(
            path: "not a path",
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: .black
        )
        #expect(broken.cgPath == nil)
        #expect(broken.cgPath(fitting: CGRect(x: 0, y: 0, width: 44, height: 44)) == nil)
    }

    @Test("Fitting a square box fills it exactly")
    func fitsSquare() throws {
        let rect = CGRect(x: 0, y: 0, width: 44, height: 44)
        let path = try #require(square.cgPath(fitting: rect))
        #expect(path.boundingBoxOfPath.equalTo(rect))
    }

    @Test("Fitting a wide box centres horizontally rather than stretching")
    func preservesAspectRatio() throws {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let path = try #require(square.cgPath(fitting: rect))
        let box = path.boundingBoxOfPath
        #expect(abs(box.width - 40) < 0.001)
        #expect(abs(box.height - 40) < 0.001)
        #expect(abs(box.midX - rect.midX) < 0.001)
        #expect(abs(box.midY - rect.midY) < 0.001)
    }

    @Test("Fitting a tall box centres vertically")
    func preservesAspectRatioWhenTall() throws {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 100)
        let path = try #require(square.cgPath(fitting: rect))
        let box = path.boundingBoxOfPath
        #expect(abs(box.width - 40) < 0.001)
        #expect(abs(box.midY - rect.midY) < 0.001)
    }

    @Test("An offset target rect moves the path with it")
    func offsetRect() throws {
        let rect = CGRect(x: 30, y: 12, width: 20, height: 20)
        let path = try #require(square.cgPath(fitting: rect))
        #expect(path.boundingBoxOfPath.equalTo(rect))
    }

    @Test("A shifted viewBox origin is normalised away")
    func shiftedViewBox() throws {
        let shifted = BrandIconShape.vector(
            path: "M8 8 H32 V32 H8 Z",
            viewBox: CGRect(x: 8, y: 8, width: 24, height: 24),
            tint: .black
        )
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        let path = try #require(shifted.cgPath(fitting: rect))
        #expect(path.boundingBoxOfPath.equalTo(rect))
    }

    @Test("An empty target rect yields no path rather than a divide by zero")
    func emptyRect() {
        #expect(square.cgPath(fitting: .zero) == nil)
        #expect(square.cgPath(fitting: CGRect(x: 0, y: 0, width: 10, height: 0)) == nil)
    }

    @Test("An empty viewBox yields no path")
    func emptyViewBox() {
        let broken = BrandIconShape.vector(path: "M0 0 H1 V1 Z", viewBox: .zero, tint: .black)
        #expect(broken.cgPath(fitting: CGRect(x: 0, y: 0, width: 10, height: 10)) == nil)
    }

    @Test("A real mark fits the rect it is given")
    func realMarkFits() throws {
        let mark = try #require(BundledCatalog.mark(slug: "spotify"))
        let shape = BundledIconProvider.shape(for: mark)
        let rect = CGRect(x: 0, y: 0, width: 60, height: 60)
        let path = try #require(shape.cgPath(fitting: rect))
        let box = path.boundingBoxOfPath
        #expect(box.minX >= rect.minX - 0.01)
        #expect(box.maxX <= rect.maxX + 0.01)
        #expect(box.minY >= rect.minY - 0.01)
        #expect(box.maxY <= rect.maxY + 0.01)
    }
}
