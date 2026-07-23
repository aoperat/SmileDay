import Foundation

public protocol ReminderPromptCursorStoring: AnyObject {
    /// 주어진 버킷에서 다음으로 꺼낼 문구의 인덱스를 반환한다.
    /// poolCount개를 다 꺼내면 순서를 다시 섞어 새 사이클을 시작한다.
    func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int
}

/// 순환 상태(섞인 순서 + 다음 위치)를 계산하는 순수 로직. 저장 방식과 분리해 in-memory/UserDefaults 양쪽에서 재사용한다.
struct ReminderPromptCursorState {
    var order: [Int]
    var position: Int

    static func advancing(from current: ReminderPromptCursorState?, poolCount: Int) -> (index: Int, state: ReminderPromptCursorState) {
        guard poolCount > 0 else {
            return (0, ReminderPromptCursorState(order: [], position: 0))
        }

        var state = current ?? ReminderPromptCursorState(order: Array(0..<poolCount).shuffled(), position: 0)
        if state.order.count != poolCount || state.position >= state.order.count {
            state = ReminderPromptCursorState(order: Array(0..<poolCount).shuffled(), position: 0)
        }

        let index = state.order[state.position]
        state.position += 1
        return (index, state)
    }
}

public final class InMemoryReminderPromptCursorStore: ReminderPromptCursorStoring {
    private var states: [TimeBucket: ReminderPromptCursorState] = [:]

    public init() {}

    public func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int {
        let (index, state) = ReminderPromptCursorState.advancing(from: states[bucket], poolCount: poolCount)
        states[bucket] = state
        return index
    }
}

public final class UserDefaultsReminderPromptCursorStore: ReminderPromptCursorStoring {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int {
        let orderKey = "reminderPromptOrder_\(bucket.rawValue)"
        let positionKey = "reminderPromptPosition_\(bucket.rawValue)"

        let storedOrder = defaults.array(forKey: orderKey) as? [Int]
        let current = storedOrder.map {
            ReminderPromptCursorState(order: $0, position: defaults.integer(forKey: positionKey))
        }

        let (index, state) = ReminderPromptCursorState.advancing(from: current, poolCount: poolCount)
        defaults.set(state.order, forKey: orderKey)
        defaults.set(state.position, forKey: positionKey)
        return index
    }
}
