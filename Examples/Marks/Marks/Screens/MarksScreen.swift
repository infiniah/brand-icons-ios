import BrandIcons
import SwiftUI

struct MarksScreen: View {
    @State private var model: MarksModel
    @State private var selected: BundledMark?

    init(query: String = "") {
        _model = State(initialValue: MarksModel(query: query))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Marks")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Palette.title)
                    Text(model.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondary)
                }
                MarkSearchField(query: $model.query, variant: $model.variant)
                FacetTabs(selection: $model.facet)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().overlay(Palette.hairline)

            if model.visible.isEmpty {
                empty
            } else {
                grid
            }
        }
        .background(Palette.canvas)
        .sheet(item: $selected) { mark in
            MarkDetailSheet(mark: mark) { selected = nil }
                .presentationDetents([.large])
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(model.visible, id: \.slug) { mark in
                    Button {
                        selected = mark
                    } label: {
                        MarkCell(mark: mark, size: 46)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("Nothing matches “\(model.query)”")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.title)
            Text("\(model.total.formatted()) marks searched")
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension BundledMark: @retroactive Identifiable {
    public var id: String { slug }
}

#Preview("Light") {
    MarksScreen()
}

#Preview("Dark") {
    MarksScreen().preferredColorScheme(.dark)
}

#Preview("Searching") {
    MarksScreen(query: "spot")
}

#Preview("No match") {
    MarksScreen(query: "zzzzzz")
}
