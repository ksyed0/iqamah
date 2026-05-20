import IqamahCore
import SwiftUI
import WidgetKit

struct SettingsTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var locationUpdater = WatchLocationSetup()
    @State private var isUpdatingLocation = false
    @State private var database: CitiesDatabase?

    var body: some View {
        Form {
            Section("Location") {
                Text(locationLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // GPS update
                Button(isUpdatingLocation ? "Updating…" : "Update via GPS") {
                    isUpdatingLocation = true
                    locationUpdater.start(settings: settings)
                }
                .disabled(isUpdatingLocation)
                .onChange(of: locationUpdater.isReady) { _, ready in
                    if ready {
                        isUpdatingLocation = false
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }

                // Manual city selection — drill-down Country → City
                // Uses .task on the Form (not .onAppear on the Section) for reliable
                // loading on watchOS where Section.onAppear can silently not fire.
                if let db = database {
                    NavigationLink("Set City Manually") {
                        WatchCountryPicker(database: db, settings: settings)
                    }
                } else {
                    Text("Loading cities…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Prayer Times") {
                Picker("Method", selection: $settings.calculationMethod) {
                    ForEach(CalculationMethod.allCases) { m in
                        Text(m.shortName).tag(m)
                    }
                }
                Picker("Asr", selection: $settings.asrMethod) {
                    Text("Standard").tag(AsrJuristicMethod.standard)
                    Text("Hanafi").tag(AsrJuristicMethod.hanafi)
                }
            }
            .onChange(of: settings.calculationMethod) { _, _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: settings.asrMethod) { _, _ in
                WidgetCenter.shared.reloadAllTimelines()
            }

            Section("Adjustments") {
                ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayer in
                    Stepper(value: adjustmentBinding(for: prayer), in: -15 ... 15) {
                        let val = settings.getAdjustment(for: prayer)
                        Text("\(prayer): \(val > 0 ? "+" : "")\(val)m")
                            .font(.caption)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Prayer haptics", isOn: $settings.hilalNotificationEnabled)
            }

            Section("Display") {
                Toggle("24-hour time", isOn: $settings.use24HourTime)
            }
        }
        .task {
            // .task on the Form fires reliably on watchOS; Section.onAppear can be missed.
            guard database == nil else { return }
            if case let .success(db) = CitiesLoader.shared.load() {
                database = db
            }
        }
    }

    private var locationLabel: String {
        let name = settings.activeCityName // GPS locality or nearest city name
        if !name.isEmpty { return name }
        if let coord = settings.activeCoordinate {
            return String(format: "%.2f°, %.2f°", coord.latitude, coord.longitude)
        }
        return "Not set"
    }

    private func adjustmentBinding(for prayer: String) -> Binding<Int> {
        Binding(
            get: { settings.getAdjustment(for: prayer) },
            set: {
                settings.setAdjustment($0, for: prayer)
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }
}

// MARK: - Country picker (watch drill-down level 1)

struct WatchCountryPicker: View {
    let database: CitiesDatabase
    let settings: SettingsManager
    @State private var query = ""

    private var filtered: [Country] {
        let all = database.countries.sorted { $0.name < $1.name }
        return query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { country in
                NavigationLink(country.name) {
                    WatchCityPicker(
                        cities: database.cities(forCountryCode: country.code),
                        settings: settings
                    )
                }
            }
        }
        .searchable(text: $query, prompt: "Country")
        .navigationTitle("Country")
    }
}

// MARK: - City picker (watch drill-down level 2)

struct WatchCityPicker: View {
    let cities: [City]
    let settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [City] {
        query.isEmpty ? cities : cities.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { city in
                Button(city.name) {
                    settings.saveCity(city)
                    settings.locationSource = "manual"
                    WidgetCenter.shared.reloadAllTimelines()
                    dismiss()
                }
            }
        }
        .searchable(text: $query, prompt: "City")
        .navigationTitle("City")
    }
}
