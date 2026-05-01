import Foundation

enum CalculationMethod: String, CaseIterable, Identifiable {
    case muslimWorldLeague = "mwl"
    case isna = "isna"
    case egypt = "egypt"
    case ummAlQura = "umm_al_qura"
    case karachi = "karachi"
    case tehran = "tehran"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muslimWorldLeague:
            return "Muslim World League"
        case .isna:
            return "Islamic Society of North America (ISNA)"
        case .egypt:
            return "Egyptian General Authority of Survey"
        case .ummAlQura:
            return "Umm Al-Qura University, Makkah"
        case .karachi:
            return "University of Islamic Sciences, Karachi"
        case .tehran:
            return "Institute of Geophysics, University of Tehran"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .muslimWorldLeague:
            return 18.0
        case .isna:
            return 15.0
        case .egypt:
            return 19.5
        case .ummAlQura:
            return 18.5
        case .karachi:
            return 18.0
        case .tehran:
            return 17.7
        }
    }

    var ishaAngle: Double {
        switch self {
        case .muslimWorldLeague:
            return 17.0
        case .isna:
            return 15.0
        case .egypt:
            return 17.5
        case .ummAlQura:
            return 0.0 // Umm Al-Qura uses fixed interval
        case .karachi:
            return 18.0
        case .tehran:
            return 14.0
        }
    }

    var ishaInterval: Int? {
        switch self {
        case .ummAlQura:
            return 90 // 90 minutes after Maghrib
        default:
            return nil
        }
    }

    var maghribAngle: Double? {
        switch self {
        case .tehran:
            return 4.5
        default:
            return nil
        }
    }
}

// MARK: - Country Mapping (US-0031)

extension CalculationMethod {
    /// Returns the calculation method most commonly used in a given ISO 3166-1 alpha-2 country.
    static func suggested(forCountryCode code: String) -> CalculationMethod {
        switch code.uppercased() {
        case "US", "CA":
            return .isna
        case "EG", "LY", "SD", "MA", "DZ", "TN", "JO", "PS", "LB", "SY", "IQ", "KM":
            return .egypt
        case "SA", "AE", "QA", "BH", "KW", "YE", "OM":
            return .ummAlQura
        case "PK", "AF", "BD", "IN", "LK", "NP", "MV":
            return .karachi
        case "IR":
            return .tehran
        default:
            return .muslimWorldLeague
        }
    }

    /// Human-readable region label used in the "Recommended for…" badge.
    static func recommendationLabel(forCountryCode code: String) -> String? {
        let name = Locale.current.localizedString(forRegionCode: code)
        return name.map { "Recommended for \($0)" }
    }
}

enum AsrJuristicMethod: String, CaseIterable, Identifiable {
    case standard = "standard"
    case hanafi = "hanafi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "Standard (Shafi'i/Maliki/Hanbali)"
        case .hanafi:
            return "Hanafi"
        }
    }

    var shadowFactor: Double {
        switch self {
        case .standard:
            return 1.0
        case .hanafi:
            return 2.0
        }
    }
}
