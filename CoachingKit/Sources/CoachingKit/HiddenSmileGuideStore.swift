import Foundation

/// 목록에서 숨긴 기본 카드 ID. 기본 카드는 코드 상수라 삭제할 수 없고 숨기기만 한다.
/// 숨겨도 ID로는 계속 찾아지므로 지난 기록이 이름을 잃지 않는다.
public protocol HiddenSmileGuideStoring: AnyObject {
    var hiddenGuideIDs: Set<String> { get set }
}

public final class UserDefaultsHiddenSmileGuideStore: HiddenSmileGuideStoring {
    private static let key = "hiddenSmileGuideIDs"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hiddenGuideIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.key) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.key) }
    }
}

public final class InMemoryHiddenSmileGuideStore: HiddenSmileGuideStoring {
    public var hiddenGuideIDs: Set<String>

    public init(hiddenGuideIDs: Set<String> = []) {
        self.hiddenGuideIDs = hiddenGuideIDs
    }
}
