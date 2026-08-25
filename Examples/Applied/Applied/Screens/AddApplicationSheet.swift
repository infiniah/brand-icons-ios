import BrandIcons
import SwiftUI

/// Add an application, by finding its icon.
///
/// Built as a search and pick, a sibling of Public's ticker search: a field at the top, then the
/// matches as full width rows with the mark leading and the selection on the trailing edge, then
/// one primary action. The per-tier timings sit behind a disclosure.
struct AddApplicationSheet: View {
    let onAdd: (Application, BrandIconCandidate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var company = ProcessInfo.processInfo.environment["APPLIED_QUERY"] ?? ""
    @State private var domain = ""
    @State private var role = ""
    @State private var status = ApplicationStatus.applied
    @State private var candidates: [BrandIconCandidate] = []
    @State private var chosen: BrandIconCandidate?

    /// Stops the exhaustive pass from overriding a candidate the user tapped.
    @State private var pickedManually = false
    @State private var isResolving = false
    @State private var searchTask: Task<Void, Never>?
    @State private var includesAppStore =
        ProcessInfo.processInfo.environment["APPLIED_APP_STORE"] == "1"
    @State private var probes: [ProviderProbe] = []
    @State private var showsComparison = false
    @State private var showsAllCandidates = false

    /// Bundled marks only. Answers instantly, so the list never sits empty while the network
    /// providers are still going.
    private let offlineResolver = BrandIconResolver(configuration: .offline)

    /// Every tier, every time.
    ///
    /// The default resolver stops as soon as the bundled catalogue answers confidently, so the
    /// network providers would never run for a name it already knows. This screen exists to
    /// compare them, so it asks all of them, which costs seconds rather than milliseconds.
    private func exhaustiveResolver() -> BrandIconResolver {
        var configuration = ResolverConfiguration.exhaustive
        configuration.allowsAppStore = includesAppStore
        return BrandIconResolver(configuration: configuration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    companyField
                    results
                    comparison
                    LabelledField(
                        label: "Role",
                        placeholder: "Senior Product Engineer",
                        text: $role
                    )
                    LabelledField(
                        label: "Website",
                        placeholder: "figma.com",
                        text: $domain,
                        hint: "Optional. A real domain lets the site's own icon outrank a flat mark.",
                        systemImage: "globe"
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: domain) { _, _ in resolve(company) }

                    storeToggle
                    statusPicker
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Palette.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if !company.isEmpty { resolve(company) }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: add) {
                    Text("Add application")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(company.trimmingCharacters(in: .whitespaces).count < 2)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
    }

    private var companyField: some View {
        LabelledField(
            label: "Company",
            placeholder: "Search a company",
            text: $company,
            hint: "Try Figma, Duolingo or a name off a bank statement",
            systemImage: "magnifyingglass"
        ) {
            if isResolving {
                ProgressView().controlSize(.small)
            } else if !company.isEmpty {
                Button {
                    company = ""
                    pickedManually = false
                    resolve("")
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .onChange(of: company) { _, value in
            pickedManually = false
            resolve(value)
        }
    }

    /// The matches, or an honest account of why there are none.
    ///
    /// Three at a time, because a chooser that runs off the screen buries everything under it.
    @ViewBuilder
    private var results: some View {
        if company.trimmingCharacters(in: .whitespaces).count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Icon")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .padding(.leading, 2)

                if candidates.isEmpty {
                    Text(isResolving ? "Looking…" : "No icon for that name yet. You can still add it.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    let visible = showsAllCandidates ? candidates : Array(candidates.prefix(3))
                    VStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, candidate in
                            Button {
                                chosen = candidate
                                pickedManually = true
                            } label: {
                                CandidateRow(candidate: candidate, isSelected: candidate == chosen)
                            }
                            .buttonStyle(.plain)

                            if index < visible.count - 1 {
                                Divider()
                                    .foregroundStyle(Palette.hairline)
                                    .padding(.leading, 74)
                            }
                        }

                        if candidates.count > 3 {
                            Button {
                                showsAllCandidates.toggle()
                            } label: {
                                Text(showsAllCandidates ? "Show fewer" : "\(candidates.count - 3) more")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    /// One line on how the answer was found, expanding into the per-tier detail.
    @ViewBuilder
    private var comparison: some View {
        if !probes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsComparison.toggle() }
                } label: {
                    HStack {
                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Text(showsComparison ? "Hide" : "Compare")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showsComparison {
                    TierComparison(probes: probes, isRunning: false)
                }
            }
        }
    }

    private var summary: String {
        let answered = probes.filter { !$0.candidates.isEmpty }
        let fastest = answered.min { $0.milliseconds < $1.milliseconds }
        let base = "\(answered.count) of \(probes.count) sources answered"
        guard let fastest else { return base }
        return base + " · fastest \(fastest.milliseconds) ms"
    }

    private var storeToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Search Apple's App Store", isOn: $includesAppStore)
                .font(.system(size: 15, weight: .medium))
                .onChange(of: includesAppStore) { _, _ in resolve(company) }

            Text("""
                Real app artwork, in colour. Apple's on every platform: Google Play publishes no \
                public search API. Apple limits the endpoint to roughly twenty requests a minute \
                and its terms describe the artwork as promotional material for store content, so \
                it is off by default.
                """)
                .font(.system(size: 12))
                .foregroundStyle(Palette.tertiary)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .padding(.leading, 2)

            Picker("Status", selection: $status) {
                ForEach(ApplicationStatus.allCases, id: \.self) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Debounced, and resolved in two passes.
    ///
    /// The bundled pass is synchronous in practice and shows something immediately. The
    /// exhaustive pass then asks every network provider, which takes seconds, and replaces the
    /// list when it arrives. Without the first pass the screen looks like it found nothing for
    /// as long as the slowest provider takes to time out.
    private func resolve(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let host = domain.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 2 else {
            candidates = []
            probes = []
            chosen = nil
            pickedManually = false
            isResolving = false
            return
        }

        let query = BrandQuery(name: trimmed, domain: host.isEmpty ? nil : host)

        searchTask = Task {
            defer { isResolving = false }
            isResolving = true

            let offlineResult = await offlineResolver.resolve(query)
            let bundled = await withShapes(offlineResult.candidates, using: offlineResolver)
            guard !Task.isCancelled else { return }
            candidates = bundled
            if !pickedManually { chosen = bundled.first }

            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let resolver = exhaustiveResolver()
            let measured = await resolver.probe(query)
            guard !Task.isCancelled else { return }

            var withArt: [ProviderProbe] = []
            for probe in measured {
                let shaped = await withShapes(probe.candidates, using: resolver)
                withArt.append(
                    ProviderProbe(
                        source: probe.source,
                        duration: probe.duration,
                        candidates: shaped,
                        failure: probe.failure
                    )
                )
            }
            guard !Task.isCancelled else { return }

            probes = withArt

            // Ranked through `BrandIconResult` rather than by confidence alone, so the store
            // preference applies here too. Sorting on confidence would put the flattened outline
            // of Figma above the real coloured app icon, since both are certainly Figma.
            let ranked = BrandIconResult(
                query: trimmed,
                candidates: withArt.flatMap(\.candidates),
                preferring: resolver.configuration.effectivePreferredSources,
                preferenceThreshold: resolver.configuration.preferenceThreshold
            )
            candidates = Array(ranked.candidates.filter { $0.confidence > 0 }.prefix(8))
            if !pickedManually { chosen = candidates.first }
        }
    }

    private func withShapes(
        _ candidates: [BrandIconCandidate],
        using resolver: BrandIconResolver
    ) async -> [BrandIconCandidate] {
        var output: [BrandIconCandidate] = []
        for candidate in candidates.prefix(8) {
            if candidate.shape == nil, let shape = try? await resolver.shape(for: candidate) {
                output.append(candidate.withShape(shape))
            } else {
                output.append(candidate)
            }
        }
        return output
    }

    private func add() {
        let name = company.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let host = domain.trimmingCharacters(in: .whitespaces)
        let application = Application(
            company: name,
            domain: host.isEmpty ? nil : host,
            role: role.isEmpty ? "Role not set" : role,
            status: status,
            appliedOn: Date()
        )
        onAdd(application, chosen)
        dismiss()
    }
}
