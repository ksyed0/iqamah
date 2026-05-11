import SwiftUI
import IqamahCore

struct HilalCriterionPicker: View {
    @Binding var selectedCriterion: CriterionChoice

    enum CriterionChoice: String, CaseIterable, Identifiable {
        case odeh = "Odeh"
        case yallop = "Yallop"
        case hmnao = "HMNAO"

        var id: String { rawValue }

        var criterion: any VisibilityCriterion & Sendable {
            switch self {
            case .odeh: OdehCriterion.shared
            case .yallop: YallopCriterion.shared
            case .hmnao: HMNAOCriterion.shared
            }
        }
    }

    var body: some View {
        Picker("Criterion", selection: $selectedCriterion) {
            ForEach(CriterionChoice.allCases) { choice in
                Text(choice.rawValue).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }
}
