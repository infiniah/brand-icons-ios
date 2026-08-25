import Testing
@testable import BrandIcons

/// The two catalogues differ only in which marks they hold.
@Suite("Catalogue variants")
struct CatalogVariantTests {
    @Test("Both variants load, and compact is the smaller subset")
    func bothLoad() {
        let full = BundledCatalog.marks(.full)
        let compact = BundledCatalog.marks(.compact)

        #expect(full.count == 4770)
        #expect(compact.count == 4473)

        let fullSlugs = Set(full.map(\.slug))
        let compactSlugs = Set(compact.map(\.slug))
        #expect(compactSlugs.isSubset(of: fullSlugs), "compact holds a mark full does not")
    }

    @Test("A brand in both scores the same either way")
    func scoresMatch() async throws {
        for name in ["Figma", "Spotify", "NOTION LABS INC", "Microsoft"] {
            let fromFull = await BrandIconResolver(configuration: .offline, variant: .full)
                .resolve(BrandQuery(name: name))
            let fromCompact = await BrandIconResolver(configuration: .offline, variant: .compact)
                .resolve(BrandQuery(name: name))

            #expect(
                fromFull.candidates.first?.slug == fromCompact.candidates.first?.slug,
                "\(name) resolved differently"
            )
            #expect(
                fromFull.candidates.first?.confidence == fromCompact.candidates.first?.confidence,
                "\(name) scored differently"
            )
        }
    }

    @Test("What compact leaves out is illustration sized")
    func omissionsAreLarge() {
        let compactSlugs = Set(BundledCatalog.marks(.compact).map(\.slug))
        let omitted = BundledCatalog.marks(.full).filter { !compactSlugs.contains($0.slug) }

        #expect(omitted.count == 297)
        for mark in omitted {
            let bytes = mark.pathData.utf8.count
                + mark.layers.reduce(0) { $0 + $1.path.utf8.count }
            #expect(bytes > 4096, "\(mark.slug) is not larger than the cut off")
        }
    }
}
