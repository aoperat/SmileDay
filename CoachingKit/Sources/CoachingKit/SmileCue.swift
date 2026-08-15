import Foundation

/// 미소 가이드 화면의 안내 문구 하나를 가리키는 식별자.
///
/// 문구 자체는 앱 타깃의 `Coaching.xcstrings`에 있다(`smileCue.<id>`). 패키지는 어떤 큐가
/// 있고 어떤 순서로 도는지만 안다 — `SmileCueCursorStore`가 이 id로 순환 위치를 저장하므로
/// **id와 배열 순서는 바꾸지 않는다.**
public struct SmileCue: Identifiable, Equatable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public enum SmileCueCatalog {
    public static let all: [SmileCue] = [
        SmileCue(id: "cared-for"),
        SmileCue(id: "welcome"),
        SmileCue(id: "self-kindness"),
        SmileCue(id: "gratitude"),
        SmileCue(id: "greeting"),
        SmileCue(id: "enough"),
        SmileCue(id: "nothing-needed"),
        SmileCue(id: "gentle-invitation"),
    ]
}
