import Foundation

enum CalculationMethod: String, CaseIterable, Identifiable {
    case muslimWorldLeague = "mwl"
    case isna
    case egypt
    case ummAlQura = "umm_al_qura"
    case karachi
    case tehran

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muslimWorldLeague:
            "Muslim World League"
        case .isna:
            "Islamic Society of North America (ISNA)"
        case .egypt:
            "Egyptian General Authority of Survey"
        case .ummAlQura:
            "Umm Al-Qura University, Makkah"
        case .karachi:
            "University of Islamic Sciences, Karachi"
        case .tehran:
            "Institute of Geophysics, University of Tehran"
        }
    }

    /// Abbreviated name suitable for constrained UI (header toolbar).
    var shortName: String {
        switch self {
        case .muslimWorldLeague: "MWL"
        case .isna: "ISNA"
        case .egypt: "Egyptian"
        case .ummAlQura: "Umm Al-Qura"
        case .karachi: "Karachi"
        case .tehran: "Tehran"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .muslimWorldLeague:
            18.0
        case .isna:
            15.0
        case .egypt:
            19.5
        case .ummAlQura:
            18.5
        case .karachi:
            18.0
        case .tehran:
            17.7
        }
    }

    var ishaAngle: Double {
        switch self {
        case .muslimWorldLeague:
            17.0
        case .isna:
            15.0
        case .egypt:
            17.5
        case .ummAlQura:
            0.0 // Umm Al-Qura uses fixed interval
        case .karachi:
            18.0
        case .tehran:
            14.0
        }
    }

    var ishaInterval: Int? {
        switch self {
        case .ummAlQura:
            90 // 90 minutes after Maghrib
        default:
            nil
        }
    }

    var maghribAngle: Double? {
        switch self {
        case .tehran:
            4.5
        default:
            nil
        }
    }
}

// MARK: - Country Mapping (US-0031)

extension CalculationMethod {
    /// Returns the calculation method most commonly used in a given ISO 3166-1 alpha-2 country.
    static func suggested(forCountryCode code: String) -> CalculationMethod {
        switch code.uppercased() {
        case "US", "CA":
            .isna
        case "EG", "LY", "SD", "MA", "DZ", "TN", "JO", "PS", "LB", "SY", "IQ", "KM":
            .egypt
        case "SA", "AE", "QA", "BH", "KW", "YE", "OM":
            .ummAlQura
        case "PK", "AF", "BD", "IN", "LK", "NP", "MV":
            .karachi
        case "IR":
            .tehran
        default:
            .muslimWorldLeague
        }
    }

    /// Human-readable region label used in the "Recommended for…" badge.
    static func recommendationLabel(forCountryCode code: String) -> String? {
        let name = Locale.current.localizedString(forRegionCode: code)
        return name.map { "Recommended for \($0)" }
    }
}

enum AsrJuristicMethod: String, CaseIterable, Identifiable {
    case standard
    case hanafi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            "Standard (Shafi'i/Maliki/Hanbali)"
        case .hanafi:
            "Hanafi"
        }
    }

    var shadowFactor: Double {
        switch self {
        case .standard:
            1.0
        case .hanafi:
            2.0
        }
    }
}
