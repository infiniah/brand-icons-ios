import BrandIcons
import SwiftUI

/// Lets a person pick the right mark when the resolver is not sure.
///
/// Composition follows Google's "Results from Google Search" sheet: a left aligned title, then
/// rows of artwork, name, a secondary line, and the match percentage as plain metadata rather
/// than an emphasised badge. Comparing many candidates is the case where a loud pill on every
/// row would be noise.
struct IconChooserSheet: View {
    let query: String
    let candidates: [BrandIconCandidate]
    let chosen: BrandIconCandidate?
    let onPick: (BrandIconCandidate?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header

                    ForEach(candidates) { candidate in
                        Button {
                            onPick(candidate)
                            dismiss()
                        } label: {
                            row(for: candidate)
                        }
                        .buttonStyle(.plain)

                        Divider().foregroundStyle(Palette.hairline)
                    }

                    if candidates.isEmpty {
                        Text("Nothing matched \(query).")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                }
            }
            .background(Palette.canvas)
            .navigationTitle("Choose an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Results for \(query)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.title)
            Text("Ranked by how well each brand matched the name.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func row(for candidate: BrandIconCandidate) -> some View {
        HStack(spacing: 14) {
            BrandIconView(candidate: candidate, fallbackText: candidate.title, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.title)
                Text(candidate.source.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                Text("\(Int((candidate.confidence * 100).rounded()))% match")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.tertiary)
            }

            Spacer(minLength: 8)

            if candidate == chosen {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.title)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
