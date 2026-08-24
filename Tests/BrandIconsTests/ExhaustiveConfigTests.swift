import Testing
@testable import BrandIcons

@Suite("Exhaustive configuration")
struct ExhaustiveConfigTests {
    @Test("The default configuration finds a bundled brand")
    func defaultFindsFigma() async {
        let resolver = BrandIconResolver(configuration: .offline)
        let result = await resolver.resolve("Figma")
        #expect(!result.candidates.isEmpty, "default/offline found nothing for Figma")
        print("OFFLINE Figma -> \(result.candidates.map { "\($0.slug):\(Int($0.confidence*100))" })")
    }

    @Test("The exhaustive configuration also finds it")
    func exhaustiveFindsFigma() async {
        let resolver = BrandIconResolver(configuration: .exhaustive)
        let result = await resolver.resolve("Figma")
        print("EXHAUSTIVE Figma -> \(result.candidates.map { "\($0.slug):\(Int($0.confidence*100))" })")
        #expect(!result.candidates.isEmpty, "exhaustive found nothing for Figma")
    }

    @Test("Exhaustive with the bundled provider only")
    func bundledOnly() async {
        let provider = BundledIconProvider()
        let found = try? await provider.candidates(for: BrandQuery(name: "Figma"))
        print("BUNDLED PROVIDER Figma -> \(found?.count ?? -1) candidates")
        #expect((found?.isEmpty == false), "bundled provider itself found nothing")
    }
}
