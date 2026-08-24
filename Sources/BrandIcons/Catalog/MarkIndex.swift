import Foundation

/// Narrows a catalogue to the handful of marks worth scoring.
///
/// Scoring every mark is fine at a few hundred and not at a few thousand: the edit distance
/// inside ``MatchScorer`` is quadratic in the string lengths, so the cost is linear in the
/// catalogue and it was measured at 130 milliseconds for 3,453 marks on a fast Mac. A list
/// resolving twenty rows would take seconds, and worse on a phone.
///
/// Two structures fix that without changing a single score:
///
/// - an exact map from normalised key to marks, which answers `Netflix` and `Spotify` without
///   scoring anything at all
/// - an inverted index from token to marks, so a query only ever scores marks that share a
///   word with it
///
/// A query whose tokens appear nowhere still falls back to the whole catalogue, because a
/// misspelling has no shared token and edit distance is exactly what should catch it. That
/// case is rare and slow rather than common and slow.
struct MarkIndex: Sendable {
    private let byKey: [String: [BundledMark]]
    private let byToken: [String: [BundledMark]]
    private let all: [BundledMark]

    init(marks: [BundledMark]) {
        all = marks

        var keys: [String: [BundledMark]] = [:]
        var tokens: [String: [BundledMark]] = [:]
        keys.reserveCapacity(marks.count)
        tokens.reserveCapacity(marks.count * 2)

        for mark in marks {
            // `Set` because a mark whose title normalises to its slug, which is most of them,
            // would otherwise be indexed under that one key twice and returned twice.
            for key in Set([mark.title, mark.slug].map(NameNormalizer.key)) where !key.isEmpty {
                keys[key, default: []].append(mark)
            }
            for token in Set(NameNormalizer.brandTokens(mark.title) + [mark.slug]) {
                guard !token.isEmpty else { continue }
                tokens[token, default: []].append(mark)
            }
        }

        byKey = keys
        byToken = tokens
    }

    /// Marks whose normalised key equals the query's exactly.
    func exactMatches(for query: String) -> [BundledMark] {
        byKey[NameNormalizer.key(query)] ?? []
    }

    /// The marks worth scoring for this query.
    ///
    /// Every mark sharing a token, plus the whole catalogue when nothing shares one.
    func shortlist(for query: String) -> [BundledMark] {
        let queryTokens = NameNormalizer.brandTokens(query)
        guard !queryTokens.isEmpty else { return all }

        var seen: Set<String> = []
        var shortlist: [BundledMark] = []

        for token in queryTokens {
            for mark in byToken[token] ?? [] where seen.insert(mark.slug).inserted {
                shortlist.append(mark)
            }
        }

        // A prefix hit catches "netflixcom" against "netflix" when nothing tokenised the same.
        if shortlist.isEmpty {
            let key = NameNormalizer.key(query)
            for mark in all where seen.insert(mark.slug).inserted {
                let markKey = NameNormalizer.key(mark.slug)
                if key.hasPrefix(markKey) || markKey.hasPrefix(key) { shortlist.append(mark) }
            }
        }

        return shortlist.isEmpty ? all : shortlist
    }
}
