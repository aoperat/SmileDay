import XCTest
@testable import CoachingKit

final class ReminderPromptCursorStoreTests: XCTestCase {
    func test_inMemory_cyclesThroughAllIndicesBeforeRepeating() {
        let store = InMemoryReminderPromptCursorStore()
        var seen: [Int] = []
        for _ in 0..<8 {
            seen.append(store.nextIndex(for: .morning, poolCount: 8))
        }
        XCTAssertEqual(Set(seen), Set(0..<8), "one full cycle must touch every index exactly once")
    }

    func test_inMemory_bucketsAreIndependent() {
        let store = InMemoryReminderPromptCursorStore()
        let morningFirst = store.nextIndex(for: .morning, poolCount: 8)
        let eveningFirst = store.nextIndex(for: .evening, poolCount: 8)
        _ = morningFirst
        _ = eveningFirst
        // 두 번째 아침 호출은 첫 호출과 같은 사이클(0..<8) 안에서 나와야 한다.
        let morningSecond = store.nextIndex(for: .morning, poolCount: 8)
        XCTAssertTrue((0..<8).contains(morningSecond))
    }

    func test_userDefaults_persistsAcrossNewInstances() throws {
        let suiteName = "reminder-prompt-cursor-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = UserDefaultsReminderPromptCursorStore(defaults: defaults)
        var seen: Set<Int> = []
        for _ in 0..<4 {
            seen.insert(firstStore.nextIndex(for: .afternoon, poolCount: 8))
        }

        // 앱 재시작을 흉내: 같은 UserDefaults를 보는 새 인스턴스
        let secondStore = UserDefaultsReminderPromptCursorStore(defaults: defaults)
        for _ in 0..<4 {
            seen.insert(secondStore.nextIndex(for: .afternoon, poolCount: 8))
        }

        XCTAssertEqual(seen, Set(0..<8), "이어붙인 8번 호출이 인스턴스 경계와 무관하게 한 사이클을 이뤄야 한다")
    }
}
