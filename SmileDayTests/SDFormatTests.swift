import XCTest
import CoachingKit
@testable import SmileDay

/// 화면에 시간을 적는 두 규칙.
///
/// 둘은 일부러 다르다. 이 테스트가 그 차이를 고정한다 — 하나로 합치려는 시도가 있으면
/// 여기서 걸린다.
final class SDFormatTests: XCTestCase {

    // MARK: - 흘러간 시간

    func test_duration_1분_미만은_초로_적는다() {
        XCTAssertEqual(SDFormat.duration(seconds: 0), "0초")
        XCTAssertEqual(SDFormat.duration(seconds: 1), "1초")
        XCTAssertEqual(SDFormat.duration(seconds: 59), "59초")
    }

    /// 나머지가 0이면 "1분 0초"가 아니라 "1분"이다.
    func test_duration_딱_떨어지면_분만_적는다() {
        XCTAssertEqual(SDFormat.duration(seconds: 60), "1분")
        XCTAssertEqual(SDFormat.duration(seconds: 180), "3분")
        XCTAssertEqual(SDFormat.duration(seconds: 3_600), "60분")
    }

    func test_duration_나머지가_있으면_함께_적는다() {
        XCTAssertEqual(SDFormat.duration(seconds: 90), "1분 30초")
        XCTAssertEqual(SDFormat.duration(seconds: 61), "1분 1초")
    }

    /// 설정 화면의 알림 간격 선택지가 전부 읽을 수 있는 문구로 나온다.
    func test_duration_알림간격_선택지가_모두_자연스럽다() {
        let labels = LiveSmileNudgeSettings.allowedIntervalSeconds.map {
            SDFormat.duration(seconds: $0)
        }
        XCTAssertEqual(labels, ["30초", "1분", "1분 30초", "2분", "3분"])
    }

    // MARK: - 반복 주기

    // 이 아래는 로케일을 탄다. `reminderInterval`은 길이를 `Duration` 포맷으로 그리고 "마다"를
    // 카탈로그에서 가져오므로, 한국어 문구는 앱을 호스트한 시뮬레이터가 한국어일 때 나온다.
    // 예전의 손 계산 결과와 글자까지 같아야 한다 — 이 테스트가 그 동등성을 고정한다.

    /// 30분을 `분 / 60`으로 적으면 "0시간마다"가 된다. 한 시간 미만은 분으로 나와야 한다.
    func test_reminderInterval_한시간_미만은_분으로_적는다() {
        XCTAssertEqual(SDFormat.reminderInterval(minutes: 30), "30분마다")
        XCTAssertEqual(SDFormat.reminderInterval(minutes: 59), "59분마다")
    }

    func test_reminderInterval_한시간_이상은_시간으로_적는다() {
        XCTAssertEqual(SDFormat.reminderInterval(minutes: 60), "1시간마다")
        XCTAssertEqual(SDFormat.reminderInterval(minutes: 240), "4시간마다")
    }

    /// 설정에서 고를 수 있는 주기가 전부 "0시간마다" 같은 문구를 만들지 않는다.
    func test_reminderInterval_허용된_주기가_모두_자연스럽다() {
        let labels = SmileReminderPattern.allowedIntervals.map {
            SDFormat.reminderInterval(minutes: $0)
        }
        XCTAssertEqual(labels, ["30분마다", "1시간마다", "2시간마다", "3시간마다", "4시간마다"])
        XCTAssertFalse(labels.contains { $0.hasPrefix("0") })
    }
}
