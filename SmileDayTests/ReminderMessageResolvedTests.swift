import XCTest
@testable import SmileDay
import CoachingKit

/// 기본 알림 문구가 실제로 카탈로그에서 해석되는지 본다 (JSON에 키가 있는지는 CoachingKit 테스트가 본다).
final class ReminderMessageResolvedTests: XCTestCase {
    func test_everyDefault_resolvesToCopy_notToItsKey() {
        for message in ReminderMessageCatalog.defaults {
            let text = message.resolvedText
            XCTAssertFalse(text.isEmpty, message.id)
            XCTAssertFalse(text.hasPrefix("reminderMessage."), "\(message.id) rendered its key")
        }
    }

    func test_userText_passesThroughUntouched() {
        XCTAssertEqual(ReminderMessage(id: "x", text: "내가 쓴 문구").resolvedText, "내가 쓴 문구")
    }
}
