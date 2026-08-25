import BrandIcons
import SwiftUI

struct MarkSearchField: View {
    @Binding var query: String
    @Binding var variant: CatalogVariant

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.tertiary)

            TextField("Search marks", text: $query)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.tertiary)
                }
                .buttonStyle(.plain)
            }

            Button {
                variant = variant == .full ? .compact : .full
            } label: {
                Text(variant == .full ? "Full" : "Compact")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.title)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.canvas, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Light") {
    MarkSearchField(query: .constant(""), variant: .constant(.full))
        .padding()
        .background(Palette.canvas)
}

#Preview("Dark") {
    MarkSearchField(query: .constant("spotify"), variant: .constant(.compact))
        .padding()
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}
