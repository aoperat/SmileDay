import XCTest
@testable import CoachingKit

final class SmilePracticeTests: XCTestCase {
    func test_catalog_hasAtLeastFivePractices() {
        XCTAssertGreaterThanOrEqual(SmilePractice.catalog.count, 5)
    }

    func test_catalog_hasUniqueIDs() {
        let ids = SmilePractice.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// 기존 CareSession에 남은 과거 루틴 ID와 섞이지 않도록 새 ID는 접두사를 쓴다.
    func test_catalog_idsUseSmilePrefix() {
        for practice in SmilePractice.catalog {
            XCTAssertTrue(practice.id.hasPrefix("smile-"), "\(practice.id)는 smile- 접두사를 써야 한다")
        }
    }

    func test_catalog_doesNotCollideWithLegacyRoutineIDs() {
        let legacyIDs: Set<String> = ["lift-smile", "lift-cheek", "relax-brow", "depuff-morning", "morning-1min"]

        XCTAssertTrue(Set(SmilePractice.catalog.map(\.id)).isDisjoint(with: legacyIDs))
    }

    func test_catalog_hasStepsAndPurpose() {
        for practice in SmilePractice.catalog {
            XCTAssertFalse(practice.steps.isEmpty, "\(practice.id)에 단계가 없다")
            XCTAssertFalse(practice.title.isEmpty)
            XCTAssertFalse(practice.purpose.isEmpty)
            XCTAssertGreaterThan(practice.totalSeconds, 0)
        }
    }

    /// 외모 변화나 점수 상승을 약속하는 표현은 콘텐츠에 두지 않는다.
    func test_catalog_avoidsAppearanceAndScorePromises() {
        let banned = ["근육", "림프", "붓기", "좌우", "균형", "점수", "개선", "리프팅", "교정", "치료", "탄력", "주름"]

        for practice in SmilePractice.catalog {
            let text = ([practice.title, practice.purpose] + practice.steps.map(\.title)).joined(separator: " ")
            for phrase in banned {
                XCTAssertFalse(text.contains(phrase), "'\(phrase)'가 \(practice.id)에 남아 있다: \(text)")
            }
        }
    }

    func test_catalog_coversEveryCategory() {
        let categories = Set(SmilePractice.catalog.map(\.category))

        for category in SmilePracticeCategory.allCases {
            XCTAssertTrue(categories.contains(category), "\(category)에 해당하는 콘텐츠가 없다")
        }
    }

    func test_durationText_usesSecondsUnderOneMinute() {
        let short = SmilePractice(
            id: "smile-test-short",
            title: "짧은 시간",
            category: .pause,
            steps: [SmilePracticeStep(title: "숨 고르기", seconds: 30, systemImage: "lungs.fill")],
            purpose: "테스트",
            videoFileName: "none"
        )

        XCTAssertEqual(short.totalSeconds, 30)
        XCTAssertEqual(short.durationText, "30초")
    }

    func test_durationText_roundsUpToMinutes() {
        let long = SmilePractice(
            id: "smile-test-long",
            title: "긴 시간",
            category: .pause,
            steps: [SmilePracticeStep(title: "머무르기", seconds: 40, reps: 2, systemImage: "clock")],
            purpose: "테스트",
            videoFileName: "none"
        )

        XCTAssertEqual(long.totalSeconds, 80)
        XCTAssertEqual(long.durationText, "2분")
    }

    func test_categoryDisplayNames_describeIntentNotFacialArea() {
        XCTAssertEqual(SmilePracticeCategory.pause.displayName, "잠깐 멈춤")
        XCTAssertEqual(SmilePracticeCategory.recall.displayName, "좋은 순간")
        XCTAssertEqual(SmilePracticeCategory.breathe.displayName, "숨 고르기")
        XCTAssertEqual(SmilePracticeCategory.connect.displayName, "따뜻한 연결")
    }
}
