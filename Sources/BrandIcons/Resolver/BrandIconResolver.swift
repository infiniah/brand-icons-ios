import Foundation

/// Resolves a service name to ranked brand icon candidates.
///
/// ```swift
/// let resolver = BrandIconResolver()
/// let result = try await resolver.resolve("NETFLIX.COM")
///
/// if let best = result.best(minimum: 0.8) {
///     draw(best)
/// } else if result.isAmbiguous() {
///     askTheUser(result.candidates)
/// }
/// ```
///
/// Providers are consulted cheapest first and the resolver stops early once a candidate is
/// good enough, so the common case never touches the network.
public actor BrandIconResolver {
    private let providers: [any BrandIconProvider]
    /// How this resolver was configured.
    ///
    /// Readable without awaiting the actor, so a caller can rank a list it assembled itself the
    /// same way ``resolve(_:)`` would have.
    public nonisolated let configuration: ResolverConfiguration
    private var cache: [String: BrandIconResult] = [:]

    /// The default stack: bundled marks, then the service's own favicon. The App Store provider
    /// is included only when the configuration allows it.
    public init(
        configuration: ResolverConfiguration = .default,
        providers: [any BrandIconProvider]? = nil
    ) {
        self.configuration = configuration
        if let providers {
            self.providers = providers
        } else {
            let catalogue = configuration.excludesRestrictiveLicenses
                ? BundledCatalog.permissivelyLicensed
                : BundledCatalog.all
            var stack: [any BrandIconProvider] = [BundledIconProvider(marks: catalogue)]
            if configuration.allowsNetwork {
                stack.append(FaviconProvider())
                if configuration.allowsAppStore {
                    stack.append(AppStoreProvider(isEnabled: true))
                }
            }
            self.providers = stack
        }
    }

    /// Ranked candidates for a free text service name.
    public func resolve(_ name: String) async -> BrandIconResult {
        await resolve(BrandQuery(name: name))
    }

    /// Ranked candidates for a query that may also carry a domain or a known slug.
    public func resolve(_ query: BrandQuery) async -> BrandIconResult {
        let key = cacheKey(for: query)
        if let cached = cache[key] { return cached }

        var collected: [BrandIconCandidate] = []

        for provider in providers {
            if let top = collected.first, top.confidence >= configuration.shortCircuitConfidence {
                break
            }
            guard let found = try? await provider.candidates(for: query) else { continue }
            collected.append(contentsOf: found)
            collected.sort { $0.confidence > $1.confidence }
        }

        let result = BrandIconResult(
            query: query.name,
            candidates: deduplicated(collected)
                .filter { $0.confidence >= configuration.minimumConfidence }
                .prefix(configuration.maximumCandidates)
                .map { $0 },
            preferring: configuration.effectivePreferredSources
        )
        cache[key] = result
        return result
    }

    /// Fetches the drawable payload for a candidate, if it does not already carry one.
    public func shape(for candidate: BrandIconCandidate) async throws -> BrandIconShape {
        if let shape = candidate.shape { return shape }
        guard let provider = providers.first(where: { $0.source == candidate.source }) else {
            throw BrandIconError.providerDisabled(candidate.source)
        }
        return try await provider.shape(for: candidate)
    }

    /// Asks every provider in parallel and reports what each one returned, with timings.
    ///
    /// This is the diagnostic path, not the resolution path. It deliberately ignores the
    /// short circuit so that a name the bundled catalogue already knows still reaches the
    /// network providers, which is the only way to compare them. Expect it to take as long
    /// as the slowest provider rather than as long as the best one.
    public func probe(_ query: BrandQuery) async -> [ProviderProbe] {
        await withTaskGroup(of: ProviderProbe.self) { group in
            for provider in providers {
                group.addTask {
                    let clock = ContinuousClock()
                    var found: [BrandIconCandidate] = []
                    var failure: BrandIconError?
                    let elapsed = await clock.measure {
                        do {
                            found = try await provider.candidates(for: query)
                        } catch let error as BrandIconError {
                            failure = error
                        } catch {
                            failure = .transport(String(describing: error))
                        }
                    }
                    return ProviderProbe(
                        source: provider.source,
                        duration: elapsed,
                        candidates: found.sorted { $0.confidence > $1.confidence },
                        failure: failure
                    )
                }
            }

            var probes: [ProviderProbe] = []
            for await probe in group { probes.append(probe) }
            return probes.sorted { lhs, rhs in
                if lhs.topConfidence != rhs.topConfidence { return lhs.topConfidence > rhs.topConfidence }
                return lhs.duration < rhs.duration
            }
        }
    }

    /// Empties the in-memory result cache.
    public func removeCachedResults() {
        cache.removeAll()
    }

    /// Keeps the highest scoring candidate per brand, so the same company arriving from two
    /// providers is offered once rather than twice.
    private func deduplicated(_ candidates: [BrandIconCandidate]) -> [BrandIconCandidate] {
        var seen: Set<String> = []
        var output: [BrandIconCandidate] = []
        for candidate in candidates {
            let identity = NameNormalizer.key(candidate.slug)
            guard !seen.contains(identity) else { continue }
            seen.insert(identity)
            output.append(candidate)
        }
        return output
    }

    private func cacheKey(for query: BrandQuery) -> String {
        [NameNormalizer.key(query.name), query.domain ?? "", query.slug ?? ""].joined(separator: "|")
    }
}
