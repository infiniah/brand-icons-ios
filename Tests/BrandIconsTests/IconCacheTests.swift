import CoreGraphics
import Foundation
import Testing
@testable import BrandIcons

struct IconCacheTests {
    private func raster(bytes: Int) -> BrandIconShape {
        .raster(data: Data(repeating: 0xAB, count: bytes))
    }

    @Test func itReturnsWhatItWasGiven() async {
        let cache = IconCache()
        await cache.insert(raster(bytes: 128), for: "favicon:netflix.com")

        #expect(await cache.shape(for: "favicon:netflix.com") == raster(bytes: 128))
        #expect(await cache.byteCount == 128)
        #expect(await cache.shape(for: "missing") == nil)
    }

    @Test func theDefaultBudgetIsEightMegabytes() async {
        #expect(await IconCache().byteBudget == 8 * 1024 * 1024)
    }

    @Test func reinsertingAKeyDoesNotDoubleCountIt() async {
        let cache = IconCache()
        await cache.insert(raster(bytes: 100), for: "a")
        await cache.insert(raster(bytes: 40), for: "a")

        #expect(await cache.byteCount == 40)
        #expect(await cache.count() == 1)
    }

    @Test func theLeastRecentlyUsedEntryIsEvictedFirst() async {
        let cache = IconCache(byteBudget: 300)
        await cache.insert(raster(bytes: 100), for: "a")
        await cache.insert(raster(bytes: 100), for: "b")
        await cache.insert(raster(bytes: 100), for: "c")

        _ = await cache.shape(for: "a")
        await cache.insert(raster(bytes: 100), for: "d")

        #expect(await cache.shape(for: "b") == nil)
        #expect(await cache.shape(for: "a") != nil)
        #expect(await cache.shape(for: "c") != nil)
        #expect(await cache.shape(for: "d") != nil)
        #expect(await cache.byteCount <= 300)
    }

    @Test func aPayloadBiggerThanTheBudgetIsRefusedRatherThanClearingTheCache() async {
        let cache = IconCache(byteBudget: 200)
        await cache.insert(raster(bytes: 150), for: "keep")
        await cache.insert(raster(bytes: 900), for: "huge")

        #expect(await cache.shape(for: "huge") == nil)
        #expect(await cache.shape(for: "keep") != nil)
        #expect(await cache.byteCount == 150)
    }

    @Test func vectorPayloadsAreCostedByTheirPath() async {
        let path = String(repeating: "M0 0h4v4z", count: 10)
        let shape = BrandIconShape.vector(
            path: path,
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: .black
        )

        #expect(IconCache.cost(of: shape) == path.utf8.count + 64)
    }

    @Test func removeAllEmptiesTheAccounting() async {
        let cache = IconCache()
        await cache.insert(raster(bytes: 64), for: "a")
        await cache.removeAll()

        #expect(await cache.byteCount == 0)
        #expect(await cache.count() == 0)
    }
}
