import BrandIcons
import SwiftUI

struct MarkCell: View {
    let mark: BundledMark
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            BrandIconView(
                candidate: BrandIconCandidate(
                    slug: mark.slug,
                    title: mark.title,
                    confidence: 1,
                    source: .bundled,
                    shape: BundledIconProvider.shape(for: mark)
                ),
                fallbackText: mark.title,
                size: size,
                surface: Palette.canvasLuminance(colorScheme)
            )
            Text(mark.slug)
                .font(.system(size: 10))
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Light") {
    HStack(spacing: 14) {
        ForEach(["figma", "spotify", "notion", "github"], id: \.self) { slug in
            if let mark = BundledCatalog.mark(slug: slug) {
                MarkCell(mark: mark, size: 46)
            }
        }
    }
    .padding()
    .background(Palette.canvas)
}

#Preview("Dark") {
    HStack(spacing: 14) {
        ForEach(["figma", "spotify", "notion", "github"], id: \.self) { slug in
            if let mark = BundledCatalog.mark(slug: slug) {
                MarkCell(mark: mark, size: 46)
            }
        }
    }
    .padding()
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}
