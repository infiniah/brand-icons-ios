import Foundation

/// Reads the `icons` array out of a Web App Manifest.
///
/// Relative `src` values resolve against the manifest's own URL rather than the site root,
/// which the spec is explicit about and which real sites depend on: a manifest served from
/// `/static/app.webmanifest` routinely points at `icons/icon-192.png` next to itself.
enum WebManifestParser {
    static func icons(in data: Data, manifestURL: URL) -> [DeclaredIcon] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["icons"] as? [[String: Any]] else { return [] }

        return entries.compactMap { entry in
            guard let source = entry["src"] as? String,
                  let url = URL(string: source, relativeTo: manifestURL)?.absoluteURL else { return nil }

            let purposes = Set((entry["purpose"] as? String ?? "any").split(separator: " ").map(String.init))
            guard !isMaskOnly(purposes) else { return nil }

            let sizes = entry["sizes"] as? String ?? ""
            let type = (entry["type"] as? String ?? "").lowercased()
            let scalable = type == "image/svg+xml"
                || url.pathExtension.lowercased() == "svg"
                || DeclaredIcon.declaresScalable(sizes)

            return DeclaredIcon(
                url: url,
                declaredPixelSize: DeclaredIcon.largestSquare(in: sizes),
                assumedPixelSize: 0,
                preference: preference(purposes: purposes, scalable: scalable)
            )
        }
    }

    /// A monochrome icon is an alpha mask with its colour discarded, so it is not the brand mark
    /// even though the manifest lists it alongside ones that are.
    private static func isMaskOnly(_ purposes: Set<String>) -> Bool {
        purposes.contains("monochrome") && !purposes.contains("any")
    }

    private static func preference(purposes: Set<String>, scalable: Bool) -> Int {
        if scalable { return 2 }
        if purposes.contains("maskable") && !purposes.contains("any") { return 1 }
        return 0
    }
}
