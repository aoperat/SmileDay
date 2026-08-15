import XCTest
import SwiftData
@testable import CoachingKit

/// 알림 중심 MVP로 업데이트해도 기존 사용자의 저장 데이터가 사라지지 않아야 한다.
/// in-memory가 아니라 실제 파일 저장소를 열었다 닫으며 확인한다.
///
/// 죽은 코드를 지우는 동안 이 파일이 안전망이다. 그래서 함께 사라질 수 있는 Repository나
/// 편의 프로퍼티를 거치지 않고 `ModelContext`와 저장 프로퍼티만 직접 다룬다.
final class PersistenceSchemaMigrationTests: XCTestCase {
    /// `CustomSmileCard`가 들어오기 전, 가장 오래된 스키마.
    private var oldestSchema: Schema {
        Schema([Baseline.self, CheckInSession.self, ReminderSetting.self, CareSession.self])
    }

    /// 새 흐름(`SmileMoment`, `SmileReminderSchedule`) 직전 스키마.
    private var legacySchema: Schema {
        Schema([
            Baseline.self, CheckInSession.self, ReminderSetting.self,
            CareSession.self, CustomSmileCard.self,
        ])
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

    private let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// 카드 생성 API가 바뀌어도 호환 검증은 저장 프로퍼티만 보게 한 곳으로 모은다.
    private func makeCustomSmileCard(
        id: String,
        title: String,
        instructionText: String?,
        slotRawValue: String,
        createdAt: Date
    ) -> CustomSmileCard {
        CustomSmileCard(
            id: id,
            title: title,
            instructionText: instructionText,
            slotRawValue: slotRawValue,
            createdAt: createdAt
        )
    }

    // MARK: - 스키마 등록

    /// 화면에서 안 쓰는 모델이라도 스키마에서 빠지면 기존 저장소가 열리지 않는다.
    func test_schema_registersEverySupportedModel() {
        let names = PersistenceSchema.models.map { String(describing: $0) }

        for expected in [
            "Baseline", "CheckInSession", "ReminderSetting", "CareSession",
            "SmileMoment", "CustomSmileCard", "SmileReminderSchedule",
        ] {
            XCTAssertTrue(names.contains(expected), "\(expected)이(가) 스키마에서 빠졌다")
        }
        XCTAssertEqual(names.count, 7, "모델을 더하거나 빼면 마이그레이션 영향을 먼저 확인해야 한다")
    }

    // MARK: - 재열기 호환

    /// 가장 오래된 저장소도 현재 스키마로 열려야 한다.
    func test_openingOldestStoreWithNewSchema_keepsExistingRecords() throws {
        do {
            let (container, context) = try makeContext(schema: oldestSchema)
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

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Baseline>()).count, 1, "기준선이 지워지면 안 된다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CheckInSession>()).count, 1, "미소 시간 기록이 지워지면 안 된다")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CareSession>()).count, 1, "쉬어가기 기록이 지워지면 안 된다")

        let reminders = try context.fetch(FetchDescriptor<ReminderSetting>())
        XCTAssertEqual(reminders.count, 1)
        XCTAssertNil(reminders.first?.guideID, "구버전 알림의 guideID는 nil로 들어온다")

        XCTAssertTrue(try context.fetch(FetchDescriptor<SmileMoment>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CustomSmileCard>()).isEmpty)
        _ = container
    }

    /// 레코드 수뿐 아니라 저장값 하나하나가 그대로 돌아와야 한다.
    /// 정리 과정에서 저장 프로퍼티를 건드리면 여기서 걸린다.
    func test_openingLegacyStoreWithNewSchema_keepsEveryStoredValue() throws {
        let startedAt = capturedAt.addingTimeInterval(-60)
        let payload = Data("legacy-payload".utf8)

        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(Baseline(
                capturedAt: capturedAt,
                mouthCornerLeft: 0.21,
                mouthCornerRight: 0.26,
                browTension: 0.11,
                lightingQuality: 0.91,
                deviceAngleOK: false
            ))
            context.insert(CheckInSession(
                date: capturedAt,
                mouthCornerLeft: 0.31,
                mouthCornerRight: 0.32,
                browTension: 0.12,
                lightingQuality: 0.93,
                deviceAngleOK: true,
                scoreDelta: 4.25,
                smileMean: 0.41,
                smileMax: 0.62,
                smileStability: 0.73,
                smileAsymmetry: 0.04,
                duchenneScore: 0.55,
                mood: "🙂",
                payload: payload,
                payloadVersion: 2,
                promptText: "지금 표정은 어떤가요?",
                smileMomentNote: "커피 한 잔"
            ))
            context.insert(CareSession(
                date: capturedAt,
                routineID: "legacy-routine",
                startedAt: startedAt,
                durationSeconds: 92.5,
                completedSteps: 3,
                totalSteps: 5,
                wasCompleted: false
            ))
            context.insert(ReminderSetting(
                hour: 20,
                minute: 30,
                isEnabled: false,
                createdAt: capturedAt,
                notificationID: "legacy-reminder",
                guideID: "anytime-pause"
            ))
            context.insert(makeCustomSmileCard(
                id: "card-1",
                title: "엘리베이터에서 웃기",
                instructionText: "문이 닫히면 한 번 웃어보세요.",
                slotRawValue: "evening",
                createdAt: capturedAt
            ))
            try context.save()
            _ = container
        }

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)

        let baseline = try XCTUnwrap(context.fetch(FetchDescriptor<Baseline>()).first)
        XCTAssertEqual(baseline.capturedAt, capturedAt)
        XCTAssertEqual(baseline.mouthCornerLeft, 0.21)
        XCTAssertEqual(baseline.mouthCornerRight, 0.26)
        XCTAssertEqual(baseline.browTension, 0.11)
        XCTAssertEqual(baseline.lightingQuality, 0.91)
        XCTAssertFalse(baseline.deviceAngleOK)

        let checkIn = try XCTUnwrap(context.fetch(FetchDescriptor<CheckInSession>()).first)
        XCTAssertEqual(checkIn.date, capturedAt)
        XCTAssertEqual(checkIn.mouthCornerLeft, 0.31)
        XCTAssertEqual(checkIn.mouthCornerRight, 0.32)
        XCTAssertEqual(checkIn.browTension, 0.12)
        XCTAssertEqual(checkIn.lightingQuality, 0.93)
        XCTAssertTrue(checkIn.deviceAngleOK)
        XCTAssertEqual(checkIn.scoreDelta, 4.25)
        XCTAssertEqual(checkIn.smileMean, 0.41)
        XCTAssertEqual(checkIn.smileMax, 0.62)
        XCTAssertEqual(checkIn.smileStability, 0.73)
        XCTAssertEqual(checkIn.smileAsymmetry, 0.04)
        XCTAssertEqual(checkIn.duchenneScore, 0.55)
        XCTAssertEqual(checkIn.mood, "🙂")
        XCTAssertEqual(checkIn.payload, payload, "체크인 payload는 읽지 않아도 보존한다")
        XCTAssertEqual(checkIn.payloadVersion, 2)
        XCTAssertEqual(checkIn.promptText, "지금 표정은 어떤가요?")
        XCTAssertEqual(checkIn.smileMomentNote, "커피 한 잔")

        let care = try XCTUnwrap(context.fetch(FetchDescriptor<CareSession>()).first)
        XCTAssertEqual(care.date, capturedAt)
        XCTAssertEqual(care.routineID, "legacy-routine")
        XCTAssertEqual(care.startedAt, startedAt)
        XCTAssertEqual(care.durationSeconds, 92.5)
        XCTAssertEqual(care.completedSteps, 3)
        XCTAssertEqual(care.totalSteps, 5)
        XCTAssertFalse(care.wasCompleted)

        let reminder = try XCTUnwrap(context.fetch(FetchDescriptor<ReminderSetting>()).first)
        XCTAssertEqual(reminder.hour, 20)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertFalse(reminder.isEnabled)
        XCTAssertEqual(reminder.createdAt, capturedAt)
        XCTAssertEqual(reminder.notificationID, "legacy-reminder", "알림 식별자가 바뀌면 예약 취소가 어긋난다")
        XCTAssertEqual(reminder.guideID, "anytime-pause")

        let card = try XCTUnwrap(context.fetch(FetchDescriptor<CustomSmileCard>()).first)
        XCTAssertEqual(card.id, "card-1")
        XCTAssertEqual(card.title, "엘리베이터에서 웃기")
        XCTAssertEqual(card.instructionText, "문이 닫히면 한 번 웃어보세요.")
        XCTAssertEqual(card.slotRawValue, "evening")
        XCTAssertEqual(card.createdAt, capturedAt)

        _ = container
    }

    /// 새 스키마에서 저장한 미소는 앱을 다시 실행해도 남아 있어야 한다.
    func test_smileMomentSurvivesReopen_alongsideLegacyData() throws {
        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(CareSession(date: capturedAt, routineID: "legacy-routine"))
            try context.save()
            _ = container
        }

        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let (container, context) = try makeContext(schema: PersistenceSchema.schema)
            try SmileMomentRepository(modelContext: context)
                .save(guideID: "morning-greeting", source: .notification, date: completedAt)
            _ = container
        }

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)
        let moments = try context.fetch(FetchDescriptor<SmileMoment>())

        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments.first?.guideID, "morning-greeting")
        XCTAssertEqual(moments.first?.source, .notification)
        XCTAssertEqual(moments.first?.date, completedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CareSession>()).count, 1, "기존 기록은 그대로여야 한다")
        _ = container
    }

    /// 구버전 알림 레코드를 현재 스키마에서 고쳐도 저장되고, 다시 열어도 유지된다.
    func test_editingLegacyReminder_persistsAcrossReopen() throws {
        do {
            let (container, context) = try makeContext(schema: legacySchema)
            context.insert(ReminderSetting(hour: 20, minute: 30, notificationID: "legacy-reminder"))
            try context.save()
            _ = container
        }

        do {
            let (container, context) = try makeContext(schema: PersistenceSchema.schema)
            let reminder = try XCTUnwrap(context.fetch(FetchDescriptor<ReminderSetting>()).first)
            reminder.guideID = "anytime-pause"
            try context.save()
            _ = container
        }

        let (container, context) = try makeContext(schema: PersistenceSchema.schema)
        let reminder = try XCTUnwrap(context.fetch(FetchDescriptor<ReminderSetting>()).first)

        XCTAssertEqual(reminder.guideID, "anytime-pause")
        XCTAssertEqual(reminder.hour, 20)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertEqual(reminder.notificationID, "legacy-reminder", "알림 식별자가 바뀌면 예약 취소가 어긋난다")
        _ = container
    }
}
