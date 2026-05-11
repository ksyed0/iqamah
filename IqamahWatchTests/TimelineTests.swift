import Foundation
import IqamahCore
import Testing
import WidgetKit

@Suite("Complication Timeline Tests")
struct TimelineTests {
    private func seedDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "test.timeline.\(UUID().uuidString)")!
        suite.set("manual", forKey: "locationSource")
        suite.set("Riyadh", forKey: "selectedCityName")
        suite.set("SA", forKey: "selectedCityCountryCode")
        suite.set(24.6877, forKey: "selectedCityLatitude")
        suite.set(46.7219, forKey: "selectedCityLongitude")
        suite.set("Asia/Riyadh", forKey: "selectedCityTimezone")
        suite.set("isna", forKey: "calculationMethod")
        suite.set("standard", forKey: "asrMethod")
        return suite
    }

    @Test("Timeline generates at least 10 entries covering today + tomorrow")
    func timelineEntriesCount() throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        // Use start-of-day to ensure all 5 prayers for today are in the future
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let startOfDay = cal.startOfDay(for: Date())
        let entries = provider.buildEntries(from: startOfDay)
        #expect(entries.count >= 10, "Expected ≥10 entries, got \(entries.count)")
    }

    @Test("Timeline refresh policy equals nextPrayerTime of the last entry")
    func timelineRefreshPolicy() throws {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        let lastEntry = try #require(entries.last)
        let policy = provider.refreshPolicy(for: entries)
        // TimelineReloadPolicy is a struct (not enum); compare via .after factory
        #expect(policy == .after(lastEntry.nextPrayerTime),
                "Expected refresh policy .after(\(lastEntry.nextPrayerTime))")
    }

    @Test("All entries have non-empty cityName and methodName")
    func prayerEntryFieldsNonEmpty() {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        for entry in entries {
            #expect(!entry.cityName.isEmpty, "cityName is empty in entry for \(entry.nextPrayerName)")
            #expect(!entry.methodName.isEmpty, "methodName is empty in entry for \(entry.nextPrayerName)")
        }
    }

    @Test("No entry has nextPrayerTime in the past relative to entry.date")
    func nextPrayerIsAlwaysInFuture() {
        let defaults = seedDefaults()
        let provider = PrayerTimelineProvider(defaults: defaults)
        let entries = provider.buildEntries(from: Date())
        for entry in entries {
            #expect(
                entry.nextPrayerTime >= entry.date,
                "\(entry.nextPrayerName) at \(entry.nextPrayerTime) is before entry.date \(entry.date)"
            )
        }
    }

    @Test("placeholder returns stub without crashing on empty App Group")
    func emptyAppGroupShowsPlaceholder() throws {
        let empty = try #require(UserDefaults(suiteName: "test.empty.\(UUID().uuidString)"))
        let provider = PrayerTimelineProvider(defaults: empty)
        let stub = provider.placeholder()
        #expect(!stub.nextPrayerName.isEmpty)
        #expect(stub.cityName == "—")
    }
}
