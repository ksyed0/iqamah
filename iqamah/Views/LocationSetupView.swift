import SwiftUI
import CoreLocation

struct LocationSetupView: View {
    @StateObject private var locationService = LocationService()
    @State private var database: CitiesDatabase?
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var hasDetectedLocation = false
    @State private var showDetectedBadge = false // US-0026

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
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        Text("Location detected")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())
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
                }
                Spacer()
                Button(action: {
                    if let city = selectedCity { onLocationConfirmed(city) }
                }) {
                    Text("Continue")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appGold)
                .controlSize(.large)
                .disabled(selectedCity == nil)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 420, minHeight: 420)
        .onAppear {
            loadDatabase()
            locationService.requestLocation()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            if let coordinate = newLocation, !hasDetectedLocation {
                detectClosestCity(to: coordinate)
            }
        }
        .onChange(of: selectedCountry) { oldValue, _ in
            if oldValue != nil {
                selectedCity = nil
                // Hide GPS badge when user manually changes country
                if hasDetectedLocation {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedCity = closestCity
                withAnimation(.spring(response: 0.4)) {
                    showDetectedBadge = true
                }
            }
        }
    }
}
