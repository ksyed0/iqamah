import SwiftUI
#if os(macOS)
    import ServiceManagement
#endif
import CoreLocation
import IqamahCore

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
    #if os(macOS)
        @State private var launchAtLogin = false
    #endif
    @State private var isDetectingLocation = false
    @StateObject private var locationService = LocationService()
    @State private var detectedLocationInfo: String? = nil // inline result text

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
        // GPS detect button — fixed layout so it never changes height
        HStack(spacing: 8) {
            Button(action: detectLocation) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text("Detect my location")
                }
            }
            .disabled(isDetectingLocation)

            if isDetectingLocation {
                ProgressView().controlSize(.small)
            }
        }

        // Inline result shown after detection
        if let info = detectedLocationInfo {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(info)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

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
                    // GPS-detected city injected at top when country matches
                    if let gpsCity = SettingsManager.shared.gpsDetectedCity,
                       gpsCity.countryCode == selectedCountry?.code {
                        Text("📍 \(gpsCity.name) (GPS)").tag(gpsCity as City?)
                    }
                    ForEach(cities) { city in
                        Text(city.name).tag(city as City?)
                    }
                }
            }
        } else {
            ProgressView("Loading cities…")
        }
    }

    private func detectLocation() {
        detectedLocationInfo = nil
        isDetectingLocation = true
        Task {
            do {
                let coordinate = try await locationService.requestLocationAsync()
                let lat = coordinate.latitude
                let lon = coordinate.longitude
                await MainActor.run {
                    SettingsManager.shared.locationSource = "gps"
                    SettingsManager.shared.saveGPSCoordinates(coordinate)
                    SettingsManager.shared.gpsTimezone = TimeZone.current.identifier
                    var detectedCityName = "Unknown"
                    var countryCode = "CA"
                    if let db = database, let nearestCity = db.closestCity(to: coordinate) {
                        detectedCityName = nearestCity.name
                        countryCode = nearestCity.countryCode
                        selectedCountry = db.country(forCode: nearestCity.countryCode)
                        if !userOverrodeMethod {
                            selectedMethod = CalculationMethod.suggested(forCountryCode: nearestCity.countryCode)
                            recommendationLabel = CalculationMethod.recommendationLabel(forCountryCode: nearestCity.countryCode)
                        }
                    }
                    // Create and cache GPS city so it appears in the dropdown
                    let gpsCity = try? City(name: detectedCityName, countryCode: countryCode,
                                            latitude: lat, longitude: lon,
                                            timezone: TimeZone.current.identifier)
                    SettingsManager.shared.gpsDetectedCity = gpsCity
                    selectedCity = gpsCity
                    let latStr = String(format: "%.4f°%@", abs(lat), lat >= 0 ? "N" : "S")
                    let lonStr = String(format: "%.4f°%@", abs(lon), lon >= 0 ? "E" : "W")
                    detectedLocationInfo = "📍 \(detectedCityName) — \(latStr), \(lonStr)"
                    isDetectingLocation = false
                }
                // ENH-001 Option B: CLGeocoder refines locality name
                CLGeocoder().reverseGeocodeLocation(
                    CLLocation(latitude: lat, longitude: lon)
                ) { placemarks, _ in
                    guard let placemark = placemarks?.first else { return }
                    let locality = placemark.locality ?? placemark.name
                    let tz = placemark.timeZone?.identifier ?? TimeZone.current.identifier
                    DispatchQueue.main.async {
                        let finalName = locality ?? SettingsManager.shared.gpsLocality
                        if let locality { SettingsManager.shared.gpsLocality = locality }
                        SettingsManager.shared.gpsTimezone = tz
                        // Update GPS city cache with refined name and timezone
                        if let db = database,
                           let nearest = db.closestCity(to: CLLocationCoordinate2D(latitude: lat, longitude: lon)),
                           let refined = try? City(name: finalName, countryCode: nearest.countryCode,
                                                   latitude: lat, longitude: lon, timezone: tz) {
                            SettingsManager.shared.gpsDetectedCity = refined
                            selectedCity = refined
                        }
                        let latStr = String(format: "%.4f°%@", abs(lat), lat >= 0 ? "N" : "S")
                        let lonStr = String(format: "%.4f°%@", abs(lon), lon >= 0 ? "E" : "W")
                        detectedLocationInfo = "📍 \(finalName) — \(latStr), \(lonStr)"
                    }
                }
            } catch {
                await MainActor.run {
                    isDetectingLocation = false
                    detectedLocationInfo = "Location unavailable — select city manually"
                }
            }
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
        #if os(macOS)
        .pickerStyle(.radioGroup)
        #else
        .pickerStyle(.segmented)
        #endif
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
        #if os(macOS)
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
        #endif
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
            .accessibilityLabel("Decrease display size")
            Text("\(Int(settings.uiScale * 100))%")
                .font(.body.monospacedDigit()).frame(minWidth: 42, alignment: .center)
                .accessibilityLabel("Display size \(Int(settings.uiScale * 100)) percent")
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
            .accessibilityLabel("Increase display size")
            if settings.uiScale != 1.0 {
                Button("Reset") { settings.uiScale = 1.0 }
                    .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Reset display size to default")
            }
        }
    }

    private static let adjustmentPrayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    // Calculated prayer times using current draft city/method/asr
    private var previewTimes: PrayerTimes? {
        guard let city = selectedCity,
              let tz = TimeZone(identifier: city.timezone)
        else { return nil }
        return try? PrayerCalculator(
            coordinate: city.coordinate,
            timezone: tz,
            method: selectedMethod,
            asrMethod: selectedAsrMethod
        ).calculate(for: Date())
    }

    @ViewBuilder private var adjustmentsSection: some View {
        HStack(spacing: 0) {
            Text("Prayer").frame(maxWidth: .infinity, alignment: .leading)
            Text("Calc'd").frame(width: 66, alignment: .trailing)
            Text("Adj").frame(width: 86, alignment: .center)
            Text("Final").frame(width: 66, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        ForEach(Self.adjustmentPrayerNames, id: \.self) { prayerName in
            let fmt = selectedCity.flatMap { TimeZone(identifier: $0.timezone) }
                .map { PrayerTimes.timeFormatter(for: $0, use24Hour: use24Hour) }
            let baseTime: Date? = {
                guard let t = previewTimes else { return nil }
                switch prayerName {
                case "Fajr": return t.fajr
                case "Dhuhr": return t.dhuhr
                case "Asr": return t.asr
                case "Maghrib": return t.maghrib
                case "Isha": return t.isha
                default: return nil
                }
            }()
            SettingsAdjustmentRow(prayerName: prayerName, baseTime: baseTime, formatter: fmt)
        }
    }

    private var settingsForm: some View {
        Form {
            Section { locationSection } header: { Label("Location", systemImage: "location.fill") }
            Section { calculationSection } header: { Label("Calculation", systemImage: "function") }
            Section { displaySection } header: { Label("Display", systemImage: "display") }
            Section {
                adjustmentsSection
            } header: {
                Label("Adjustments", systemImage: "timer")
            } footer: {
                HStack {
                    Button("Reset all adjustments") {
                        SettingsManager.shared.resetAdjustments()
                    }
                    .foregroundStyle(.red)
                    .font(.footnote)
                    Spacer()
                    Text("Calc'd → adj → Final")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
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

            ScrollView {
                settingsForm
            }

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
        #if os(macOS)
        .frame(width: 480, height: min((NSScreen.main?.visibleFrame.height ?? 900) - 80, 820))
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
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
        #if os(macOS)
            launchAtLogin = SMAppService.mainApp.status == .enabled
        #endif

        // Load cities database
        if case let .success(db) = CitiesLoader.shared.load() {
            database = db
            selectedCountry = db.country(forCode: currentCity.countryCode)
            // If the current city is the GPS-detected city, restore it
            if SettingsManager.shared.locationSource == "gps",
               let gpsCity = SettingsManager.shared.gpsDetectedCity,
               gpsCity.countryCode == currentCity.countryCode {
                selectedCity = gpsCity
            } else {
                selectedCity = currentCity
            }
        }
        // Restore GPS detection info banner if present
        if SettingsManager.shared.locationSource == "gps",
           !SettingsManager.shared.gpsLocality.isEmpty,
           let coord = SettingsManager.shared.cachedGPSCoordinate() {
            let lat = coord.latitude, lon = coord.longitude
            let latStr = String(format: "%.4f°%@", abs(lat), lat >= 0 ? "N" : "S")
            let lonStr = String(format: "%.4f°%@", abs(lon), lon >= 0 ? "E" : "W")
            detectedLocationInfo = "📍 \(SettingsManager.shared.gpsLocality) — \(latStr), \(lonStr)"
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

// MARK: - Adjustment row (extracted to keep SettingsSheetView under line limit)

private struct SettingsAdjustmentRow: View {
    let prayerName: String
    let baseTime: Date?
    let formatter: DateFormatter?

    @ObservedObject private var settings = SettingsManager.shared

    private var current: Int { settings.prayerAdjustments[prayerName] ?? 0 }

    private var finalTime: Date? {
        baseTime.flatMap { Calendar.current.date(byAdding: .minute, value: current, to: $0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(prayerName)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let fmt = formatter, let base = baseTime {
                    Text(fmt.string(from: base)).foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .font(.caption.monospacedDigit())
            .frame(width: 66, alignment: .trailing)

            HStack(spacing: 4) {
                Button { SettingsManager.shared.setAdjustment(current - 1, for: prayerName) } label: {
                    Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical)
                        .foregroundStyle(current > -60 ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain).disabled(current <= -60)
                .accessibilityLabel("Decrease \(prayerName) adjustment")

                Text(current == 0 ? "±0" : (current > 0 ? "+\(current)" : "\(current)"))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(current == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    .frame(width: 32, alignment: .center)
                    .accessibilityLabel("\(prayerName) adjustment: \(current) minutes")

                Button { SettingsManager.shared.setAdjustment(current + 1, for: prayerName) } label: {
                    Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical)
                        .foregroundStyle(current < 60 ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain).disabled(current >= 60)
                .accessibilityLabel("Increase \(prayerName) adjustment")
            }
            .frame(width: 86, alignment: .center)

            Group {
                if let fmt = formatter, let adjusted = finalTime {
                    Text(fmt.string(from: adjusted))
                        .foregroundStyle(current != 0 ? AnyShapeStyle(Color.appGold) : AnyShapeStyle(Color.primary))
                        .fontWeight(current != 0 ? .semibold : .regular)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .font(.callout.monospacedDigit())
            .frame(width: 66, alignment: .trailing)
        }
    }
}
