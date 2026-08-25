import BrandIcons
import SwiftUI

/// The list of applications.
///
/// Composition follows Revolut Business "Card requests": one grouped rounded card holding every
/// row, a leading icon, title with a secondary line, and a right aligned trailing stack. The
/// status treatment is Jira's, a filled categorical pill, because Applied and Interview and
/// Offer are states rather than prose.
struct ApplicationsScreen: View {
    @State private var model = ApplicationsModel()
    @State private var editing: Application?
    @State private var isAdding = ProcessInfo.processInfo.arguments.contains("-openAddSheet")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(model.applications.count) applications")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 20)

                    card
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
            .background(Palette.canvas)
            .navigationTitle("Applied")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add an application"))
                }
            }
            .sheet(isPresented: $isAdding) {
                AddApplicationSheet { application, icon in
                    model.add(application, icon: icon)
                }
            }
            .task { await model.resolveAll() }
            .sheet(item: $editing) { application in
                IconChooserSheet(
                    query: application.company,
                    candidates: model.resolution(for: application).alternatives,
                    chosen: model.resolution(for: application).chosen,
                    onPick: { model.choose($0, for: application) }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.applications.enumerated()), id: \.element.id) { index, application in
                ApplicationRow(
                    application: application,
                    resolution: model.resolution(for: application),
                    onTapIcon: { editing = application }
                )

                if index < model.applications.count - 1 {
                    Divider()
                        .foregroundStyle(Palette.hairline)
                        .padding(.leading, 68)
                }
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

}

#Preview("Applications") {
    ApplicationsScreen()
}

#Preview("Applications · dark") {
    ApplicationsScreen().preferredColorScheme(.dark)
}
