import Foundation

/// Result of evaluating today against the user's Fasting Mode settings.
/// Pure-data; computed by FastingModeEngine; consumed by every surface.
public struct FastingDayState: Equatable, Codable, Hashable {
    /// Is today a fasting day (after prohibition filter)?
    public let isActive: Bool
    /// Why today is active. Nil when isActive == false.
    public let trigger: FastingTriggerKind?
    /// Hard-prohibited override. When non-nil, isActive is false regardless of triggers.
    public let prohibition: ProhibitedDay?
    /// The day this state describes (midnight in the evaluation timezone).
    public let date: Date

    public init(
        isActive: Bool,
        trigger: FastingTriggerKind?,
        prohibition: ProhibitedDay?,
        date: Date
    ) {
        self.isActive = isActive
        self.trigger = trigger
        self.prohibition = prohibition
        self.date = date
    }

    /// Convenience constructor for the inactive case.
    public static func inactive(date: Date) -> FastingDayState {
        FastingDayState(isActive: false, trigger: nil, prohibition: nil, date: date)
    }
}

public enum FastingTriggerKind: String, Codable, Hashable, CaseIterable {
    case autoRamadan
    case weeklySchedule
    case ayyamAlBeed
    case sixDaysShawwal
    case dayOfArafah
    case firstNineDhulHijjah
    case muharramFast
    case midShaban
    case mabath
}

public enum ProhibitedDay: String, Codable, Hashable, CaseIterable {
    case eidAlFitr // 1 Shawwal
    case eidAlAdha // 10 Dhul-Hijjah
    case tashriq11 // 11 Dhul-Hijjah
    case tashriq12 // 12 Dhul-Hijjah
    case tashriq13 // 13 Dhul-Hijjah

    public var displayName: String {
        switch self {
        case .eidAlFitr: "Eid al-Fitr"
        case .eidAlAdha: "Eid al-Adha"
        case .tashriq11: "11 Dhul-Hijjah (Tashriq)"
        case .tashriq12: "12 Dhul-Hijjah (Tashriq)"
        case .tashriq13: "13 Dhul-Hijjah (Tashriq)"
        }
    }
}

/// User-configurable Fasting Mode settings, persisted as a single JSON blob
/// in UserDefaults under Keys.fastingModeSettings and KVS-synced.
public struct FastingModeSettings: Codable, Equatable {
    public var enabled: Bool
    public var autoRamadan: Bool
    /// Calendar weekday integers (1=Sun, 2=Mon, …, 7=Sat) per Calendar.component(.weekday).
    public var weeklyDays: Set<Int>
    public var ayyamAlBeed: Bool
    public var sixDaysShawwal: Bool
    public var dayOfArafah: Bool
    public var firstNineDhulHijjah: Bool
    public var muharramFast: Bool
    /// 15 Sha'ban — engine suppresses when !calculationMethod.isShiaMethod.
    public var midShaban: Bool
    /// 27 Rajab (Mab'ath) — engine suppresses when !calculationMethod.isShiaMethod.
    public var mabath: Bool
    /// Lead time before Fajr for Suhoor notification, in minutes (5–120, step 5).
    public var suhoorLeadMinutes: Int
    /// Lead time before Maghrib for Iftar notification, in minutes (5–120, step 5).
    public var iftarLeadMinutes: Int
    /// When true, day-before reminder is scheduled.
    public var dayBeforeEnabled: Bool
    /// Time of day for day-before reminder. Default 20:00 (8 PM).
    public var dayBeforeHour: Int
    public var dayBeforeMinute: Int
    /// Master switch for all three reminder kinds (Suhoor, Iftar, day-before).
    public var notificationsEnabled: Bool

    public init(
        enabled: Bool = false,
        autoRamadan: Bool = true,
        weeklyDays: Set<Int> = [],
        ayyamAlBeed: Bool = false,
        sixDaysShawwal: Bool = false,
        dayOfArafah: Bool = false,
        firstNineDhulHijjah: Bool = false,
        muharramFast: Bool = false,
        midShaban: Bool = false,
        mabath: Bool = false,
        suhoorLeadMinutes: Int = 30,
        iftarLeadMinutes: Int = 15,
        dayBeforeEnabled: Bool = true,
        dayBeforeHour: Int = 20,
        dayBeforeMinute: Int = 0,
        notificationsEnabled: Bool = true
    ) {
        self.enabled = enabled
        self.autoRamadan = autoRamadan
        self.weeklyDays = weeklyDays
        self.ayyamAlBeed = ayyamAlBeed
        self.sixDaysShawwal = sixDaysShawwal
        self.dayOfArafah = dayOfArafah
        self.firstNineDhulHijjah = firstNineDhulHijjah
        self.muharramFast = muharramFast
        self.midShaban = midShaban
        self.mabath = mabath
        self.suhoorLeadMinutes = suhoorLeadMinutes
        self.iftarLeadMinutes = iftarLeadMinutes
        self.dayBeforeEnabled = dayBeforeEnabled
        self.dayBeforeHour = dayBeforeHour
        self.dayBeforeMinute = dayBeforeMinute
        self.notificationsEnabled = notificationsEnabled
    }

    // MARK: - Forward-compatible decoding
    //
    // Synthesized Codable throws `keyNotFound` for any absent field, which would
    // break users upgrading from an earlier version whose persisted JSON predates
    // a newly-added field. Decode each field with `decodeIfPresent` and fall back
    // to the same defaults the memberwise `init(...)` uses.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false,
            autoRamadan: try c.decodeIfPresent(Bool.self, forKey: .autoRamadan) ?? true,
            weeklyDays: try c.decodeIfPresent(Set<Int>.self, forKey: .weeklyDays) ?? [],
            ayyamAlBeed: try c.decodeIfPresent(Bool.self, forKey: .ayyamAlBeed) ?? false,
            sixDaysShawwal: try c.decodeIfPresent(Bool.self, forKey: .sixDaysShawwal) ?? false,
            dayOfArafah: try c.decodeIfPresent(Bool.self, forKey: .dayOfArafah) ?? false,
            firstNineDhulHijjah: try c.decodeIfPresent(Bool.self, forKey: .firstNineDhulHijjah) ?? false,
            muharramFast: try c.decodeIfPresent(Bool.self, forKey: .muharramFast) ?? false,
            midShaban: try c.decodeIfPresent(Bool.self, forKey: .midShaban) ?? false,
            mabath: try c.decodeIfPresent(Bool.self, forKey: .mabath) ?? false,
            suhoorLeadMinutes: try c.decodeIfPresent(Int.self, forKey: .suhoorLeadMinutes) ?? 30,
            iftarLeadMinutes: try c.decodeIfPresent(Int.self, forKey: .iftarLeadMinutes) ?? 15,
            dayBeforeEnabled: try c.decodeIfPresent(Bool.self, forKey: .dayBeforeEnabled) ?? true,
            dayBeforeHour: try c.decodeIfPresent(Int.self, forKey: .dayBeforeHour) ?? 20,
            dayBeforeMinute: try c.decodeIfPresent(Int.self, forKey: .dayBeforeMinute) ?? 0,
            notificationsEnabled: try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        )
    }

    /// Friday in weeklyDays without Thursday or Saturday — discouraged in many traditions.
    public var hasFridayAloneWarning: Bool {
        weeklyDays.contains(6) && !weeklyDays.contains(5) && !weeklyDays.contains(7)
    }

    /// Saturday in weeklyDays without Friday — canonical Sunnah pairing is Fri+Sat.
    public var hasSaturdayAloneWarning: Bool {
        weeklyDays.contains(7) && !weeklyDays.contains(6)
    }
}
