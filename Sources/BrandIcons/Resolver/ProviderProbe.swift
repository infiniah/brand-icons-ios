import Foundation

/// What one provider returned for a query, and how long it took.
///
/// Produced by ``BrandIconResolver/probe(_:)``. Use it to decide which tiers are worth
/// enabling for your data: a provider that answers in two milliseconds from a bundled
/// catalogue and one that answers in eight hundred over the network are not interchangeable,
/// and the right choice depends on names you actually have rather than on a benchmark.
public struct ProviderProbe: Sendable, Identifiable {
    public let source: BrandIconSource

    /// Wall clock time from asking to answering, including the network.
    public let duration: Duration

    /// What it found, best first. Empty is a normal answer.
    public let candidates: [BrandIconCandidate]

    /// Why it returned nothing, when it failed rather than simply not matching.
    public let failure: BrandIconError?

    public var id: String { source.rawValue }

    /// The best confidence this provider offered, or zero.
    public var topConfidence: Double { candidates.first?.confidence ?? 0 }

    /// Milliseconds, rounded, for display.
    public var milliseconds: Int {
        Int((Double(duration.components.seconds) * 1000)
            + (Double(duration.components.attoseconds) / 1_000_000_000_000_000))
    }

    public init(
        source: BrandIconSource,
        duration: Duration,
        candidates: [BrandIconCandidate],
        failure: BrandIconError? = nil
    ) {
        self.source = source
        self.duration = duration
        self.candidates = candidates
        self.failure = failure
    }
}
