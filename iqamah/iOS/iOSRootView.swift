import IqamahCore
import SwiftUI

struct IOSRootView: View {
    @EnvironmentObject private var settings: SettingsManager
    /// Drives switching to the Times tab when a prayer notification is tapped.
    @State private var selectedTab: Int = 0
    @State private var showHilalWatch = false

    var body: some View {
        if settings.hasCompletedSetup {
            MainTabView(selectedTab: $selectedTab)
                .onReceive(NotificationCenter.default.publisher(for: .openPrayerTimesTab)) { _ in
                    selectedTab = 0
                }
                .sheet(isPresented: $showHilalWatch) {
                    HilalWatchSheet()
                        .environmentObject(settings)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openHilalWatch)) { _ in
                    showHilalWatch = true
                }
        } else {
            OnboardingFlow()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Binding var selectedTab: Int

    private var city: City? { settings.loadCity() }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                if let city {
                    PrayerTimesView(
                        city: city,
                        calculationMethod: settings.calculationMethod,
                        asrMethod: settings.asrMethod,
                        onSettingsSaved: { newCity, newMethod, newAsr in
                            settings.saveCity(newCity)
                            settings.calculationMethod = newMethod
                            settings.asrMethod = newAsr
                        }
                    )
                } else {
                    ProgressView("Loading…")
                }
            }
            .tabItem { Label("Times", systemImage: "clock") }
            .tag(0)

            NavigationStack {
                if let city {
                    QiblahView(latitude: city.latitude, longitude: city.longitude, cityName: city.name)
                } else {
                    Text("Select a location first")
                        .foregroundStyle(.secondary)
                }
            }
            .tabItem { Label("Qiblah", systemImage: "location.north.line") }
            .tag(1)

            NavigationStack {
                if let city {
                    SettingsSheetView(
                        currentCity: city,
                        currentMethod: settings.calculationMethod,
                        currentAsrMethod: settings.asrMethod,
                        onSave: { newCity, newMethod, newAsr in
                            settings.saveCity(newCity)
                            settings.calculationMethod = newMethod
                            settings.asrMethod = newAsr
                        },
                        onCancel: {}
                    )
                } else {
                    ProgressView("Loading…")
                }
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(2)
        }
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var step: Step = .location
    @State private var selectedCity: City?
    @State private var selectedMethod: CalculationMethod = .isna
    @State private var selectedAsrMethod: AsrJuristicMethod = .standard

    enum Step { case location, method }

    var body: some View {
        switch step {
        case .location:
            LocationSetupView(
                onLocationConfirmed: { city in
                    selectedCity = city
                    step = .method
                },
                onBack: nil
            )
        case .method:
            CalculationMethodView(
                selectedMethod: $selectedMethod,
                selectedAsrMethod: $selectedAsrMethod,
                onConfirm: {
                    guard let city = selectedCity else { return }
                    settings.completeSetup(
                        city: city,
                        calculationMethod: selectedMethod,
                        asrMethod: selectedAsrMethod
                    )
                },
                onBack: { step = .location }
            )
        }
    }
}
