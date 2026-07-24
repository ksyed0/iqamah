import Foundation
import IqamahCore
import Testing
import UserNotifications
@testable import IqamahWatch

// MARK: - Mock notification center

@MainActor
final class MockWatchNotificationCenter: WatchNotificationCenterProtocol {
    var addedRequests: [UNNotificationRequest] = []
    var removeAllCallCount = 0
    var removedIdentifiers: [String] = []
    var authorizationGranted = true

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removeAllPendingNotificationRequests() {
        addedRequests.removeAll()
        removeAllCallCount += 1
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        addedRequests.removeAll { identifiers.contains($0.identifier) }
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequests
    }
}

// MARK: - Shared stub

extension SettingsManager {
    static func watchStub(cityName: String = "Toronto") -> SettingsManager {
        let s = SettingsManager()
        if let city = try? City(
            name: cityName, countryCode: "CA",
            latitude: 43.6534, longitude: -79.3834,
            timezone: "America/Toronto"
        ) {
            s.saveCity(city)
        }
        s.calculationMethod = .isna
        s.asrMethod = .standard
        return s
    }
}

// MARK: - Tests

@Suite("WatchNotificationScheduler")
@MainActor
struct WatchNotificationSchedulerTests {

    @Test("schedules requests for a valid city")
    func schedulesForValidCity() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        #expect(center.addedRequests.count > 0)
        #expect(center.addedRequests.count <= 35)
    }

    @Test("produces no requests when authorization denied")
    func noRequestsWhenDenied() async {
        let center = MockWatchNotificationCenter()
        center.authorizationGranted = false
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        #expect(center.addedRequests.isEmpty)
    }

    @Test("produces no requests when no city is set")
    func noRequestsWithoutCity() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: SettingsManager())
        #expect(center.addedRequests.isEmpty)
    }

    @Test("Sunrise is never scheduled")
    func sunriseNeverScheduled() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        let sunriseRequests = center.addedRequests.filter { $0.identifier.contains("Sunrise") }
        #expect(sunriseRequests.isEmpty)
    }

    @Test("each request uses a calendar trigger with hour and minute")
    func allRequestsUseCalendarTrigger() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        for request in center.addedRequests {
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                Issue.record("Expected UNCalendarNotificationTrigger for \(request.identifier)")
                continue
            }
            #expect(trigger.dateComponents.hour != nil)
            #expect(trigger.dateComponents.minute != nil)
        }
    }

    @Test("cancel clears all added requests")
    func cancelClearsRequests() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        #expect(center.addedRequests.count > 0)
        scheduler.cancel()
        #expect(center.addedRequests.isEmpty)
    }

    @Test("second rescheduleAll removes previous requests first")
    func removesBeforeRescheduling() async {
        let center = MockWatchNotificationCenter()
        let scheduler = WatchNotificationScheduler(center: center)
        await scheduler.rescheduleAll(settings: .watchStub())
        let firstCount = center.addedRequests.count
        await scheduler.rescheduleAll(settings: .watchStub())
        #expect(center.removeAllCallCount == 2)
        #expect(center.addedRequests.count == firstCount)
    }
}
