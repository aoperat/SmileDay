import Foundation
import Observation

public struct CareRecommendation: Equatable {
    public let routine: CareRoutine
    public let reason: String

    public init(routine: CareRoutine, reason: String) {
        self.routine = routine
        self.reason = reason
    }
}

/// 즐겨찾기 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol CareFavoritesStoring: AnyObject {
    var favoriteRoutineIDs: Set<String> { get set }
}

public final class UserDefaultsCareFavorites: CareFavoritesStoring {
    private static let key = "careFavoriteRoutineIDs"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var favoriteRoutineIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.key) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.key) }
    }
}

public final class InMemoryCareFavorites: CareFavoritesStoring {
    public var favoriteRoutineIDs: Set<String> = []
    public init() {}
}

@Observable
public final class CareViewModel {
    public private(set) var recommendation: CareRecommendation?
    public private(set) var favoriteIDs: Set<String> = []
    /// nil이면 전체.
    public var selectedCategory: CareCategory?

    public let routines: [CareRoutine]

    private let sessionRepository: SessionRepository
    private let careRepository: CareRepository
    private let favorites: CareFavoritesStoring
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        sessionRepository: SessionRepository,
        careRepository: CareRepository,
        favorites: CareFavoritesStoring,
        routines: [CareRoutine] = CareRoutine.catalog,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.sessionRepository = sessionRepository
        self.careRepository = careRepository
        self.favorites = favorites
        self.routines = routines
        self.calendar = calendar
        self.now = now
    }

    public var filteredRoutines: [CareRoutine] {
        guard let selectedCategory else { return routines }
        return routines.filter { $0.category == selectedCategory }
    }

    public func refresh() throws {
        favoriteIDs = favorites.favoriteRoutineIDs
        recommendation = try makeRecommendation()
    }

    public func toggleFavorite(_ routineID: String) {
        var ids = favorites.favoriteRoutineIDs
        if ids.contains(routineID) {
            ids.remove(routineID)
        } else {
            ids.insert(routineID)
        }
        favorites.favoriteRoutineIDs = ids
        favoriteIDs = ids
    }

    public func completeRoutine(_ routine: CareRoutine) throws {
        try careRepository.saveCompletion(routineID: routine.id, date: now())
    }

    /// 어제 측정값 기반 추천. 기록이 없으면 첫 케어 안내.
    private func makeRecommendation() throws -> CareRecommendation? {
        guard let lift = routines.first(where: { $0.category == .lift }) else { return nil }

        let today = calendar.startOfDay(for: now())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let session = try sessionRepository.fetchLatestCheckIn(onDayOf: yesterday, calendar: calendar)
        else {
            return CareRecommendation(
                routine: lift,
                reason: "첫 케어로 입꼬리 근육을 깨워봐요. 측정을 쌓으면 맞춤 추천을 드려요."
            )
        }

        let score = ScoreCalculator.displayValue(session.scoreDelta)
        let scoreText = String(format: "%.1f", score)
        if score < 0 {
            return CareRecommendation(
                routine: lift,
                reason: "어제 \(scoreText)°로 내려갔어요. 리프팅으로 다시 끌어올려봐요."
            )
        }
        return CareRecommendation(
            routine: lift,
            reason: "어제 +\(scoreText)°였어요. 입꼬리 근육을 깨우는 리프팅으로 오늘 기록을 올려봐요."
        )
    }
}
