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
    @State private var selectedAppearance: AppAppearance
    // Scale is applied live; originalUiScale lets Cancel restore it
    private let originalUiScale = SettingsManager.shared.uiScale
    @ObservedObject private var settings = SettingsManager.shared
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
        _selectedAppearance = State(initialValue: SettingsManager.shared.appearance)
    }

    // MARK: - Body

    // Each section extracted so the type-checker handles them independently
    @ViewBuilder private var locationSection: some View {
        if let db = database {
            Picker("Country", selection: $selectedCountry) {
                Text("Select a country").tag(nil as Country?)
                ForEach(db.countries.sorted { $0.name < $1.name }) { c in
                    Text(c.name).tag(c as Country?)
                }
            }
            if selectedCountry != nil {
                Picker("City", selection: $selectedCity) {
                    Text("Select a city").tag(nil as City?)
                    ForEach(cities) { city in
                        Text(city.name).tag(city as City?)
                    }
                }
            }
        } else {
            ProgressView("Loading cities…")
        }
    }

    @ViewBuilder private var calculationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Method", selection: $selectedMethod) {
                ForEach(CalculationMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .onChange(of: selectedMethod) { _, _ in userOverrodeMethod = true }
            if let label = recommendationLabel, !userOverrodeMethod {
                Text(label).font(.caption).foregroundStyle(Color.accentColor)
            }
        }
        Picker("Asr Calculation", selection: $selectedAsrMethod) {
            ForEach(AsrJuristicMethod.allCases) { method in
                Text(method.displayName).tag(method)
            }
        }
        .pickerStyle(.radioGroup)
    }

    @ViewBuilder private var displaySection: some View {
        Toggle(isOn: $use24Hour) {
            VStack(alignment: .leading, spacing: 2) {
                Text("24-Hour Time")
                Text(use24Hour ? "e.g. 13:30" : "e.g. 1:30 PM")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        Toggle(isOn: $launchAtLogin) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Launch at Login")
                Text("Start Iqamah automatically when you log in")
                    .font(.caption).foregroundStyle(.secondary)
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
            } catch { launchAtLogin = !enabled }
        }
        Picker("Appearance", selection: $selectedAppearance) {
            ForEach(AppAppearance.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        displaySizeRow
    }

    private var displaySizeRow: some View {
        HStack {
            Text("Display Size")
            Spacer()
            Button {
                if settings.uiScale > SettingsManager.uiScaleMin {
                    settings.uiScale = (settings.uiScale - SettingsManager.uiScaleStep).rounded(toPlaces: 1)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(settings.uiScale > SettingsManager.uiScaleMin ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(settings.uiScale <= SettingsManager.uiScaleMin)
            Text("\(Int(settings.uiScale * 100))%")
                .font(.body.monospacedDigit()).frame(minWidth: 42, alignment: .center)
            Button {
                if settings.uiScale < SettingsManager.uiScaleMax {
                    settings.uiScale = (settings.uiScale + SettingsManager.uiScaleStep).rounded(toPlaces: 1)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(settings.uiScale < SettingsManager.uiScaleMax ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(settings.uiScale >= SettingsManager.uiScaleMax)
            if settings.uiScale != 1.0 {
                Button("Reset") { settings.uiScale = 1.0 }
                    .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
    }

    private var settingsForm: AnyView {
        AnyView(
            Form {
                Section("Location") { locationSection }
                Section("Calculation") { calculationSection }
                Section("Display") { displaySection }
            }
            .formStyle(.grouped)
        )
    }

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

            settingsForm

            // ── Action buttons ───────────────────────────────────────
            HStack(spacing: 12) {
                Button("Cancel") {
                    SettingsManager.shared.uiScale = originalUiScale
                    onCancel()
                }
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
        .frame(width: 480)
        .frame(minHeight: 540, maxHeight: 700)
        .background {
            Rectangle().fill(.regularMaterial)
        }
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
        SettingsManager.shared.appearance = selectedAppearance
        onSave(city, selectedMethod, selectedAsrMethod)
    }
}
