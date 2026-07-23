import IqamahCore
import SwiftUI

struct IOSRootView: View {
    @EnvironmentObject private var settings: SettingsManager
    /// Drives switching to the Times tab when a prayer notification is tapped.
    @State private var selectedTab: Int = {
        // --startTab=N selects the initial tab for UI tests (visionOS 26 floating tab
        // bar does not respond to XCUITest synthetic taps, so tests relaunch on the
        // target tab directly instead of navigating via tapTab()).
        if CommandLine.arguments.contains("--startTab=1") {
            return 1
        }
        if CommandLine.arguments.contains("--startTab=2") {
            return 2
        }
        return 0
    }()
    @State private var showHilalWatch = false
    @State private var showLegacyReDetectPrompt = false
    @State private var moveDetected: MoveDetectedPayload?

    var body: some View {
        if settings.hasCompletedSetup {
            MainTabView(selectedTab: $selectedTab)
                .onReceive(NotificationCenter.default.publisher(for: .openPrayerTimesTab)) { _ in
                    selectedTab = 0
                }
            #if !os(visionOS)
                .fullScreenCover(isPresented: $showHilalWatch) {
                    HilalWatchSheet()
                        .environmentObject(settings)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openHilalWatch)) { _ in
                    showHilalWatch = true
                }
            #endif
                .onAppear {
                    if settings.isLegacyV15User, !settings.didShowGPSReDetectPromptV16 {
                        showLegacyReDetectPrompt = true
                    }
                }
                .alert("Location accuracy improved", isPresented: $showLegacyReDetectPrompt) {
                    Button("Re-detect") {
                        settings.didShowGPSReDetectPromptV16 = true
                        selectedTab = 2 // jump to Settings tab — re-detect button lives there
                        // SettingsSheetView observes this and pulses the Detect button.
                        // Slight delay so the tab switch settles before the highlight fires.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .openSettingsForReDetect, object: nil)
                        }
                    }
                    Button("Keep current", role: .cancel) {
                        settings.didShowGPSReDetectPromptV16 = true
                        settings.locationSource = "manual"
                    }
                } message: {
                    Text(
                        "Iqamah v1.6 uses your exact GPS position and authoritative timezone for prayer-time calculations. Re-detect your location now to apply the improvement?"
                    )
                }
                // BUG-0069: launch-time auto-detect prompt
                .onReceive(NotificationCenter.default.publisher(for: .didDetectMove)) { note in
                    if let payload = note.object as? MoveDetectedPayload {
                        moveDetected = payload
                    }
                }
                .alert(
                    "Have you moved?",
                    isPresented: Binding(
                        get: { moveDetected != nil },
                        set: {
                            if !$0 {
                                moveDetected = nil
                            }
                        }
                    ),
                    presenting: moveDetected
                ) { payload in
                    Button("Switch") {
                        let locality = payload.detectedLocality.isEmpty
                            ? payload.savedCityName
                            : payload.detectedLocality
                        if let newCity = try? City(
                            name: locality,
                            countryCode: settings.loadCity()?.countryCode ?? "US",
                            latitude: payload.detectedCoordinate.latitude,
                            longitude: payload.detectedCoordinate.longitude,
                            timezone: TimeZone.current.identifier
                        ) {
                            settings.saveCity(newCity)
                            settings.locationSource = "gps"
                            settings.saveGPSCoordinates(payload.detectedCoordinate)
                            settings.gpsLocality = payload.detectedLocality
                            settings.gpsDetectedCity = newCity
                            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                        }
                        moveDetected = nil
                    }
                    Button("Not now", role: .cancel) {
                        moveDetected = nil
                    }
                } message: { payload in
                    let whereText = payload.detectedLocality.isEmpty
                        ? "your current location"
                        : payload.detectedLocality
                    Text(
                        "It looks like you're in \(whereText), about \(payload.distanceKmString) from \(payload.savedCityName). Switch your prayer-times city?"
                    )
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
                    QiblahView(latitude: city.latitude, longitude: city.longitude,
                               cityName: settings.activeCityName.isEmpty ? city.name : settings.activeCityName)
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
