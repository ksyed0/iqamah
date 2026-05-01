import SwiftUI
import ServiceManagement

/// Non-destructive settings sheet (US-0020).
/// All changes are held in local draft state until the user taps Save.
/// Cancel discards without touching UserDefaults or prayer adjustments.
struct SettingsSheetView: View {
    // MARK: - Inputs

    let currentCity: City
    let currentMethod: CalculationMethod
    let currentAsrMethod: AsrJuristicMethod

    // MARK: - Callbacks

    let onSave: (City, CalculationMethod, AsrJuristicMethod) -> Void
    let onCancel: () -> Void

    // MARK: - Draft state

    @State private var database: CitiesDatabase?
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var selectedMethod: CalculationMethod
    @State private var selectedAsrMethod: AsrJuristicMethod
    @State private var use24Hour: Bool
    @State private var uiScale: Double
    @State private var launchAtLogin = false

    // US-0031: track whether the user has manually changed the method
    @State private var userOverrodeMethod = false
    @State private var recommendationLabel: String? = nil

    // MARK: - Derived

    private var cities: [City] {
        guard let db = database, let country = selectedCountry else { return [] }
        return db.cities(forCountryCode: country.code)
    }

    private var canSave: Bool { selectedCity != nil }

    // MARK: - Init

    init(
        currentCity: City,
        currentMethod: CalculationMethod,
        currentAsrMethod: AsrJuristicMethod,
        onSave: @escaping (City, CalculationMethod, AsrJuristicMethod) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentCity = currentCity
        self.currentMethod = currentMethod
        self.currentAsrMethod = currentAsrMethod
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedMethod = State(initialValue: currentMethod)
        _selectedAsrMethod = State(initialValue: currentAsrMethod)
        _use24Hour = State(initialValue: SettingsManager.shared.use24HourTime)
        _uiScale = State(initialValue: SettingsManager.shared.uiScale)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack {
                Text("Settings")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider().padding(.horizontal, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ── Location section ─────────────────────────────
                    SectionHeader("Location")

                    VStack(alignment: .leading, spacing: 14) {
                        SettingsRow(label: "Country") {
                            if let db = database {
                                Picker("", selection: $selectedCountry) {
                                    Text("Select a country").tag(nil as Country?)
                                    ForEach(db.countries.sorted { $0.name < $1.name }) { c in
                                        Text(c.name).tag(c as Country?)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            } else {
                                ProgressView()
                            }
                        }

                        if selectedCountry != nil {
                            SettingsRow(label: "City") {
                                Picker("", selection: $selectedCity) {
                                    Text("Select a city").tag(nil as City?)
                                    ForEach(cities) { city in
                                        Text(city.name).tag(city as City?)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 28)

                    Divider().padding(.horizontal, 28)

                    // ── Calculation section ──────────────────────────
                    SectionHeader("Calculation")

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Calculation Method")
                                .font(.headline)
                            // US-0031: recommendation badge
                            if let label = recommendationLabel, !userOverrodeMethod {
                                Text(label)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            Picker("", selection: $selectedMethod) {
                                ForEach(CalculationMethod.allCases) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .onChange(of: selectedMethod) { _, _ in
                                userOverrodeMethod = true
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Asr Calculation")
                                .font(.headline)
                            Text("The Hanafi school uses a different shadow length calculation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedAsrMethod) {
                                ForEach(AsrJuristicMethod.allCases) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.radioGroup)
                        }
                    }
                    .padding(.horizontal, 28)

                    Divider().padding(.horizontal, 28)

                    // ── Display section ──────────────────────────────
                    SectionHeader("Display")

                    // BUG-0030: fixedSize prevents subtitle clipping; padding ensures
                    // the Display section is always reachable within the sheet's scroll area
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $use24Hour) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("24-Hour Time")
                                    .font(.headline)
                                Text(use24Hour ? "e.g. 13:30" : "e.g. 1:30 PM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .toggleStyle(.switch)

                        Divider()

                        Toggle(isOn: $launchAtLogin) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Launch at Login")
                                    .font(.headline)
                                Text("Start Iqamah automatically when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = !enabled
                            }
                        }

                        Divider()

                        // UI Scale
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Display Size")
                                .font(.headline)
                            Text("Scale the window and all UI elements")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Button(action: {
                                    if uiScale > SettingsManager.uiScaleMin {
                                        uiScale = (uiScale - SettingsManager.uiScaleStep)
                                            .rounded(toPlaces: 1)
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(
                                            uiScale > SettingsManager.uiScaleMin ? .accentColor : .secondary
                                        )
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .buttonStyle(.plain)
                                .disabled(uiScale <= SettingsManager.uiScaleMin)

                                Text("\(Int(uiScale * 100))%")
                                    .font(.body.monospacedDigit())
                                    .frame(minWidth: 42, alignment: .center)

                                Button(action: {
                                    if uiScale < SettingsManager.uiScaleMax {
                                        uiScale = (uiScale + SettingsManager.uiScaleStep)
                                            .rounded(toPlaces: 1)
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(
                                            uiScale < SettingsManager.uiScaleMax ? .accentColor : .secondary
                                        )
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .buttonStyle(.plain)
                                .disabled(uiScale >= SettingsManager.uiScaleMax)

                                if uiScale != 1.0 {
                                    Button("Reset") { uiScale = 1.0 }
                                        .font(.caption)
                                        .buttonStyle(.plain)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 20)
            }

            Divider().padding(.horizontal, 28)

            // ── Action buttons ───────────────────────────────────────
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 480, height: 660)
        .onAppear { loadInitialState() }
        .onChange(of: selectedCountry) { _, newCountry in
            guard let country = newCountry else { return }
            // Reset city when country changes
            if selectedCity?.countryCode != country.code {
                selectedCity = nil
            }
            // US-0031: suggest method for new country (only if user hasn't overridden)
            if !userOverrodeMethod {
                selectedMethod = CalculationMethod.suggested(forCountryCode: country.code)
            }
            recommendationLabel = CalculationMethod.recommendationLabel(forCountryCode: country.code)
        }
    }

    // MARK: - Helpers

    private func loadInitialState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // Load cities database
        if case let .success(db) = CitiesLoader.shared.load() {
            database = db
            // Pre-select the current city's country and city
            selectedCountry = db.country(forCode: currentCity.countryCode)
            selectedCity = currentCity
        }
        // Set recommendation label for current country (without treating it as override)
        recommendationLabel = CalculationMethod.recommendationLabel(
            forCountryCode: currentCity.countryCode
        )
        // If the current method matches the suggestion, don't mark as overridden
        let suggested = CalculationMethod.suggested(forCountryCode: currentCity.countryCode)
        userOverrodeMethod = (currentMethod != suggested)
    }

    private func save() {
        guard let city = selectedCity else { return }
        SettingsManager.shared.use24HourTime = use24Hour
        SettingsManager.shared.uiScale = uiScale
        onSave(city, selectedMethod, selectedAsrMethod)
    }
}

// MARK: - Sub-views

private struct SectionHeader: View {
    let title: String
    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, 28)
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            content()
        }
    }
}
