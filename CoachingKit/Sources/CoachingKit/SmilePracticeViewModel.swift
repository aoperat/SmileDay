import Foundation
import Observation

public struct SmilePracticeRecommendation: Equatable {
    public let practice: SmilePractice
    public let reason: String

    public init(practice: SmilePractice, reason: String) {
        self.practice = practice
        self.reason = reason
    }
}

/// 즐겨찾기 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol SmilePracticeFavoritesStoring: AnyObject {
    var favoritePracticeIDs: Set<String> { get set }
}

public final class UserDefaultsSmilePracticeFavorites: SmilePracticeFavoritesStoring {
    /// 기존 키를 그대로 쓴다. 과거 즐겨찾기 ID가 새 카탈로그에 없으면 조용히 무시될 뿐,
    /// 저장된 값을 강제로 지우지 않는다.
    private static let key = "careFavoriteRoutineIDs"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var favoritePracticeIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.key) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.key) }
    }
}

public final class InMemorySmilePracticeFavorites: SmilePracticeFavoritesStoring {
    public var favoritePracticeIDs: Set<String> = []
    public init() {}
}

/// 쉬어가기 탭 상태.
///
/// 추천은 얼굴 지표나 전날 점수가 아니라 지금 시간대와 오늘 이미 쉬어갔는지로만 정한다.
@Observable
public final class SmilePracticeViewModel {
    public private(set) var recommendation: SmilePracticeRecommendation?
    public private(set) var favoriteIDs: Set<String> = []
    /// nil이면 전체.
    public var selectedCategory: SmilePracticeCategory?

    public let practices: [SmilePractice]

    private let careRepository: CareRepository
    private let favorites: SmilePracticeFavoritesStoring
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        careRepository: CareRepository,
        favorites: SmilePracticeFavoritesStoring,
        practices: [SmilePractice] = SmilePractice.catalog,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.careRepository = careRepository
        self.favorites = favorites
        self.practices = practices
        self.calendar = calendar
        self.now = now
    }

    public var filteredPractices: [SmilePractice] {
        guard let selectedCategory else { return practices }
        return practices.filter { $0.category == selectedCategory }
    }

    public func refresh() throws {
        // 새 카탈로그에 없는 과거 ID는 화면에서만 무시한다. 저장된 값은 건드리지 않는다.
        favoriteIDs = favorites.favoritePracticeIDs
        recommendation = try makeRecommendation()
    }

    /// 화면에 표시할 즐겨찾기. 지금 카탈로그에 있는 항목만 남긴다.
    public var visibleFavoriteIDs: Set<String> {
        favoriteIDs.intersection(practices.map(\.id))
    }

    public func toggleFavorite(_ practiceID: String) {
        var ids = favorites.favoritePracticeIDs
        if ids.contains(practiceID) {
            ids.remove(practiceID)
        } else {
            ids.insert(practiceID)
        }
        favorites.favoritePracticeIDs = ids
        favoriteIDs = ids
    }

    public func completePractice(_ practice: SmilePractice, startedAt: Date? = nil) throws {
        let endedAt = now()
        try careRepository.saveSession(
            routineID: practice.id,
            date: endedAt,
            startedAt: startedAt,
            durationSeconds: startedAt.map { endedAt.timeIntervalSince($0) },
            completedSteps: practice.steps.count,
            totalSteps: practice.steps.count,
            wasCompleted: true
        )
    }

    /// 중도 이탈 기록. 스텝을 하나도 못 마친 이탈(열자마자 닫기)은 노이즈라 저장하지 않는다.
    public func abandonPractice(_ practice: SmilePractice, startedAt: Date?, completedSteps: Int) throws {
        guard completedSteps > 0 else { return }
        let endedAt = now()
        try careRepository.saveSession(
            routineID: practice.id,
            date: endedAt,
            startedAt: startedAt,
            durationSeconds: startedAt.map { endedAt.timeIntervalSince($0) },
            completedSteps: completedSteps,
            totalSteps: practice.steps.count,
            wasCompleted: false
        )
    }

    /// 시간대에 어울리는 practice 하나. 오늘 이미 쉬어갔다면 문구만 바뀐다.
    private func makeRecommendation() throws -> SmilePracticeRecommendation? {
        let bucket = TimeBucket(hour: calendar.component(.hour, from: now()))
        guard let practice = preferredPractice(for: bucket) else { return nil }

        if try careRepository.hasCompletion(onDayOf: now(), calendar: calendar) {
            return SmilePracticeRecommendation(
                practice: practice,
                reason: "오늘 이미 한 번 쉬어갔어요. 더 하고 싶으면 편하게 이어가세요."
            )
        }
        return SmilePracticeRecommendation(practice: practice, reason: reason(for: bucket))
    }

    private func preferredPractice(for bucket: TimeBucket) -> SmilePractice? {
        let category = Self.category(for: bucket)
        return practices.first { $0.category == category } ?? practices.first
    }

    /// 아침은 하루 시작, 낮은 숨 고르기, 저녁은 좋은 순간 회고.
    static func category(for bucket: TimeBucket) -> SmilePracticeCategory {
        switch bucket {
        case .morning: .pause
        case .afternoon: .breathe
        case .evening: .recall
        }
    }

    private func reason(for bucket: TimeBucket) -> String {
        switch bucket {
        case .morning: "하루를 여는 짧은 시간이에요."
        case .afternoon: "잠깐 하던 일을 멈추고 숨을 고를까요?"
        case .evening: "오늘 좋았던 순간을 떠올려볼까요?"
        }
    }
}
