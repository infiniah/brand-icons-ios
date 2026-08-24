import Foundation
import Testing

@testable import BrandIcons

/// Measures the one cost the bundled catalogue has: decoding the whole JSON on first touch.
///
/// This suite is deliberately the only place that reads ``BundledCatalog/all`` first in a
/// fresh process, so run it on its own to get a true cold number:
///
///     swift test --filter BundledCatalogLoadTests
@Suite("Bundled catalogue loading")
struct BundledCatalogLoadTests {
    @Test("First access decodes the whole catalogue in well under a second")
    func coldLoad() {
        let started = DispatchTime.now().uptimeNanoseconds
        let count = BundledCatalog.all.count
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000

        print("BundledCatalog.all cold load: \(count) marks in \(String(format: "%.1f", elapsed)) ms")

        #expect(count > 3_000)
        #expect(elapsed < 1_000)
    }

    @Test("Later access is free")
    func warmLoad() {
        _ = BundledCatalog.all.count

        let started = DispatchTime.now().uptimeNanoseconds
        _ = BundledCatalog.mark(slug: "netflix")
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000

        #expect(elapsed < 5)
    }
}
