import Foundation

/// 미소 가이드 화면의 안내 문구 하나를 가리키는 식별자.
///
/// 문구 자체는 앱 타깃의 `Coaching.xcstrings`에 있다(`smileCue.<id>`). 패키지는 어떤 큐가
/// 있고 어떤 순서로 도는지만 안다. **id와 배열 순서는 바꾸지 않는다** — 순서는
/// `SmileCueCursorStore`가 다음 위치를 인덱스로 저장하기 때문이고, id는 카탈로그 키가 그 위에
/// 만들어지기 때문이다.
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
