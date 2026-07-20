#if os(iOS)
    import IqamahCore
    import MapKit
    import SwiftUI

    /// iOS presentation of Hilal Watch as a modal sheet.
    /// The macOS version uses a separate Window scene (HilalWatchWindow).
    struct HilalWatchSheet: View {
        @EnvironmentObject private var settings: SettingsManager
        @Environment(\.dismiss) private var dismiss
        @Environment(\.horizontalSizeClass) private var hSizeClass
        @ObservedObject private var preloader = HilalWatchPreloader.shared
        @State private var selectedEvening: Evening = .d29
        @State private var selectedCriterion: HilalCriterionPicker.CriterionChoice = .odeh
        @State private var grid: ContiguousArray<Int8> = ContiguousArray(
            repeating: 1, count: HilalCalculator.cellCount
        )
        @State private var localCard: LocalSightingValues?
        @State private var isLoading = false
        @State private var showAbout = false
        @State private var newMoonDate: Date = Date()
        /// Hides the live MKMapView while the share sheet is visible to prevent the
        /// Metal command-buffer lifetime assertion that fires when two rendering surfaces
        /// interact during sheet animation.
        @State private var isExporting = false
        /// Rendered export image — set before showing the share sheet.
        @State private var exportItems: [Any]?

        var body: some View {
            NavigationStack {
                ZStack {
                    iOSVisibilityContent
                        .task {
                            // Use pre-computed data if available; otherwise compute now
                            if preloader.isReady {
                                grid = preloader.grid
                                localCard = preloader.localCard
                                newMoonDate = preloader.newMoonDate
                            } else {
                                await loadGrid()
                            }
                        }

                    if isLoading {
                        ProgressView("Computing\u{2026}")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    if showAbout {
                        AboutHilalWatchCard(isPresented: $showAbout)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .navigationTitle("Hilal Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            prepareAndExport()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export Hilal Map")
                        // XCUITest identifier (AC-0332, US-0067)
                        .accessibilityIdentifier("exportHilalButton")

                        Button {
                            withAnimation { showAbout.toggle() }
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("About Hilal Watch")
                    }
                }
                // ActivityController presented as a SwiftUI sheet — avoids UIKit VC traversal
                .sheet(isPresented: Binding(
                    get: { exportItems != nil },
                    set: {
                        if !$0 {
                            exportItems = nil; isExporting = false
                        }
                    }
                )) {
                    if let items = exportItems {
                        ActivityController(activityItems: items)
                    }
                }
            }
        }

        private var iOSVisibilityContent: some View {
            List {
                // Evening picker + criterion picker
                Section {
                    Picker("Evening", selection: $selectedEvening) {
                        Text("29th Evening").tag(Evening.d29)
                        Text("30th Evening").tag(Evening.d30)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedEvening) { _, _ in Task { await loadGrid() } }

                    HilalCriterionPicker(selectedCriterion: $selectedCriterion)
                        .onChange(of: selectedCriterion) { _, _ in Task { await loadGrid() } }
                }

                // Local sighting card
                if let card = localCard {
                    Section("Your Location") {
                        LocalSightingCardView(
                            values: card,
                            criterionName: selectedCriterion.criterion.name
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }

                // Global crescent visibility map — hidden while exporting to prevent
                // Metal command-buffer conflicts during share sheet animation.
                Section("Global Visibility") {
                    if isExporting {
                        Color.secondary.opacity(0.08)
                            .frame(height: hSizeClass == .regular ? 380 : 220)
                            .listRowInsets(EdgeInsets())
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        HilalMapView(grid: grid)
                            .frame(height: hSizeClass == .regular ? 380 : 220)
                            .listRowInsets(EdgeInsets())
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                // Summary statistics from grid
                Section("Global Summary") {
                    gridSummaryRows
                }
            }
        }

        private var gridSummaryRows: some View {
            let total = grid.count
            let aCount = grid.filter { $0 == Int8(VisibilityCategory.A.rawValue) }.count
            let bCount = grid.filter { $0 == Int8(VisibilityCategory.B.rawValue) }.count
            let cCount = grid.filter { $0 == Int8(VisibilityCategory.C.rawValue) }.count
            let dCount = total - aCount - bCount - cCount
            let pct = { (n: Int) in String(format: "%.0f%%", Double(n) / Double(total) * 100) }

            return Group {
                HStack {
                    Circle().fill(.green).frame(width: 10, height: 10)
                    Text("Easily visible")
                    Spacer()
                    Text(pct(aCount)).foregroundStyle(.secondary)
                }
                HStack {
                    Circle().fill(.teal).frame(width: 10, height: 10)
                    Text("Good conditions")
                    Spacer()
                    Text(pct(bCount)).foregroundStyle(.secondary)
                }
                HStack {
                    Circle().fill(.gray).frame(width: 10, height: 10)
                    Text("Optical aid needed")
                    Spacer()
                    Text(pct(cCount)).foregroundStyle(.secondary)
                }
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Not visible")
                    Spacer()
                    Text(pct(dCount)).foregroundStyle(.secondary)
                }
            }
        }

        private func loadGrid() async {
            isLoading = true
            defer { isLoading = false }
            let prev = NewMoon.previous(before: Date())
            newMoonDate = prev
            let req = HilalGridRequest(
                newMoonJD: prev.julianDay,
                evening: selectedEvening,
                criterion: selectedCriterion.criterion
            )
            grid = await HilalCalculator.shared.computeGrid(req)
            if let coord = settings.activeCoordinate {
                let date = Date.fromJulianDay(prev.julianDay + (selectedEvening == .d29 ? 1 : 2))
                localCard = HilalCalculator.shared.computeLocalCard(
                    date: date,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    criterion: selectedCriterion.criterion
                )
            }
        }

        // MARK: - Export

        /// Renders a branded summary card to UIImage and presents the system share sheet.
        /// The live MKMapView is hidden first to prevent Metal command-buffer conflicts
        /// during the share sheet slide-in animation.
        @MainActor
        private func prepareAndExport() {
            // 1. Hide the live map — prevents Metal drawable lifetime assertion
            isExporting = true

            // 2. Compute stats
            let total = grid.count
            let aCount = grid.filter { $0 == Int8(VisibilityCategory.A.rawValue) }.count
            let bCount = grid.filter { $0 == Int8(VisibilityCategory.B.rawValue) }.count
            let cCount = grid.filter { $0 == Int8(VisibilityCategory.C.rawValue) }.count
            let dCount = total - aCount - bCount - cCount
            let evening = selectedEvening == .d29 ? "29th Evening" : "30th Evening"

            // 3. Render summary card to UIImage using ImageRenderer (no Metal GPU involved)
            let card = HilalExportCard(
                evening: evening,
                criterion: selectedCriterion.criterion.name,
                aCount: aCount, bCount: bCount, cCount: cCount, dCount: dCount, total: total
            )
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            let image = renderer.uiImage

            // 4. Build share payload — image + text fallback
            let text = "Hilal Watch · \(evening) · \(String(format: "%.0f%%", Double(aCount) / Double(total) * 100)) of globe easily visible · via Iqamah"
            var items: [Any] = [text]
            if let img = image {
                items.insert(img, at: 0)
            }
            exportItems = items
        }
    }

    // MARK: - Export card rendered by ImageRenderer

    /// Branded summary card: rendered to UIImage for sharing, so it's always crisp
    /// and avoids interacting with the live MKMapView's Metal rendering.
    private struct HilalExportCard: View {
        let evening: String
        let criterion: String
        let aCount: Int
        let bCount: Int
        let cCount: Int
        let dCount: Int
        let total: Int

        private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("Hilal Watch")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(gold)
                    Spacer()
                    Text("Iqamah")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(gold.opacity(0.7))
                }

                Text("\(evening) · \(criterion)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Divider().overlay(gold.opacity(0.25))

                // Visibility bars
                VStack(spacing: 8) {
                    exportBar(label: "Easily visible", count: aCount, color: .green)
                    exportBar(label: "Good conditions", count: bCount, color: .teal)
                    exportBar(label: "Optical aid", count: cCount, color: Color(white: 0.6))
                    exportBar(label: "Not visible", count: dCount, color: .red)
                }

                Text("Global crescent visibility · \(Date(), style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(width: 540)
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
        }

        private func exportBar(label: String, count: Int, color: Color) -> some View {
            let pct = total > 0 ? Double(count) / Double(total) : 0
            return HStack(spacing: 10) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(label).font(.caption.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                        Capsule().fill(color).frame(width: geo.size.width * pct, height: 6)
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - UIActivityViewController wrapper

    /// Presents UIActivityViewController as a SwiftUI-managed sheet.
    /// Because it's presented via SwiftUI's .sheet() rather than imperatively,
    /// there is no UIKit VC-hierarchy traversal and no "already presenting" conflicts.
    private struct ActivityController: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
