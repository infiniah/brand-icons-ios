import Foundation

/// Turns the many ways a service gets written into something comparable.
///
/// Real inputs are messy: a bank statement says `NETFLIX.COM`, an Apple receipt says
/// `Apple Music (Family)`, a person types `netflix`. All three should reach the same brand.
public enum NameNormalizer {
    /// Words that describe a *tier* rather than a *brand*.
    ///
    /// These are stripped for matching but kept in ``qualifiers(in:)``, because they are
    /// exactly what separates two real brands: `Apple Music` and `Apple TV` share a root
    /// and are not the same product.
    static let tierWords: Set<String> = [
        "plus", "premium", "pro", "family", "individual", "student", "duo", "basic",
        "standard", "unlimited", "annual", "monthly", "yearly", "subscription", "plan",
        "membership", "trial", "tier", "account"
    ]

    /// Noise a payment processor bolts onto a descriptor, safe to drop anywhere it appears.
    static let processorNoise: Set<String> = [
        "com", "www", "inc", "ltd", "llc", "co", "corp", "gmbh", "bv", "sa", "ag",
        "payment", "payments", "recurring", "autopay", "bill", "billing", "purchase"
    ]

    /// Processors that are also real brands.
    ///
    /// `APPLE.COM/BILL SPOTIFY` is Spotify, so the leading `apple` is noise. `Apple TV` is
    /// Apple, so the same token is the brand. Position alone does not separate them, since
    /// both lead. What separates them is what follows: a descriptor puts processor noise
    /// after the prefix, and a brand name does not.
    static let processorPrefixes: Set<String> = [
        "apple", "google", "paypal", "stripe", "sq", "sumup", "chk", "pos"
    ]

    /// Lowercased, diacritic free, punctuation collapsed to single spaces.
    public static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Word tokens, with processor noise removed.
    ///
    /// `APPLE.COM/BILL SPOTIFY` becomes `["spotify"]`, which is the only useful token in it.
    public static func tokens(_ raw: String, keepingProcessorNoise: Bool = false) -> [String] {
        let words = normalize(raw).split(separator: " ").map(String.init)
        guard !keepingProcessorNoise else { return words }

        var kept = words
        if let lead = words.first, processorPrefixes.contains(lead), words.count > 1,
           processorNoise.contains(words[1]) {
            kept = Array(words.dropFirst())
        }

        let meaningful = kept.filter { !processorNoise.contains($0) }
        // Falling back to the kept words matters for a descriptor that is *only* noise,
        // such as a bare "APPLE.COM", where "apple" really is the brand.
        return meaningful.isEmpty ? kept : meaningful
    }

    /// Brand tokens only, with tier words removed.
    public static func brandTokens(_ raw: String) -> [String] {
        let all = tokens(raw)
        let stripped = all.filter { !tierWords.contains($0) }
        return stripped.isEmpty ? all : stripped
    }

    /// The tier words present, in order. `Kalend Plus` reports `["plus"]`.
    public static func qualifiers(in raw: String) -> [String] {
        tokens(raw, keepingProcessorNoise: true).filter { tierWords.contains($0) }
    }

    /// The comparable key: brand tokens, joined, no spaces.
    public static func key(_ raw: String) -> String {
        brandTokens(raw).joined()
    }
}
