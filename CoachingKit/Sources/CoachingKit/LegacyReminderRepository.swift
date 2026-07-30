import Foundation
import SwiftData

/// 개별 알림을 하나씩 등록하던 시절의 저장소.
///
/// 새 흐름은 반복 스케줄 하나만 쓴다. 여기 남은 것은 예전 버전이 이미 예약해둔
/// pending notification을 끄는 데 필요한 최소 조회뿐이다. 추가·수정·삭제는 없다.
public final class LegacyReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 예전 버전이 예약한 알림 식별자. 취소에만 쓴다.
    ///
    /// `isEnabled`를 보지 않는다. 끈 알림도 예약이 남아 있을 수 있어 전부 취소해야 한다.
    public func pendingNotificationIDs() throws -> [String] {
        let descriptor = FetchDescriptor<ReminderSetting>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )
        return try modelContext.fetch(descriptor).map(\.notificationID)
    }
}
