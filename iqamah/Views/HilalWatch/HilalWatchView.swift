import IqamahCore
import MapKit
import SwiftUI

@MainActor
struct HilalWatchView: View {
    @State private var selectedEvening: Evening = .d29
    @State private var selectedCriterion: HilalCriterionPicker.CriterionChoice = .odeh
    @State private var grid: ContiguousArray<Int8> = ContiguousArray(repeating: 1, count: HilalCalculator.cellCount)
    @State private var localCard: LocalSightingValues?
    @State private var isLoading = false
    @State private var showAbout = false
    @State private var newMoonDate: Date = Date()

    @EnvironmentObject private var settings: SettingsManager

    private var cityName: String { settings.activeCityName }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)

            Divider()

            // Map
            ZStack {
                HilalMapView(grid: grid)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Computing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                // Local card overlay (bottom-left)
                if let card = localCard {
                    VStack {
                        Spacer()
                        HStack {
                            LocalSightingCardView(values: card, criterionName: selectedCriterion.criterion.name)
                                .frame(maxWidth: 280)
                            Spacer()
                        }
                        .padding()
                    }
                }

                // About card peek-through
                if showAbout {
                    AboutHilalWatchCard(isPresented: $showAbout)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .task { await loadGrid() }
        .onChange(of: selectedEvening) { _, _ in Task { await loadGrid() } }
        .onChange(of: selectedCriterion) { _, _ in Task { await loadGrid() } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hilal Watch")
                    .font(.headline)
                Text(monthLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Evening tab picker
            Picker("Evening", selection: $selectedEvening) {
                Text("29th").tag(Evening.d29)
                Text("30th").tag(Evening.d30)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)

            HilalCriterionPicker(selectedCriterion: $selectedCriterion)

            Button {
                withAnimation { showAbout.toggle() }
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About Hilal Watch")
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: newMoonDate) + " — Confirms start of next Hijri month"
    }

    // MARK: - Grid loading

    private func loadGrid() async {
        isLoading = true
        defer { isLoading = false }

        // Find previous new moon relative to today
        let previousNewMoon = NewMoon.previous(before: Date())
        newMoonDate = previousNewMoon
        let jd = previousNewMoon.julianDay

        let req = HilalGridRequest(
            newMoonJD: jd,
            evening: selectedEvening,
            criterion: selectedCriterion.criterion
        )
        grid = await HilalCalculator.shared.computeGrid(req)

        // Compute local card if location is available
        if let coord = settings.activeCoordinate {
            let date = Date.fromJulianDay(jd + (selectedEvening == .d29 ? 1 : 2))
            localCard = HilalCalculator.shared.computeLocalCard(
                date: date,
                latitude: coord.latitude,
                longitude: coord.longitude,
                criterion: selectedCriterion.criterion
            )
        }
    }
}
