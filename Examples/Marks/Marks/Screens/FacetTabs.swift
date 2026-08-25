import SwiftUI

struct FacetTabs: View {
    @Binding var selection: MarkFacet

    var body: some View {
        HStack(spacing: 20) {
            ForEach(MarkFacet.allCases) { facet in
                Button {
                    selection = facet
                } label: {
                    VStack(spacing: 6) {
                        Text(facet.rawValue)
                            .font(.system(size: 14, weight: selection == facet ? .semibold : .regular))
                            .foregroundStyle(selection == facet ? Palette.title : Palette.tertiary)
                        Rectangle()
                            .fill(selection == facet ? Palette.title : .clear)
                            .frame(height: 2)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Light") {
    FacetTabs(selection: .constant(.all)).padding().background(Palette.canvas)
}

#Preview("Dark") {
    FacetTabs(selection: .constant(.color))
        .padding().background(Palette.canvas).preferredColorScheme(.dark)
}
