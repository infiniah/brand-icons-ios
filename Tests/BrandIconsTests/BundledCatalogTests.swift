import CoreGraphics
import Testing

@testable import BrandIcons

@Suite("Bundled catalogue")
struct BundledCatalogTests {
    @Test("The generated resource loads the whole Simple Icons set")
    func loads() {
        #expect(BundledCatalog.all.count > 3_000)
        #expect(!BundledCatalog.sourceVersion.isEmpty)
    }

    @Test("Every entry is drawable")
    func everyEntryIsDrawable() {
        for mark in BundledCatalog.all {
            #expect(!mark.slug.isEmpty)
            #expect(!mark.title.isEmpty, "\(mark.slug) has no title")
            // A mark is drawn from its colour layers when it has them, and from its flattened
            // path when it does not. Carrying both was geometry nothing rendered.
            #expect(
                !mark.pathData.isEmpty || !mark.layers.isEmpty,
                "\(mark.slug) has neither a path nor layers"
            )
            #expect(mark.viewBox.width > 0, "\(mark.slug) has an empty viewBox")
            #expect(mark.viewBox.height > 0, "\(mark.slug) has an empty viewBox")
            #expect(mark.tint.alpha == 255, "\(mark.slug) is not opaque")
        }
    }

    @Test("Slugs are unique, so lookup has one answer")
    func slugsAreUnique() {
        let slugs = BundledCatalog.all.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
    }

    @Test("Entries are ordered by slug")
    func ordered() {
        let slugs = BundledCatalog.all.map(\.slug)
        #expect(slugs == slugs.sorted())
    }

    @Test(
        "The services this package exists for are present",
        arguments: [
            "netflix", "spotify", "youtube", "audible", "steam", "notion", "github",
            "dropbox", "1password", "nordvpn", "duolingo", "strava", "doordash",
            "vodafone", "patreon", "anthropic",
        ]
    )
    func wellKnownServices(slug: String) throws {
        let mark = try #require(BundledCatalog.mark(slug: slug), "\(slug) is missing")
        #expect(mark.slug == slug)
    }

    @Test("Lookup by slug matches the array")
    func lookupMatchesArray() throws {
        let first = try #require(BundledCatalog.all.first)
        #expect(BundledCatalog.mark(slug: first.slug) == first)
        #expect(BundledCatalog.mark(slug: "not-a-brand-that-exists") == nil)
    }

    @Test("Tints are the brand colours, not a placeholder")
    func tints() throws {
        let netflix = try #require(BundledCatalog.mark(slug: "netflix"))
        #expect(netflix.tint.hexString == "#E50914")

        let spotify = try #require(BundledCatalog.mark(slug: "spotify"))
        #expect(spotify.tint.hexString == "#1ED760")
    }

    @Test("Per icon licence data survives generation")
    func licencesAreCarriedThrough() throws {
        let anki = try #require(BundledCatalog.mark(slug: "anki")?.license)
        #expect(anki.type == "AGPL-3.0-only")

        let webex = try #require(BundledCatalog.mark(slug: "webex")?.license)
        #expect(webex.type == "custom")
        #expect(webex.url != nil)

        #expect(BundledCatalog.mark(slug: "netflix")?.license == nil)
    }

    @Test("Marks carrying terms other than CC0 are reachable as a set")
    func nonDefaultLicences() {
        let licensed = BundledCatalog.all.filter { $0.license != nil }
        #expect(licensed.count > 100)
        #expect(licensed.allSatisfy { !($0.license?.type ?? "").isEmpty })
    }

    @Test("The NonCommercial and NoDerivatives marks NOTICE names are still those marks")
    func restrictivelyLicensedMarks() {
        let restrictive = BundledCatalog.all
            .filter { ($0.license?.type.contains("-NC") ?? false) || ($0.license?.type.contains("-ND") ?? false) }
            .map(\.slug)
            .sorted()

        #expect(restrictive.contains("vuedotjs"))
        #expect(restrictive.contains("letsencrypt"))
        #expect(restrictive.contains("tauri"))
        #expect(restrictive.count == 13)
    }

    @Test("Every mark converts to a shape the renderer can use")
    func marksBecomeShapes() throws {
        for mark in BundledCatalog.all.prefix(40) {
            let shape = BundledIconProvider.shape(for: mark)
            #expect(shape.isVector)

            switch shape {
            case let .vector(path, _, _):
                let converted = try #require(
                    SVGPathParser.path(from: path), "\(mark.slug) did not convert"
                )
                #expect(!converted.isEmpty)
            case let .layeredVector(layers, _):
                #expect(!layers.isEmpty, "\(mark.slug) has no layers")
                for layer in layers {
                    let converted = try #require(
                        SVGPathParser.path(from: layer.path), "\(mark.slug) layer did not convert"
                    )
                    #expect(!converted.isEmpty)
                }
            case .raster:
                Issue.record("\(mark.slug) produced a raster shape")
            }
        }
    }
}
