#if os(iOS)
    import IqamahCore
    import Foundation

    /// Computes the Hilal grid in the background when the app becomes active,
    /// so HilalWatchSheet shows results instantly without a loading delay.
    @MainActor
    final class HilalWatchPreloader: ObservableObject {
        static let shared = HilalWatchPreloader()

        @Published private(set) var grid: ContiguousArray<Int8> =
            ContiguousArray(repeating: 1, count: HilalCalculator.cellCount)
        @Published private(set) var localCard: LocalSightingValues?
        @Published private(set) var isReady = false
        @Published private(set) var newMoonDate: Date = Date()

        // Evening and criterion for which the cached grid was computed
        private var cachedEvening: Evening?
        private var cachedCriterion: String?

        private var activeTask: Task<Void, Never>?

        /// Call from app-active / app-appear to start background computation.
        func prefetch(settings: SettingsManager,
                      evening: Evening = .d29,
                      criterionChoice: HilalCriterionPicker.CriterionChoice = .odeh) {
            let criterion = criterionChoice.criterion
            let criterionID = criterionChoice.id

            // Skip if already cached for same params
            if cachedEvening == evening, cachedCriterion == criterionID, isReady {
                return
            }

            activeTask?.cancel()
            isReady = false

            activeTask = Task(priority: .background) { [weak self] in
                guard let self else { return }
                let prev = NewMoon.previous(before: Date())
                let req = HilalGridRequest(
                    newMoonJD: prev.julianDay,
                    evening: evening,
                    criterion: criterion
                )
                let computed = await HilalCalculator.shared.computeGrid(req)
                guard !Task.isCancelled else { return }

                var card: LocalSightingValues?
                if let coord = settings.activeCoordinate {
                    let offset = evening == .d29 ? 1.0 : 2.0
                    let date = Date.fromJulianDay(prev.julianDay + offset)
                    card = HilalCalculator.shared.computeLocalCard(
                        date: date,
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        criterion: criterion
                    )
                }

                grid = computed
                localCard = card
                newMoonDate = prev
                cachedEvening = evening
                cachedCriterion = criterionID
                isReady = true
            }
        }
    }
#endif
