import Foundation

/// A place icons can come from.
///
/// Providers return *candidates*, not a single answer, and never throw for "no match":
/// an empty array is a normal result. They throw only when something went wrong that the
/// caller might act on, such as being rate limited.
public protocol BrandIconProvider: Sendable {
    var source: BrandIconSource { get }

    /// Candidates for a free-text service name. May be empty.
    func candidates(for query: BrandQuery) async throws -> [BrandIconCandidate]

    /// Fetches the drawable payload for a candidate this provider produced.
    func shape(for candidate: BrandIconCandidate) async throws -> BrandIconShape
}
