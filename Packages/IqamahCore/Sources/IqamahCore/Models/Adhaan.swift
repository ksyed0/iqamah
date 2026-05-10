import Foundation

/// A single audio option selectable per prayer — either a full Adhaan recording or a gentle alert tone.
public struct Adhaan: Identifiable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let filename: String // empty for .silent

    public init(id: String, displayName: String, filename: String) {
        self.id = id
        self.displayName = displayName
        self.filename = filename
    }

    public var shortName: String {
        if displayName.hasPrefix("Adhaan ") {
            return String(displayName.dropFirst("Adhaan ".count))
        }
        return displayName
    }

    // MARK: - Built-in options

    public static let silent = Adhaan(id: "silent", displayName: "Silent", filename: "")

    /// All options for standard prayers: Silent → Alert Tones → Adhaan recordings
    public static var available: [Adhaan] {
        var options: [Adhaan] = [.silent]
        options += alertTones
        options += adhaanRecordings
        return options
    }

    /// All options for Fajr prayer — includes Fajr-specific adhaans (with "prayer is better than sleep").
    public static var availableForFajr: [Adhaan] {
        var options: [Adhaan] = [.silent]
        options += alertTones
        options += adhaanRecordings
        options += adhaanFajrRecordings
        return options
    }

    /// Bundled gentle alert tones (tone_*.aiff / tone_*.mp3)
    public static var alertTones: [Adhaan] {
        let known: [(id: String, name: String, exts: [String])] = [
            ("tone_glass", "Glass Bell", ["aiff", "mp3"]),
            ("tone_ping", "Soft Ping", ["aiff", "mp3"]),
            ("tone_tink", "Light Chime", ["aiff", "mp3"]),
            ("tone_hero", "Hero", ["aiff", "mp3"]),
            ("tone_breeze", "Gentle Breeze", ["aiff", "mp3"]),
        ]
        return known.compactMap { entry in
            for ext in entry.exts where Bundle.module.url(forResource: entry.id, withExtension: ext) != nil {
                return Adhaan(id: entry.id, displayName: entry.name, filename: "\(entry.id).\(ext)")
            }
            return nil
        }
    }

    /// Standard Adhaan recordings (adhaan_1…adhaan_10) — suitable for all prayers.
    public static var adhaanRecordings: [Adhaan] {
        (1 ... 10).compactMap { i in
            let id = "adhaan_\(i)"
            for ext in ["mp3", "m4a", "aac", "aiff"] where Bundle.module.url(forResource: id, withExtension: ext) != nil {
                return Adhaan(id: id, displayName: "Adhaan \(i)", filename: "\(id).\(ext)")
            }
            return nil
        }
    }

    /// Fajr-specific Adhaan recordings — include "As-salatu khayrun minan nawm"
    /// (Prayer is better than sleep), as prescribed for the Fajr call.
    public static var adhaanFajrRecordings: [Adhaan] {
        (1 ... 5).compactMap { i in
            let id = "adhaan_fajr_\(i)"
            for ext in ["mp3", "m4a", "aac", "aiff"] where Bundle.module.url(forResource: id, withExtension: ext) != nil {
                return Adhaan(id: id, displayName: "Fajr Adhaan \(i)", filename: "\(id).\(ext)")
            }
            return nil
        }
    }

    // MARK: - Notification sound helpers

    /// Returns the URL of the 30-second `.mp3` notification variant for this adhaan,
    /// or `nil` if the clip is not present in the bundle (silent / alert tones have no clip).
    public var notificationSoundURL: URL? {
        guard id != "silent", !filename.isEmpty else { return nil }
        let baseName = (filename as NSString).deletingPathExtension
        let notifFile = "\(baseName)_notif"
        return Bundle.module.url(forResource: notifFile, withExtension: "mp3", subdirectory: "Notifications")
    }

    /// Returns the filename of the 30-second `.mp3` notification variant (base + ext only,
    /// suitable for `UNNotificationSoundName`), or `nil` if no clip exists.
    public var notificationSoundFilename: String? {
        guard notificationSoundURL != nil else { return nil }
        let baseName = (filename as NSString).deletingPathExtension
        return "\(baseName)_notif.mp3"
    }
}
