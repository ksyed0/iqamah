import Foundation

// MARK: - Evening

/// The two evenings on which crescent sighting is attempted.
public enum Evening: String, CaseIterable, Sendable {
    /// 29th of the Hijri month — first watch evening.
    case d29
    /// 30th of the Hijri month — second (fallback) watch evening.
    case d30
}

// MARK: - HilalGridRequest

/// Input parameters for a `HilalCalculator` grid computation.
public struct HilalGridRequest: Sendable {
    /// The Julian Day of the new moon that precedes these watch evenings.
    public let newMoonJD: Double
    /// Which evening to compute (29th or 30th).
    public let evening: Evening
    /// The visibility criterion to apply.
    public let criterion: any VisibilityCriterion & Sendable

    public init(newMoonJD: Double, evening: Evening, criterion: any VisibilityCriterion & Sendable) {
        self.newMoonJD = newMoonJD
        self.evening = evening
        self.criterion = criterion
    }
}

// MARK: - LocalSightingValues

/// The precise optical parameters for a single observer location on a watch evening.
public struct LocalSightingValues: Sendable {
    /// Arc of Light (ARCL): angular separation Moon–Sun at sunset, degrees.
    public let arcl: Double
    /// Arc of Vision (ARCV): Moon altitude above the horizon at sunset, degrees.
    public let arcv: Double
    /// Crescent width W, arcminutes.
    public let widthArcmin: Double
    /// Odeh V-value (for Odeh criterion) or Yallop q×10 (for Yallop/HMNAO).
    public let criterionValue: Double
    /// Visibility category from the applied criterion.
    public let category: VisibilityCategory

    public init(arcl: Double, arcv: Double, widthArcmin: Double,
                criterionValue: Double, category: VisibilityCategory) {
        self.arcl = arcl
        self.arcv = arcv
        self.widthArcmin = widthArcmin
        self.criterionValue = criterionValue
        self.category = category
    }
}
