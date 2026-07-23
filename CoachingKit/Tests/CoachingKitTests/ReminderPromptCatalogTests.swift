import XCTest
@testable import CoachingKit

final class ReminderPromptCatalogTests: XCTestCase {
    func test_timeBucket_hourBoundaries() {
        XCTAssertEqual(TimeBucket(hour: 4), .evening)
        XCTAssertEqual(TimeBucket(hour: 5), .morning)
        XCTAssertEqual(TimeBucket(hour: 10), .morning)
        XCTAssertEqual(TimeBucket(hour: 11), .afternoon)
        XCTAssertEqual(TimeBucket(hour: 16), .afternoon)
        XCTAssertEqual(TimeBucket(hour: 17), .evening)
        XCTAssertEqual(TimeBucket(hour: 0), .evening)
        XCTAssertEqual(TimeBucket(hour: 23), .evening)
    }

    func test_timeBucket_displayName() {
        XCTAssertEqual(TimeBucket.morning.displayName, "아침")
        XCTAssertEqual(TimeBucket.afternoon.displayName, "낮")
        XCTAssertEqual(TimeBucket.evening.displayName, "저녁")
    }

    func test_timeBucket_suggestedHour_valuesAndSelfContainment() {
        XCTAssertEqual(TimeBucket.morning.suggestedHour, 9)
        XCTAssertEqual(TimeBucket.afternoon.suggestedHour, 13)
        XCTAssertEqual(TimeBucket.evening.suggestedHour, 20)
        for bucket in TimeBucket.allCases {
            XCTAssertEqual(TimeBucket(hour: bucket.suggestedHour), bucket,
                           "추천 시각은 자기 버킷 범위 안에 있어야 한다")
        }
    }

    func test_catalog_hasEightPromptsPerBucket() {
        for bucket in TimeBucket.allCases {
            XCTAssertEqual(ReminderPromptCatalog.prompts(for: bucket).count, 8, "\(bucket) should have 8 prompts")
        }
    }

    func test_catalog_hasNoDuplicateText() {
        let allText = ReminderPromptCatalog.prompts.map(\.text)
        XCTAssertEqual(Set(allText).count, allText.count, "prompt text must be unique across the whole catalog")
    }

    func test_catalog_hasNoEmptyText() {
        XCTAssertTrue(ReminderPromptCatalog.prompts.allSatisfy { !$0.text.isEmpty })
    }
}
