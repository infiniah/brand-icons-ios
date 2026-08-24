import Foundation

/// Scores how well a query names a brand, 0 to 1.
///
/// The number is meant to be *acted on*, so it is built from signals that can be explained
/// rather than a single fuzzy distance. In descending order of trust:
///
/// 1. the normalised keys are identical
/// 2. every brand token of one appears in the other
/// 3. tokens overlap partially
/// 4. the strings are merely close in edit distance
///
/// A tier word that appears on one side and not the other applies a penalty, because
/// `Apple Music` and `Apple TV` must not collapse into `Apple`.
public enum MatchScorer {
    /// Score `query` against a brand's canonical `name`, optionally also its `slug`.
    public static func score(query: String, name: String, slug: String? = nil) -> Double {
        let queryKey = NameNormalizer.key(query)
        guard !queryKey.isEmpty else { return 0 }

        var best = 0.0
        for target in [name, slug].compactMap({ $0 }) {
            best = max(best, rawScore(queryKey: queryKey, query: query, target: target))
        }
        return min(max(best, 0), 1)
    }

    private static func rawScore(queryKey: String, query: String, target: String) -> Double {
        let targetKey = NameNormalizer.key(target)
        guard !targetKey.isEmpty else { return 0 }

        if queryKey == targetKey { return 1.0 - qualifierPenalty(query: query, target: target) }

        let queryTokens = Set(NameNormalizer.brandTokens(query))
        let targetTokens = Set(NameNormalizer.brandTokens(target))

        var structural = 0.0
        if !queryTokens.isEmpty, !targetTokens.isEmpty {
            let ratio = Double(min(queryTokens.count, targetTokens.count))
                / Double(max(queryTokens.count, targetTokens.count))

            if targetTokens.isSubset(of: queryTokens) {
                // The query carries extra words the brand does not, which is what a statement
                // descriptor looks like: "SPOTIFY USA" is Spotify with a region bolted on.
                structural = 0.72 + 0.18 * ratio
            } else if queryTokens.isSubset(of: targetTokens) {
                // The brand carries extra words the query does not, so the brand is the more
                // specific thing. "Apple" is not "Apple TV". Every sibling scores the same
                // here, which is deliberate: the honest answer is that it is ambiguous, and
                // `BrandIconResult.isAmbiguous` is what the caller should act on.
                structural = 0.42 + 0.18 * ratio
            } else {
                // Partial overlap. Two products of the same parent share only the parent
                // token, so this has to stay below the threshold a caller would auto pick at.
                let shared = queryTokens.intersection(targetTokens).count
                if shared > 0 {
                    let union = queryTokens.union(targetTokens).count
                    structural = 0.38 + 0.3 * (Double(shared) / Double(union))
                }
            }
        }

        // Substring containment on the joined key catches "netflixcom" against "netflix".
        //
        // It is deliberately weak. A query that is merely a prefix of a longer brand is
        // usually a different brand: "Apple" is not "Apple TV", and scoring it confidently
        // makes the resolver pick whichever sibling slug happens to be shortest.
        // The floor and the ratio gate are both load bearing. Without them a brand literally
        // named "E" is contained in "sqbluebottle" and scores 0.30, which is above the default
        // minimum, so every unmatched descriptor picks up a junk single letter candidate.
        if structural == 0 {
            let shorter = min(queryKey.count, targetKey.count)
            let ratio = Double(shorter) / Double(max(queryKey.count, targetKey.count))
            if shorter >= 3, ratio >= 0.5,
               queryKey.contains(targetKey) || targetKey.contains(queryKey) {
                structural = 0.28 + 0.24 * ratio
            }
        }

        let similarity = 1 - normalizedEditDistance(queryKey, targetKey)
        // Edit distance alone is a weak signal, so it can never carry a match on its own.
        let fuzzy = similarity >= 0.82 ? similarity * 0.6 : 0

        return max(structural, fuzzy) - qualifierPenalty(query: query, target: target)
    }

    /// Penalises a tier word present on one side only.
    ///
    /// Without this, `Apple One` scores identically against `Apple TV` and `Apple Music`,
    /// and the resolver silently picks whichever sorted first.
    private static func qualifierPenalty(query: String, target: String) -> Double {
        let queryQualifiers = Set(NameNormalizer.qualifiers(in: query))
        let targetQualifiers = Set(NameNormalizer.qualifiers(in: target))
        if queryQualifiers == targetQualifiers { return 0 }
        let difference = queryQualifiers.symmetricDifference(targetQualifiers)
        return min(0.12, 0.06 * Double(difference.count))
    }

    /// Levenshtein distance divided by the longer length, so 0 is identical and 1 is unrelated.
    static func normalizedEditDistance(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 0 }
        if lhs.isEmpty || rhs.isEmpty { return 1 }

        let a = Array(lhs)
        let b = Array(rhs)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return Double(previous[b.count]) / Double(max(a.count, b.count))
    }
}
