import Foundation

// MARK: - Input struct

/// The geometric parameters needed to evaluate any crescent visibility criterion.
public struct CrescentGeometry {
    /// Arc of Light (ARCL): angular separation between Moon and Sun centres, degrees.
    public let arcl: Double
    /// Arc of Vision (ARCV): Moon altitude above the horizon at sunset, degrees.
    public let arcv: Double
    /// Crescent width W, arcminutes.
    public let widthArcmin: Double
    /// Moon distance from Earth centre, km.
    public let moonDistanceKm: Double

    public init(arcl: Double, arcv: Double, widthArcmin: Double, moonDistanceKm: Double) {
        self.arcl = arcl
        self.arcv = arcv
        self.widthArcmin = widthArcmin
        self.moonDistanceKm = moonDistanceKm
    }
}

// MARK: - Visibility category

public enum VisibilityCategory: Int, Comparable, CaseIterable {
    /// Not visible / below horizon
    case D = 1
    /// May need optical aid
    case C = 2
    /// Visible under good conditions
    case B = 3
    /// Easily visible naked eye
    case A = 4

    public static func < (lhs: VisibilityCategory, rhs: VisibilityCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .A: "Easily visible"
        case .B: "Visible under good conditions"
        case .C: "May need optical aid"
        case .D: "Not visible"
        }
    }
}

// MARK: - Protocol

public protocol VisibilityCriterion {
    var name: String { get }
    func evaluate(_ geometry: CrescentGeometry) -> VisibilityCategory
}

// MARK: - Odeh (2004)

/// Odeh (2004) criterion — see criterion-coefficients-references.json for source verification.
/// V = ARCV − (−0.1018·W³ + 0.7319·W² − 6.3226·W + 7.1651)
/// A: V ≥ 5.65 | B: 2.00 ≤ V < 5.65 | C: −0.96 ≤ V < 2.00 | D: V < −0.96
public struct OdehCriterion: VisibilityCriterion {
    public static let shared = OdehCriterion()
    public init() {}
    public let name = "Odeh (2004)"

    public func evaluate(_ g: CrescentGeometry) -> VisibilityCategory {
        let W = g.widthArcmin
        let poly = -0.1018 * W * W * W + 0.7319 * W * W - 6.3226 * W + 7.1651
        let V = g.arcv - poly
        switch V {
        case let v where v >= 5.65: return .A
        case let v where v >= 2.00: return .B
        case let v where v >= -0.96: return .C
        default: return .D
        }
    }
}

// MARK: - Yallop (1997)

/// Yallop (1997) criterion — NAO Technical Note No. 69.
/// q = (ARCV − (11.8371 − 6.3226·ARCL + 0.7319·ARCL² − 0.1018·ARCL³)) / 10
/// Maps Yallop's 6 categories (A–F) to VisibilityCategory:
///   Yallop A(q≥+0.216)→A | B(≥-0.014)→B | C(≥-0.160)→B | D(≥-0.232)→C | E(≥-0.293)→C | F→D
public struct YallopCriterion: VisibilityCriterion {
    public static let shared = YallopCriterion()
    public init() {}
    public let name = "Yallop (1997)"

    public func evaluate(_ g: CrescentGeometry) -> VisibilityCategory {
        let a = g.arcl
        let poly = 11.8371 - 6.3226 * a + 0.7319 * a * a - 0.1018 * a * a * a
        let q = (g.arcv - poly) / 10.0
        switch q {
        case let v where v >= 0.216: return .A // Yallop A
        case let v where v >= -0.014: return .B // Yallop B
        case let v where v >= -0.232: return .C // Yallop C/D
        default: return .D // Yallop E/F
        }
    }
}

// MARK: - HMNAO Enhanced

/// HMNAO Enhanced Danjon criterion.
/// Same q-value polynomial as Yallop; simplified 4-category boundary scheme.
/// q ≥ -0.014 → naked-eye visible (A or B) | q < -0.232 → not visible (D)
public struct HMNAOCriterion: VisibilityCriterion {
    public static let shared = HMNAOCriterion()
    public init() {}
    public let name = "HMNAO Enhanced"

    public func evaluate(_ g: CrescentGeometry) -> VisibilityCategory {
        let a = g.arcl
        let poly = 11.8371 - 6.3226 * a + 0.7319 * a * a - 0.1018 * a * a * a
        let q = (g.arcv - poly) / 10.0
        switch q {
        case let v where v >= 0.216: return .A
        case let v where v >= -0.014: return .B
        case let v where v >= -0.232: return .C
        default: return .D
        }
    }
}
