import Foundation
import Observation

public struct ReminderMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// nil이면 기본 문구 — 표시·예약 시점에 id로 카탈로그에서 해석한다.
    /// 값이 있으면 사용자가 직접 쓴 문구이고, 언어가 바뀌어도 번역하지 않는다.
    public var text: String?

    public init(id: String = UUID().uuidString, text: String? = nil) {
        self.id = id
        self.text = text
    }
}

public enum ReminderMessageCatalog {
    /// 기본 문구의 id. 문구 자체는 앱 타깃 `Localizable.xcstrings`의 `reminderMessage.<id>`.
    /// **id는 기기에 예약된 알림이 키로 들고 있는 호환 계약이다 — 바꾸지 않는다.**
    public static let defaults: [ReminderMessage] = [
        "gentle-five-seconds", "release-shoulders", "warm-greeting", "comfortable-is-enough",
        "remember-gratitude", "relax-expression", "kind-to-self", "bright-as-comfortable",
    ].map { ReminderMessage(id: $0) }
}

public protocol ReminderMessageStoring: AnyObject {
    var messages: [ReminderMessage] { get set }
}

public final class UserDefaultsReminderMessageStore: ReminderMessageStoring {
    /// v1은 `text`가 항상 있던 시절의 데이터다. **읽기만 하고 절대 쓰지 않는다** — 옛 빌드가
    /// 다시 켜져도(백업 복원, TestFlight 병행) 자기 데이터를 온전히 본다.
    private static let legacyKey = "reminderMessages.v1"
    private static let key = "reminderMessages.v2"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var messages: [ReminderMessage] {
        get {
            if let data = defaults.data(forKey: Self.key),
               let decoded = try? decoder.decode([ReminderMessage].self, from: data),
               !decoded.isEmpty {
                return decoded
            }
            if let data = defaults.data(forKey: Self.legacyKey),
               let decoded = try? decoder.decode([ReminderMessage].self, from: data),
               !decoded.isEmpty {
                // 플래그로 막지 않는다 — v2가 없을 때마다 다시 승격한다. 백업 복원으로 v1만
                // 되살아나도 다음 읽기에서 그대로 맞춰진다.
                return ReminderMessageMigration.promoteUntouchedDefaults(decoded)
            }
            return ReminderMessageCatalog.defaults
        }
        set {
            let value = newValue.isEmpty ? ReminderMessageCatalog.defaults : newValue
            guard let data = try? encoder.encode(value) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }
}

public final class InMemoryReminderMessageStore: ReminderMessageStoring {
    public var messages: [ReminderMessage]

    public init(messages: [ReminderMessage] = ReminderMessageCatalog.defaults) {
        self.messages = messages
    }
}

@MainActor
@Observable
public final class ReminderMessageViewModel {
    public private(set) var messages: [ReminderMessage]
    public private(set) var error: ReminderMessageError?

    private let store: ReminderMessageStoring
    /// 항목을 화면 문구로 푼다. 앱은 카탈로그를, 테스트는 항등 함수를 넘긴다 — 이 패키지는
    /// 카탈로그를 읽을 수 없어서(스펙 4.3절) 해석을 밖에서 받는다.
    private let resolve: (ReminderMessage) -> String

    public init(store: ReminderMessageStoring, resolve: @escaping (ReminderMessage) -> String) {
        self.store = store
        self.resolve = resolve
        messages = store.messages
    }

    @discardableResult
    public func add(text: String) -> Bool {
        guard let text = validated(text) else { return false }
        messages.append(ReminderMessage(text: text))
        persist()
        return true
    }

    @discardableResult
    public func update(id: String, text: String) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              let text = validated(text, excludingID: id) else {
            return false
        }
        // 기본 문구를 열어보고 그대로 저장하면 굳지 않는다 — 해석값과 같으면 nil로 되돌린다.
        let asDefault = ReminderMessage(id: id, text: nil)
        let isCatalogDefault = ReminderMessageCatalog.defaults.contains { $0.id == id }
        if isCatalogDefault, resolve(asDefault) == text {
            messages[index].text = nil
        } else {
            messages[index].text = text
        }
        persist()
        return true
    }

    @discardableResult
    public func remove(id: String) -> Bool {
        guard messages.count > 1 else {
            error = .lastRemaining
            return false
        }
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return false }
        messages.remove(at: index)
        persist()
        return true
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.sorted().map { messages[$0] }
        messages = messages.enumerated()
            .filter { !fromOffsets.contains($0.offset) }
            .map(\.element)
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(max(0, toOffset - removedBeforeDestination), messages.count)
        messages.insert(contentsOf: moving, at: destination)
        persist()
    }

    public func clearError() {
        error = nil
    }

    private func validated(_ rawText: String, excludingID: String? = nil) -> String? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = .empty
            return nil
        }
        guard text.count <= 100 else {
            error = .tooLong(limit: 100)
            return nil
        }
        guard !messages.contains(where: { $0.id != excludingID && resolve($0) == text }) else {
            error = .duplicate
            return nil
        }
        error = nil
        return text
    }

    private func persist() {
        store.messages = messages
        error = nil
    }
}
