import XCTest
import SwiftData
@testable import CoachingKit

/// 알림 중심 MVP로 업데이트해도 기존 사용자의 저장 데이터가 사라지지 않아야 한다.
/// in-memory가 아니라 실제 파일 저장소를 열었다 닫으며 확인한다.
final class PersistenceSchemaMigrationTests: XCTestCase {
    /// `SmileMoment`를 넣기 전의 스키마.
    private var legacySchema: Schema {
        Schema([Baseline.self, CheckInSession.self, ReminderSetting.self, CareSession.self])
    }

    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("smileday-migration-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        for url in [storeURL, storeURL.appendingPathExtension("shm"), storeURL.appendingPathExtension("wal")] {
            try? FileManager.default.removeItem(at: url!)
        }
    }

    private func makeContext(schema: Schema) throws -> (ModelContainer, ModelContext) {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, ModelContext(container))
    }

    /// 구버전으로 쓴 데이터를 새 스키마가 그대로 읽고, 그 위에 새 기록을 더할 수 있어야 한다.
    func test_openingLegacyStoreWithNewSchema_keepsExistingRecords() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

        // 1. 구버전 스키마로 데이터를 남긴다.
        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(Baseline(
                capturedAt: capturedAt,
                mouthCornerLeft: 0.2,
                mouthCornerRight: 0.25,
                browTension: 0.1,
                lightingQuality: 0.9,
                deviceAngleOK: true
            ))
            context.insert(CheckInSession(
                date: capturedAt,
                mouthCornerLeft: 0.3,
                mouthCornerRight: 0.3,
                browTension: 0.1,
                lightingQuality: 0.9,
                deviceAngleOK: true,
                scoreDelta: 4.2
            ))
            context.insert(CareSession(date: capturedAt, routineID: "legacy-routine"))
            context.insert(ReminderSetting(hour: 9, minute: 0, notificationID: "legacy-reminder"))
            try context.save()
            _ = container
        }

        // 2. SmileMoment가 추가된 새 스키마로 다시 연다.
        let (container, context) = try makeContext(schema: PersistenceSchema.schema)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Baseline>()).count, 1, "기준선이 지워지면 안 된다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CheckInSession>()).count, 1, "미소 시간 기록이 지워지면 안 된다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CareSession>()).count, 1, "쉬어가기 기록이 지워지면 안 된다")

        let reminders = try context.fetch(FetchDescriptor<ReminderSetting>())
        XCTAssertEqual(reminders.count, 1)
        XCTAssertNil(reminders.first?.guideID, "구버전 알림의 guideID는 nil로 들어온다")
        XCTAssertEqual(reminders.first?.guide.id, "soft-smile", "nil은 기본 가이드로 읽혀야 한다")

        XCTAssertTrue(try context.fetch(FetchDescriptor<SmileMoment>()).isEmpty)
        _ = container
    }

    /// 새 스키마에서 저장한 미소는 앱을 다시 실행해도 남아 있어야 한다.
    func test_smileMomentSurvivesReopen_alongsideLegacyData() throws {
        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(CareSession(date: Date(timeIntervalSince1970: 1_700_000_000), routineID: "legacy-routine"))
            try context.save()
            _ = container
        }

        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let (container, context) = try makeContext(schema: PersistenceSchema.schema)
            try SmileMomentRepository(modelContext: context)
                .save(guideID: "greeting-smile", source: .notification, date: completedAt)
            _ = container
        }

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)
        let moments = try context.fetch(FetchDescriptor<SmileMoment>())

        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments.first?.guideID, "greeting-smile")
        XCTAssertEqual(moments.first?.source, .notification)
        XCTAssertEqual(moments.first?.date, completedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CareSession>()).count, 1, "기존 기록은 그대로여야 한다")
        _ = container
    }

    /// 구버전 알림에 가이드를 지정하면 저장되고, 다시 열어도 유지된다.
    func test_assigningGuideToLegacyReminder_persists() throws {
        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(ReminderSetting(hour: 20, minute: 30, notificationID: "legacy-reminder"))
            try context.save()
            _ = container
        }

        do {
            let (container, context) = try makeContext(schema: PersistenceSchema.schema)
            let repository = ReminderRepository(modelContext: context)
            let reminder = try XCTUnwrap(repository.fetchAll().first)
            try repository.updateGuide(reminder, guideID: "bright-smile")
            _ = container
        }

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)
        let reminder = try XCTUnwrap(ReminderRepository(modelContext: context).fetchAll().first)

        XCTAssertEqual(reminder.guideID, "bright-smile")
        XCTAssertEqual(reminder.hour, 20)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertEqual(reminder.notificationID, "legacy-reminder", "알림 식별자가 바뀌면 예약 취소가 어긋난다")
        _ = container
    }
}
