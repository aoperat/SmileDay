import XCTest
import SwiftData
@testable import CoachingKit

/// `CustomSmileCard`는 새 흐름에서 읽지 않는 호환 모델이다.
/// 카드 해석 로직 대신 저장 프로퍼티가 그대로 오가는지만 확인한다.
final class CustomSmileCardTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    func test_storedProperties_roundTripThroughContext() throws {
        let context = try makeContext()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(CustomSmileCard(
            id: "card-1",
            title: "엘리베이터에서 웃기",
            instructionText: "문이 닫히면 한 번 웃어보세요.",
            slotRawValue: "evening",
            createdAt: createdAt
        ))
        try context.save()

        let card = try XCTUnwrap(context.fetch(FetchDescriptor<CustomSmileCard>()).first)

        XCTAssertEqual(card.id, "card-1")
        XCTAssertEqual(card.title, "엘리베이터에서 웃기")
        XCTAssertEqual(card.instructionText, "문이 닫히면 한 번 웃어보세요.")
        XCTAssertEqual(card.slotRawValue, "evening")
        XCTAssertEqual(card.createdAt, createdAt)
    }

    /// 안내 문구를 비운 채 저장한 카드는 nil로 남는다. 기본 문구로 덮어쓰지 않는다.
    func test_instructionText_staysNil_whenNotProvided() throws {
        let context = try makeContext()
        context.insert(CustomSmileCard(title: "제목", slotRawValue: "anytime"))
        try context.save()

        XCTAssertNil(try context.fetch(FetchDescriptor<CustomSmileCard>()).first?.instructionText)
    }

    /// 사라진 `DaySlot`의 원문은 해석하지 않고 그대로 보관한다.
    func test_slotRawValue_isStoredVerbatim() throws {
        let context = try makeContext()
        context.insert(CustomSmileCard(title: "제목", slotRawValue: "midnight"))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomSmileCard>()).first?.slotRawValue, "midnight")
    }
}
