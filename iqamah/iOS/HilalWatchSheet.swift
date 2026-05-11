#if os(iOS)
    import IqamahCore
    import MapKit
    import SwiftUI

    /// iOS presentation of Hilal Watch as a modal sheet.
    /// The macOS version uses a separate Window scene (HilalWatchWindow).
    struct HilalWatchSheet: View {
        @EnvironmentObject private var settings: SettingsManager
        @Environment(\.dismiss) private var dismiss
        @State private var selectedEvening: Evening = .d29
        @State private var selectedCriterion: HilalCriterionPicker.CriterionChoice = .odeh
        @State private var grid: ContiguousArray<Int8> = ContiguousArray(
            repeating: 1, count: HilalCalculator.cellCount
        )
        @State private var localCard: LocalSightingValues?
        @State private var isLoading = false
        @State private var showAbout = false
        @State private var newMoonDate: Date = Date()

        var body: some View {
            NavigationStack {
                ZStack {
                    // iOS v1: show a list summary instead of an interactive map
                    iOSVisibilityContent
                        .task { await loadGrid() }

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
                            Task { await shareGrid() }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share Hilal Map")

                        Button {
                            withAnimation { showAbout.toggle() }
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("About Hilal Watch")
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

        private func shareGrid() async {
            // Build a simple text summary for iOS share (full image export is macOS-only in v1)
            let total = grid.count
            let aCount = grid.filter { $0 == Int8(VisibilityCategory.A.rawValue) }.count
            let pct = String(format: "%.0f%%", Double(aCount) / Double(total) * 100)
            let text = "Hilal Watch \u{00B7} \(selectedEvening == .d29 ? "29th" : "30th") Evening \u{00B7} \(pct) of globe easily visible \u{00B7} via Iqamah"

            await MainActor.run {
                let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    vc.popoverPresentationController?.sourceView = rootVC.view
                    rootVC.present(vc, animated: true)
                }
            }
        }
    }
#endif
