import BrandIcons
import SwiftUI

/// One icon the resolver offered, as a row you pick.
///
/// A sibling of Public's ticker search: leading mark, name in bold, a grey line naming where it
/// came from, and the selection control on the trailing edge.
///
/// The source is named before the score: a store icon and a flattened catalogue mark are
/// different kinds of answer even when both score 1.00.
struct CandidateRow: View {
    let candidate: BrandIconCandidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            BrandIconView(candidate: candidate, fallbackText: candidate.title, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.title)
                    .lineLimit(1)
                Text("\(candidate.source.label) · \(percentage) match")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .strokeBorder(Palette.hairline, lineWidth: 1.5)
                    .opacity(isSelected ? 0 : 1)
                Circle()
                    .fill(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(width: 24, height: 24)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var percentage: String {
        "\(Int((candidate.confidence * 100).rounded()))%"
    }
}
