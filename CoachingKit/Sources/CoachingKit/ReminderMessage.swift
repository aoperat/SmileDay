import Foundation
import Observation

public struct ReminderMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var text: String

    public init(id: String = UUID().uuidString, text: String) {
        self.id = id
        self.text = text
    }
}

public enum ReminderMessageCatalog {
    public static let defaults: [ReminderMessage] = [
        ReminderMessage(
            id: "gentle-five-seconds",
            text: "지금 괜찮다면 5초만 편안하게 미소 지어보세요."
        ),
        ReminderMessage(
            id: "release-shoulders",
            text: "잠깐 어깨 힘을 빼고 입꼬리를 살짝 올려볼까요?"
        ),
        ReminderMessage(
            id: "warm-greeting",
            text: "반가운 사람에게 인사하듯 가볍게 미소 지어보세요."
        ),
        ReminderMessage(
            id: "comfortable-is-enough",
            text: "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요."
        ),
        ReminderMessage(
            id: "remember-gratitude",
            text: "고마운 사람을 떠올리며 잠깐 미소 지어볼까요?"
        ),
        ReminderMessage(
            id: "relax-expression",
            text: "화면에서 눈을 떼고 얼굴의 힘을 가볍게 풀어볼까요?"
        ),
        ReminderMessage(
            id: "kind-to-self",
            text: "오늘의 나에게 따뜻한 표정을 보내볼까요?"
        ),
        ReminderMessage(
            id: "bright-as-comfortable",
            text: "지금 잠깐, 편한 만큼 밝게 웃어볼까요?"
        ),
    ]
}

public protocol ReminderMessageStoring: AnyObject {
    var messages: [ReminderMessage] { get set }
}

public final class UserDefaultsReminderMessageStore: ReminderMessageStoring {
    private static let key = "reminderMessages.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var messages: [ReminderMessage] {
        get {
            guard let data = defaults.data(forKey: Self.key),
                  let decoded = try? decoder.decode([ReminderMessage].self, from: data),
                  !decoded.isEmpty else {
                return ReminderMessageCatalog.defaults
            }
            return decoded
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

    public init(store: ReminderMessageStoring) {
        self.store = store
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
        messages[index].text = text
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
        guard !messages.contains(where: { $0.id != excludingID && $0.text == text }) else {
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
