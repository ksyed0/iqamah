import SwiftUI
import CoreLocation

/// Location setup screen - first step of onboarding
/// Allows user to grant GPS permission or manually select a city
struct LocationSetupView: View {
    @StateObject private var locationService = LocationService()
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var citiesDatabase: CitiesDatabase?
    @State private var useGPS = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onCitySelected: (City) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.76, blue: 0.06),
                                Color(red: 0.85, green: 0.65, blue: 0.13)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)
                
                Text("Set Your Location")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("We need your location to calculate accurate prayer times")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 30)
            
            // Location Options
            VStack(spacing: 20) {
                // GPS Option
                Button(action: requestLocation) {
                    HStack(spacing: 15) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 24))
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Current Location")
                                .font(.headline)
                            Text("Automatically detect your location via GPS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if locationService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(locationService.isLoading)
                
                // Divider with "OR"
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)
                
                // Manual Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select City Manually")
                        .font(.headline)
                    
                    if let database = citiesDatabase {
                        // Country Picker
                        Picker("Country", selection: $selectedCountry) {
                            Text("Select a country...").tag(nil as Country?)
                            ForEach(database.countries) { country in
                                Text(country.name).tag(country as Country?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        // City Picker (enabled only when country selected)
                        if let country = selectedCountry {
                            let cities = database.cities(forCountryCode: country.code)
                            
                            Picker("City", selection: $selectedCity) {
                                Text("Select a city...").tag(nil as City?)
                                ForEach(cities) { city in
                                    Text(city.name).tag(city as City?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        // Error loading cities database
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Unable to load cities database")
                                .font(.headline)
                            
                            Text("The cities.json file could not be loaded. Please contact support.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Continue Button
            Button(action: proceedWithSelectedCity) {
                HStack {
                    Text("Continue")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCity != nil ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(selectedCity == nil)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Location Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadCitiesDatabase()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCitiesDatabase() {
        let result = CitiesLoader.shared.load()
        
        switch result {
        case .success(let database):
            citiesDatabase = database
        case .failure(let error):
            errorMessage = error.localizedDescription
            if let recovery = error.recoverySuggestion {
                errorMessage += "\n\n\(recovery)"
            }
            showError = true
        }
    }
    
    private func requestLocation() {
        locationService.requestLocation()
        
        // Monitor for location updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let coordinate = locationService.currentLocation,
               let database = citiesDatabase {
                // Find closest city
                if let closestCity = database.closestCity(to: coordinate) {
                    selectedCity = closestCity
                    selectedCountry = database.country(forCode: closestCity.countryCode)
                    
                    // Auto-proceed after finding closest city
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        proceedWithSelectedCity()
                    }
                }
            } else if let error = locationService.locationError {
                errorMessage = error
                showError = true
            }
        }
    }
    
    private func proceedWithSelectedCity() {
        guard let city = selectedCity else { return }
        onCitySelected(city)
    }
}

// MARK: - Preview

#Preview {
    LocationSetupView { city in
        print("Selected city: \(city.name)")
    }
}
