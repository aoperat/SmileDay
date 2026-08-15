import Foundation

public protocol SmileCueCursorStoring: AnyObject {
    var nextIndex: Int { get set }
}

public final class UserDefaultsSmileCueCursorStore: SmileCueCursorStoring {
    private static let key = "smileCueNextIndex"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var nextIndex: Int {
        get { defaults.integer(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

public final class InMemorySmileCueCursorStore: SmileCueCursorStoring {
    public var nextIndex: Int

    public init(nextIndex: Int = 0) {
        self.nextIndex = nextIndex
    }
}

public final class SmileCueSelector {
    private let cues: [SmileCue]
    private let store: SmileCueCursorStoring

    public init(
        cues: [SmileCue] = SmileCueCatalog.all,
        store: SmileCueCursorStoring
    ) {
        precondition(!cues.isEmpty)
        self.cues = cues
        self.store = store
    }

    public func next() -> SmileCue {
        let index = ((store.nextIndex % cues.count) + cues.count) % cues.count
        let cue = cues[index]
        store.nextIndex = (index + 1) % cues.count
        return cue
    }
}
