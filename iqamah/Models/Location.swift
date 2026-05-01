import Foundation
import CoreLocation

struct Country: Codable, Identifiable, Hashable {
    let name: String
    let code: String

    var id: String { code }
}

struct City: Codable, Identifiable, Hashable {
    let name: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timezone: String

    var id: String { "\(countryCode)-\(name)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Custom initializer with validation
    init(name: String, countryCode: String, latitude: Double, longitude: Double, timezone: String) throws {
        // Validate coordinates
        guard latitude >= -90, latitude <= 90 else {
            throw IqamahError.invalidCoordinates(latitude: latitude, longitude: longitude)
        }
        guard longitude >= -180, longitude <= 180 else {
            throw IqamahError.invalidCoordinates(latitude: latitude, longitude: longitude)
        }

        // Validate timezone
        guard TimeZone(identifier: timezone) != nil else {
            throw IqamahError.invalidTimezone(timezone)
        }

        self.name = name
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    // Codable conformance (for JSON decoding)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let countryCode = try container.decode(String.self, forKey: .countryCode)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let timezone = try container.decode(String.self, forKey: .timezone)

        // Use the throwing initializer for validation
        try self.init(name: name, countryCode: countryCode, latitude: latitude, longitude: longitude, timezone: timezone)
    }

    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let cityLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return cityLocation.distance(from: otherLocation)
    }
}

struct CitiesDatabase: Codable {
    let countries: [Country]
    let cities: [City]

    func country(forCode code: String) -> Country? {
        countries.first { $0.code == code }
    }

    func cities(forCountryCode code: String) -> [City] {
        cities.filter { $0.countryCode == code }.sorted { $0.name < $1.name }
    }

    func closestCity(to coordinate: CLLocationCoordinate2D) -> City? {
        cities.min { $0.distance(from: coordinate) < $1.distance(from: coordinate) }
    }
}

class CitiesLoader {
    static let shared = CitiesLoader()

    private var database: CitiesDatabase?
    private var loadError: IqamahError?

    // Internal init allows test targets to create isolated instances (avoiding shared-cache races)
    init() {}

    func load() -> Result<CitiesDatabase, IqamahError> {
        // Return cached database if already loaded successfully
        if let database {
            return .success(database)
        }

        // Return cached error if previous load failed
        if let error = loadError {
            return .failure(error)
        }

        // Bundle(for:) resolves correctly in both app and test targets
        let bundle = Bundle(for: CitiesLoader.self)
        guard let url = bundle.url(forResource: "cities", withExtension: "json") else {
            let error = IqamahError.citiesDatabaseNotFound
            loadError = error
            logError(error, context: "CitiesLoader.load()")
            return .failure(error)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedDatabase = try decoder.decode(CitiesDatabase.self, from: data)

            // Validate database has content
            guard !loadedDatabase.cities.isEmpty else {
                let error = IqamahError.citiesDatabaseLoadFailed(reason: "Database contains no cities")
                loadError = error
                logError(error, context: "CitiesLoader.load()")
                return .failure(error)
            }

            database = loadedDatabase
            return .success(loadedDatabase)
        } catch let decodingError as DecodingError {
            let error = IqamahError.citiesDatabaseCorrupted(underlyingError: decodingError)
            loadError = error
            logError(error, context: "CitiesLoader.load()")
            return .failure(error)
        } catch {
            let wrappedError = IqamahError.citiesDatabaseLoadFailed(reason: error.localizedDescription)
            loadError = wrappedError
            logError(wrappedError, context: "CitiesLoader.load()")
            return .failure(wrappedError)
        }
    }

    private func logError(_ error: IqamahError, context: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("""
        [\(timestamp)] \(error.logLevel)
        Type: IqamahError
        Context: \(context)
        Message: \(error.localizedDescription)
        Recoverable: \(error.isRecoverable)
        ---
        """)
    }
} // end CitiesLoader
