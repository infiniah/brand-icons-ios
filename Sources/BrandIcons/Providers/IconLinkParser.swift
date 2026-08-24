import Foundation

/// Reads icon and manifest declarations out of a document head.
///
/// Sites that build their assets put icons at hashed or CDN paths that guessing never reaches,
/// and those paths only exist in the markup. This reads the `<link>` tags rather than trying to
/// understand the page, so it does not need to be a real HTML parser.
enum IconLinkParser {
    struct Declarations: Sendable {
        var icons: [DeclaredIcon] = []
        var manifestURL: URL?
    }

    private static let linkPattern = try? NSRegularExpression(
        pattern: "<link\\b[^>]*>",
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    private static let attributePattern = try? NSRegularExpression(
        pattern: "([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))",
        options: []
    )

    static func declarations(in markup: String, documentURL: URL) -> Declarations {
        guard let linkPattern else { return Declarations() }

        var found = Declarations()
        let range = NSRange(markup.startIndex..<markup.endIndex, in: markup)

        for match in linkPattern.matches(in: markup, range: range) {
            guard let tagRange = Range(match.range, in: markup) else { continue }
            let attributes = attributes(in: String(markup[tagRange]))

            guard let relation = attributes["rel"]?.lowercased(),
                  let reference = attributes["href"],
                  let url = URL(string: reference.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: documentURL)?.absoluteURL
            else { continue }

            let relations = Set(relation.split(separator: " ").map(String.init))
            if relations.contains("manifest") {
                found.manifestURL = found.manifestURL ?? url
                continue
            }

            guard let preference = iconPreference(relations) else { continue }
            let sizes = attributes["sizes"] ?? ""
            let scalable = url.pathExtension.lowercased() == "svg"
                || (attributes["type"] ?? "").lowercased() == "image/svg+xml"

            found.icons.append(
                DeclaredIcon(
                    url: url,
                    declaredPixelSize: DeclaredIcon.largestSquare(in: sizes),
                    assumedPixelSize: assumedSize(relations),
                    preference: scalable ? 2 : preference
                )
            )
        }

        found.icons.sort(by: DeclaredIcon.betterFirst)
        return found
    }

    /// `nil` for a `rel` this provider has no use for.
    ///
    /// `mask-icon` is Safari's pinned tab glyph: a single colour silhouette, so it is skipped
    /// for the same reason a monochrome manifest icon is.
    private static func iconPreference(_ relations: Set<String>) -> Int? {
        if relations.contains("apple-touch-icon") { return 0 }
        if relations.contains("apple-touch-icon-precomposed") { return 1 }
        if relations.contains("icon") { return 2 }
        return nil
    }

    private static func assumedSize(_ relations: Set<String>) -> Int {
        if relations.contains("apple-touch-icon") || relations.contains("apple-touch-icon-precomposed") {
            return 180
        }
        return 32
    }

    private static func attributes(in tag: String) -> [String: String] {
        guard let attributePattern else { return [:] }

        var found: [String: String] = [:]
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        for match in attributePattern.matches(in: tag, range: range) {
            guard let nameRange = Range(match.range(at: 1), in: tag) else { continue }
            let value = (2...4)
                .compactMap { Range(match.range(at: $0), in: tag) }
                .first
                .map { String(tag[$0]) } ?? ""
            found[String(tag[nameRange]).lowercased()] = value
        }
        return found
    }
}
