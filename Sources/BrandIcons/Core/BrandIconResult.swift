import Foundation

/// Everything the resolver found for one query, best first.
public struct BrandIconResult: Hashable, Sendable {
    /// The query as it was asked, before normalisation.
    public let query: String

    /// Candidates sorted by descending confidence. May be empty.
    public let candidates: [BrandIconCandidate]

    public init(query: String, candidates: [BrandIconCandidate]) {
        self.query = query
        self.candidates = candidates.sorted { $0.confidence > $1.confidence }
    }

    /// The single best candidate, if one clears `minimum`.
    ///
    /// Pick a threshold from what a wrong answer costs you. A dashboard that can show a
    /// letter tile instead is happy at 0.5. A flow that writes the choice to a database
    /// should ask the person below roughly 0.8.
    public func best(minimum: Double = 0.5) -> BrandIconCandidate? {
        guard let first = candidates.first, first.confidence >= minimum else { return nil }
        return first
    }

    /// True when the top two candidates are close enough that picking silently is a guess.
    ///
    /// This is the signal to show a chooser. `Apple One` matching both `apple` and
    /// `applemusic` is the case it exists for.
    public func isAmbiguous(within margin: Double = 0.15) -> Bool {
        guard candidates.count >= 2 else { return false }
        return candidates[0].confidence - candidates[1].confidence < margin
    }

    public static func empty(query: String) -> BrandIconResult {
        BrandIconResult(query: query, candidates: [])
    }
}
