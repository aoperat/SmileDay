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

    /// 타인의 시선, 표정 평가, 더 크게 웃으라는 압박을 암시하는 문구는 카탈로그에 두지 않는다.
    func test_catalog_avoidsEvaluativeAndGazePhrases() {
        let banned = ["누군가 당신을 본다면", "어떤 표정을 보고", "편안해 보일", "더 크게", "교정"]

        for prompt in ReminderPromptCatalog.prompts {
            for phrase in banned {
                XCTAssertFalse(
                    prompt.text.contains(phrase),
                    "금지 문구 '\(phrase)'가 질문에 남아 있다: \(prompt.text)"
                )
            }
        }
    }

    /// 점수·개선 어휘는 질문에서 완전히 배제한다.
    func test_catalog_avoidsScoreAndImprovementWording() {
        let banned = ["점수", "개선", "리프팅", "치료", "진짜 미소", "억지 미소"]

        for prompt in ReminderPromptCatalog.prompts {
            for phrase in banned {
                XCTAssertFalse(
                    prompt.text.contains(phrase),
                    "평가 어휘 '\(phrase)'가 질문에 남아 있다: \(prompt.text)"
                )
            }
        }
    }

    /// 좋은 순간이 떠오르지 않는 날에도 그대로 넘어갈 수 있어야 한다.
    func test_catalog_hasPermissivePromptInEveryBucket() {
        for bucket in TimeBucket.allCases {
            let permissive = ReminderPromptCatalog.prompts(for: bucket).filter {
                $0.text.contains("괜찮아요") || $0.text.contains("않아도")
            }
            XCTAssertFalse(permissive.isEmpty, "\(bucket)에는 허용적 질문이 최소 1개 있어야 한다")
        }
    }
}
