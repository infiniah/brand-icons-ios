import Foundation

/// The word a person would call a brand, taken from its domain.
///
/// `netflix.com` and `bbc.co.uk` both reduce to the brand rather than to a suffix, which is what
/// makes a domain scoreable against a free text name at all.
enum DomainLabel {
    static func secondLevel(of domain: String) -> String {
        let parts = BrandQuery.normalizeDomain(domain).split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return parts.first ?? "" }

        // `bbc.co.uk` puts the brand three labels from the end, not two. The list is the handful
        // of second level suffixes that actually appear in front of a two letter country code.
        let secondLevelSuffixes: Set<String> = ["co", "com", "net", "org", "ac", "gov", "edu"]
        if parts.count >= 3, parts[parts.count - 1].count == 2,
           secondLevelSuffixes.contains(parts[parts.count - 2]) {
            return parts[parts.count - 3]
        }
        return parts[parts.count - 2]
    }
}
