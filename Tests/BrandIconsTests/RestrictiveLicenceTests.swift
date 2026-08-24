import Testing
@testable import BrandIcons

@Suite("Restrictive licences")
struct RestrictiveLicenceTests {
    @Test("The restrictive set is exactly the marks forbidding commercial use or derivatives")
    func theSetIsWhatWeThink() {
        let slugs = Set(BundledCatalog.restrictivelyLicensed.map(\.slug))
        #expect(slugs == [
            "cocoapods", "gamebanana", "jpeg", "letsencrypt", "misskey", "nodebb",
            "pycqa", "robotframework", "rubocop", "sass", "slint", "tauri", "vuedotjs"
        ])
    }

    @Test("Attribution alone is not treated as restrictive")
    func attributionIsNotRestrictive() throws {
        let byAttribution = BundledCatalog.all.filter { $0.license?.type == "CC-BY-4.0" }
        for mark in byAttribution {
            #expect(mark.license?.isRestrictive == false, "\(mark.slug) counted as restrictive")
        }
    }

    @Test("The two catalogues partition the whole set")
    func partition() {
        let restrictive = BundledCatalog.restrictivelyLicensed.count
        let permissive = BundledCatalog.permissivelyLicensed.count
        #expect(restrictive + permissive == BundledCatalog.all.count)
        #expect(restrictive > 0)
    }

    @Test("Excluding them actually removes them from resolution")
    func exclusionReachesTheResolver() async {
        var configuration = ResolverConfiguration.offline
        configuration.excludesRestrictiveLicenses = true
        let guarded = BrandIconResolver(configuration: configuration)
        let permissive = BrandIconResolver(configuration: .offline)

        let blocked = await guarded.resolve("Vue.js").best(minimum: 0.5)
        let allowed = await permissive.resolve("Vue.js").best(minimum: 0.5)

        #expect(allowed?.slug == "vuedotjs", "control failed, got \(allowed?.slug ?? "nil")")
        #expect(blocked?.slug != "vuedotjs", "restrictive mark still resolved")
    }
}
