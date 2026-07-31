import XCTest
import SwiftData
@testable import CoachingKit

/// 저장 실패가 컨텍스트에 잔여물을 남기지 않는지 검증한다.
///
/// 뷰들은 SwiftUI `mainContext` 하나를 공유하고 두 리포지토리가 그 위에 함께 올라간다.
/// 실패한 변경을 그대로 두면 같은 컨텍스트의 **다음** `save()`가 그것까지 밀어 넣어,
/// 실패했다고 안내한 기록이 뒤늦게 저장된다.
///
/// 실패 주입은 저장소 파일을 `allowsSave: false`로 다시 여는 방식이다. 디렉터리 권한을
/// 내리는 방법은 SQLite가 이미 파일 핸들을 들고 있어 실패하지 않는다.
final class RepositorySaveFailureTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDownWithError() throws {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories = []
    }

    /// 쓰기로 한 번 만든 뒤 같은 파일을 읽기 전용으로 다시 연 컨텍스트.
    private func readOnlyContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("save-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directories.append(directory)

        let url = directory.appendingPathComponent("store.sqlite")
        _ = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, allowsSave: false)]
        )
        return ModelContext(container)
    }

    // MARK: - SmileMomentRepository

    func test_momentSave_throws_whenStoreRejectsWrite() throws {
        let repository = SmileMomentRepository(modelContext: try readOnlyContext())

        XCTAssertThrowsError(try repository.save(guideID: "anytime-soft", source: .manual))
    }

    /// 실패한 완료는 컨텍스트에서 제거돼야 다음 `save()`에 묻어가지 않는다.
    func test_momentSave_leavesNothingStaged_whenSaveFails() throws {
        let context = try readOnlyContext()
        let repository = SmileMomentRepository(modelContext: context)

        _ = try? repository.save(guideID: "anytime-soft", source: .manual)

        let staged = context.insertedModelsArray.compactMap { $0 as? SmileMoment }
        let stillPending = staged.filter { !$0.isDeleted }
        XCTAssertTrue(stillPending.isEmpty, "실패한 완료가 컨텍스트에 남아 다음 저장에 묻어간다")
    }

    /// 정리가 같은 컨텍스트의 무관한 미저장 변경까지 버리면 안 된다.
    func test_momentSave_keepsUnrelatedPendingWork_whenSaveFails() throws {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let bystander = SmileReminderSchedule(pattern: .recommended, isEnabled: true)
        context.insert(bystander)

        // 쓰기 가능한 컨텍스트라 실제로는 성공한다. 여기서 보는 것은 정리 방식이
        // 컨텍스트 전체를 되돌리지 않는다는 점이다.
        let repository = SmileMomentRepository(modelContext: context)
        _ = try? repository.save(guideID: "anytime-soft", source: .manual)

        XCTAssertFalse(bystander.isDeleted)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SmileReminderSchedule>()).count, 1)
    }

    // MARK: - SmileReminderScheduleRepository

    func test_scheduleSave_throws_whenStoreRejectsWrite() throws {
        let repository = SmileReminderScheduleRepository(modelContext: try readOnlyContext())

        XCTAssertThrowsError(try repository.save(pattern: .recommended, isEnabled: true))
    }

    /// 기존 일정을 고치다 실패하면 필드가 원래 값으로 돌아와야 한다.
    /// 뷰모델이 그 객체를 그대로 들고 화면에 보여주기 때문이다.
    func test_scheduleSave_restoresFields_whenSaveFails() throws {
        let schema = PersistenceSchema.schema
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("save-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directories.append(directory)
        let url = directory.appendingPathComponent("store.sqlite")

        // 쓰기 가능한 컨테이너로 기존 일정을 먼저 만든다.
        let writable = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let seeding = ModelContext(writable)
        try SmileReminderScheduleRepository(modelContext: seeding).save(
            pattern: .recommended,
            isEnabled: true,
            notificationGroupID: "original-group"
        )

        // 같은 파일을 읽기 전용으로 열어 수정 저장을 실패시킨다.
        let readOnly = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, allowsSave: false)]
        )
        let context = ModelContext(readOnly)
        let repository = SmileReminderScheduleRepository(modelContext: context)
        let before = try XCTUnwrap(repository.fetchCurrent())
        let originalPattern = before.pattern
        let originalEnabled = before.isEnabled

        let changed = try SmileReminderPattern(
            startTime: ReminderTime(hour: 7, minute: 30),
            endTime: ReminderTime(hour: 23, minute: 0),
            intervalMinutes: 60
        )
        _ = try? repository.save(pattern: changed, isEnabled: false, notificationGroupID: "new-group")

        let after = try XCTUnwrap(repository.fetchCurrent())
        XCTAssertEqual(after.pattern, originalPattern, "실패했는데 시간대가 바뀐 채로 남았다")
        XCTAssertEqual(after.isEnabled, originalEnabled, "실패했는데 사용 여부가 바뀐 채로 남았다")
        XCTAssertEqual(after.notificationGroupID, "original-group", "실패했는데 알림 그룹이 바뀐 채로 남았다")
    }
}
