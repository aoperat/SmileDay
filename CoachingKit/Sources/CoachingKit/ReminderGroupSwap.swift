import Foundation

/// 반복 알림 그룹을 통째로 갈아끼우는 한 번의 거래.
///
/// **순서가 전부다.** 새 `groupID`로 전부 등록한 뒤에야 저장값을 교체하고, 옛 그룹은 맨 마지막에
/// 취소한다. 같은 identifier를 덮어쓰다가 중간에 실패하면 scheduler의 부분 등록 롤백이 이미
/// 존재하던 요청까지 지울 수 있다. 새 그룹을 쓰면 실패한 요청만 정리되고 옛 알림은 온전히 남는다.
///
/// 이 순서를 필요로 하는 곳이 둘이다 — 설정 화면의 저장(`SmileReminderScheduleViewModel`)과
/// 알림 버튼 보정(`ReminderActionBackfill`). 예전에는 양쪽에 같은 스무 줄이 따로 있어서,
/// 한쪽의 실패 경로를 고쳐도 다른 쪽은 옛 순서를 그대로 들고 있었다.
struct ReminderGroupSwap {
    /// 어디서 실패했는지. 호출자마다 사용자에게 하는 말이 달라서 이유를 구분해 돌려준다.
    enum Failure: Error {
        /// 새 그룹을 등록하지 못했다. **저장값과 기존 알림은 건드리지 않았다** —
        /// 사용자는 알림을 하나도 잃지 않는다.
        case scheduling
        /// 등록은 됐지만 저장에 실패했다. 방금 등록한 그룹은 되돌렸고 기존 알림은 그대로다.
        case persistence(Error)
    }

    let scheduleRepository: SmileReminderScheduleRepository
    let scheduler: ReminderScheduling
    let groupIDFactory: () -> String

    init(
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        groupIDFactory: @escaping () -> String
    ) {
        self.scheduleRepository = scheduleRepository
        self.scheduler = scheduler
        self.groupIDFactory = groupIDFactory
    }

    /// 성공하면 새로 저장된 그룹 ID.
    ///
    /// `previousGroupID`가 새 ID와 같으면 취소하지 않는다. 실제로는 UUID라 겹칠 일이 없지만,
    /// 고정 ID를 주는 팩토리를 끼우면 방금 등록한 알림을 스스로 지우게 된다.
    @discardableResult
    func run(
        pattern: SmileReminderPattern,
        messages: [ReminderMessage],
        previousGroupID: String?
    ) async throws -> String {
        let newGroupID = groupIDFactory()

        do {
            try await scheduler.scheduleDailyPattern(
                groupID: newGroupID,
                times: pattern.occurrences(),
                messages: messages
            )
        } catch {
            throw Failure.scheduling
        }

        do {
            _ = try scheduleRepository.save(
                pattern: pattern,
                isEnabled: true,
                notificationGroupID: newGroupID
            )
        } catch {
            scheduler.cancelGroup(id: newGroupID)
            throw Failure.persistence(error)
        }

        if let previousGroupID, previousGroupID != newGroupID {
            scheduler.cancelGroup(id: previousGroupID)
        }
        return newGroupID
    }
}
