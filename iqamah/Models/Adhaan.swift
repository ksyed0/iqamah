import Foundation

/// A single audio option selectable per prayer — either a full Adhaan recording or a gentle alert tone.
struct Adhaan: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let filename: String // empty for .silent

    // MARK: - Built-in options

    static let silent = Adhaan(id: "silent", displayName: "Silent", filename: "")

    /// All options for standard prayers: Silent → Alert Tones → Adhaan recordings
    static var available: [Adhaan] {
        var options: [Adhaan] = [.silent]
        options += alertTones
        options += adhaanRecordings
        return options
    }

    /// All options for Fajr prayer — includes Fajr-specific adhaans (with "prayer is better than sleep").
    static var availableForFajr: [Adhaan] {
        var options: [Adhaan] = [.silent]
        options += alertTones
        options += adhaanRecordings
        options += adhaanFajrRecordings
        return options
    }

    /// Bundled gentle alert tones (tone_*.aiff / tone_*.mp3)
    static var alertTones: [Adhaan] {
        let known: [(id: String, name: String, exts: [String])] = [
            ("tone_glass", "Glass Bell", ["aiff", "mp3"]),
            ("tone_ping", "Soft Ping", ["aiff", "mp3"]),
            ("tone_tink", "Light Chime", ["aiff", "mp3"]),
            ("tone_hero", "Hero", ["aiff", "mp3"]),
            ("tone_breeze", "Gentle Breeze", ["aiff", "mp3"]),
        ]
        return known.compactMap { entry in
            for ext in entry.exts where Bundle.main.url(forResource: entry.id, withExtension: ext) != nil {
                return Adhaan(id: entry.id, displayName: entry.name, filename: "\(entry.id).\(ext)")
            }
            return nil
        }
    }

    /// Standard Adhaan recordings (adhaan_1…adhaan_10) — suitable for all prayers.
    static var adhaanRecordings: [Adhaan] {
        (1 ... 10).compactMap { i in
            let id = "adhaan_\(i)"
            for ext in ["mp3", "m4a", "aac", "aiff"] where Bundle.main.url(forResource: id, withExtension: ext) != nil {
                return Adhaan(id: id, displayName: "Adhaan \(i)", filename: "\(id).\(ext)")
            }
            return nil
        }
    }

    /// Fajr-specific Adhaan recordings — include "As-salatu khayrun minan nawm"
    /// (Prayer is better than sleep), as prescribed for the Fajr call.
    static var adhaanFajrRecordings: [Adhaan] {
        (1 ... 5).compactMap { i in
            let id = "adhaan_fajr_\(i)"
            for ext in ["mp3", "m4a", "aac", "aiff"] where Bundle.main.url(forResource: id, withExtension: ext) != nil {
                return Adhaan(id: id, displayName: "Fajr Adhaan \(i)", filename: "\(id).\(ext)")
            }
            return nil
        }
    }
}
