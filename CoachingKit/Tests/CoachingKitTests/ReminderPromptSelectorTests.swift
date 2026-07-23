import XCTest
@testable import CoachingKit

final class ReminderPromptSelectorTests: XCTestCase {
    func test_nextPrompt_returnsPromptMatchingHourBucket() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        let prompt = selector.nextPrompt(forHour: 9)
        XCTAssertEqual(prompt.bucket, .morning)
        XCTAssertTrue(ReminderPromptCatalog.prompts(for: .morning).contains(prompt))
    }

    func test_nextPrompt_cyclesThroughAllEightBeforeRepeating() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        let texts = (0..<8).map { _ in selector.nextPrompt(forHour: 20).text }
        let eveningTexts = Set(ReminderPromptCatalog.prompts(for: .evening).map(\.text))
        XCTAssertEqual(Set(texts), eveningTexts)
    }

    func test_nextPrompt_differentHoursInSameBucketShareCursor() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        // 낮 12시, 낮 15시 두 리마인더가 같은 버킷 커서를 공유해야 한다.
        let first = selector.nextPrompt(forHour: 12)
        let second = selector.nextPrompt(forHour: 15)
        XCTAssertNotEqual(first.text, second.text)
    }
}
