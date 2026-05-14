import SwiftUI
import CoreLocation
import IqamahCore

struct LocationSetupView: View {
    @StateObject private var locationService = LocationService()
    @State private var database: CitiesDatabase?
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var hasDetectedLocation = false
    @State private var showDetectedBadge = false // US-0026
    @State private var rawGPSCoordinate: CLLocationCoordinate2D? // ENH-001: raw GPS coordinate

    let onLocationConfirmed: (City) -> Void
    let onBack: (() -> Void)? // US-0027 — nil when used in first-run flow

    init(onLocationConfirmed: @escaping (City) -> Void, onBack: (() -> Void)? = nil) {
        self.onLocationConfirmed = onLocationConfirmed
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Step indicator (US-0027) ────────────────────────────
            StepIndicator(current: 1, total: 2)
                .padding(.top, 28)
                .padding(.bottom, 4)

            // BUG-0028: Spacer above content centres it vertically — eliminates 200pt dead zone
            Spacer(minLength: 16)

            VStack(spacing: 20) {
                Text("Select Your Location")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("We'll use your location to calculate accurate prayer times.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)

                // ── GPS status (US-0026) ────────────────────────────
                if locationService.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Detecting location…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if showDetectedBadge {
                    let locality = SettingsManager.shared.gpsLocality
                    let coord = rawGPSCoordinate
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(locality.isEmpty ? "Location detected" : "📍 \(locality)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.accentColor)
                            if let c = coord {
                                Text(String(format: "%.4f°%@, %.4f°%@",
                                            abs(c.latitude), c.latitude >= 0 ? "N" : "S",
                                            abs(c.longitude), c.longitude >= 0 ? "E" : "W"))
                                    .font(.caption2)
                                    .foregroundColor(.accentColor.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else if let error = locationService.locationError {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Button("Try Again") { locationService.requestLocation() }
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                // ── Country / City pickers ──────────────────────────
                if let database {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Country").font(.headline)
                            Picker("Country", selection: $selectedCountry) {
                                Text("Select a country").tag(nil as Country?)
                                ForEach(database.countries.sorted { $0.name < $1.name }) { country in
                                    Text(country.name).tag(country as Country?)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }

                        if selectedCountry != nil {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("City").font(.headline)
                                Picker("City", selection: $selectedCity) {
                                    Text("Select a city").tag(nil as City?)
                                    ForEach(database.cities(forCountryCode: selectedCountry?.code ?? "")) { city in
                                        Text(city.name).tag(city as City?)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: 300)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Spacer()

            // ── Navigation buttons ──────────────────────────────────
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                Spacer()
                Button(action: {
                    guard let city = selectedCity else { return }
                    if hasDetectedLocation, let coord = rawGPSCoordinate {
                        // ENH-001 Option A: use raw GPS coords + TimeZone.current
                        SettingsManager.shared.locationSource = "gps"
                        SettingsManager.shared.saveGPSCoordinates(coord)
                        SettingsManager.shared.gpsTimezone = TimeZone.current.identifier
                        guard let gpsCity = try? City(
                            name: city.name,
                            countryCode: city.countryCode,
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            timezone: TimeZone.current.identifier
                        ) else { return }
                        onLocationConfirmed(gpsCity)
                        reverseGeocodeAndUpdate(coordinate: coord)
                    } else {
                        // ENH-001 manual path
                        SettingsManager.shared.locationSource = "manual"
                        onLocationConfirmed(city)
                    }
                }) {
                    Text("Continue")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appGold)
                .controlSize(.large)
                .disabled(selectedCity == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 420, minHeight: 420)
        .onAppear {
            loadDatabase()
            locationService.requestLocation()
            // Simulator / denied permission can silently stall. After 15s synthesise a
            // "Location unavailable" error so the user can fall back to manual city selection.
            Task {
                try? await Task.sleep(for: .seconds(15))
                await MainActor.run {
                    guard locationService.isLoading else { return }
                    locationService.simulateTimeout()
                }
            }
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            if let coordinate = newLocation, !hasDetectedLocation {
                detectClosestCity(to: coordinate)
            }
        }
        .onChange(of: selectedCountry) { oldValue, _ in
            if oldValue != nil {
                selectedCity = nil
                // Hide GPS badge when user manually changes country; treat as manual selection
                if hasDetectedLocation {
                    hasDetectedLocation = false
                    rawGPSCoordinate = nil
                    withAnimation { showDetectedBadge = false }
                }
            }
        }
    }

    private func loadDatabase() {
        if case let .success(db) = CitiesLoader.shared.load() {
            database = db
        }
    }

    private func detectClosestCity(to coordinate: CLLocationCoordinate2D) {
        guard let database else { return }
        if let closestCity = database.closestCity(to: coordinate) {
            selectedCountry = database.country(forCode: closestCity.countryCode)
            hasDetectedLocation = true
            rawGPSCoordinate = coordinate // ENH-001: capture raw GPS coordinate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedCity = closestCity
                withAnimation(.spring(response: 0.4)) {
                    showDetectedBadge = true
                }
            }
        }
    }

    // ENH-001 Option B: CLGeocoder refines locality and timezone asynchronously
    private func reverseGeocodeAndUpdate(coordinate: CLLocationCoordinate2D) {
        // Skip if same location as cache (within 5 km)
        if let cached = SettingsManager.shared.cachedGPSCoordinate() {
            let cachedLoc = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
            let newLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if cachedLoc.distance(from: newLoc) < 5000,
               !SettingsManager.shared.gpsLocality.isEmpty { return }
        }

        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first else {
                print("[ENH-001] CLGeocoder failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let locality = placemark.locality ?? placemark.name ?? SettingsManager.shared.gpsLocality
            let timezone = placemark.timeZone?.identifier ?? TimeZone.current.identifier

            DispatchQueue.main.async {
                SettingsManager.shared.gpsLocality = locality
                SettingsManager.shared.gpsTimezone = timezone
                // Refine the saved city name and timezone with authoritative values
                if let city = SettingsManager.shared.loadCity(),
                   let refined = try? City(
                       name: locality,
                       countryCode: city.countryCode,
                       latitude: coordinate.latitude,
                       longitude: coordinate.longitude,
                       timezone: timezone
                   ) {
                    SettingsManager.shared.saveCity(refined)
                }
            }
        }
    }
}
