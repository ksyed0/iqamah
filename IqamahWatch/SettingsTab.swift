import IqamahCore
import SwiftUI
import WidgetKit

struct SettingsTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var locationUpdater = WatchLocationSetup()
    @State private var isUpdatingLocation = false

    var body: some View {
        Form {
            Section("Location") {
                Text(locationLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button(isUpdatingLocation ? "Updating…" : "Update Location") {
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
    }

    private var locationLabel: String {
        if let city = settings.loadCity() { return city.name }
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
