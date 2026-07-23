import Foundation
import SwiftData

/// 케어 루틴 재생 기록. 완주뿐 아니라 중도 이탈도 남긴다 (wasCompleted로 구분).
@Model
public final class CareSession {
    public var date: Date
    public var routineID: String

    // 행동 데이터 (2026-07 데이터 수집 확장). 구버전 레코드는 nil.
    public var startedAt: Date?
    public var durationSeconds: Double?
    public var completedSteps: Int?
    public var totalSteps: Int?
    /// 기본값 true — 확장 전 레코드는 전부 완주 기록이었다.
    public var wasCompleted: Bool = true

    public init(
        date: Date,
        routineID: String,
        startedAt: Date? = nil,
        durationSeconds: Double? = nil,
        completedSteps: Int? = nil,
        totalSteps: Int? = nil,
        wasCompleted: Bool = true
    ) {
        self.date = date
        self.routineID = routineID
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.wasCompleted = wasCompleted
    }
}
