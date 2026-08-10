import Foundation

/// 실시간 확인 중 웃지 않는 시간이 이어질 때 알려주는 설정.
///
/// 사용자 환경설정이라 저장한다. 얼굴 측정값을 저장하지 않는다는 약속과는 별개다 —
/// 여기에 측정 결과는 들어가지 않는다.
public struct LiveSmileNudgeSettings: Equatable, Sendable {
    /// 설정 화면에서 고를 수 있는 간격(초).
    public static let allowedIntervalSeconds = [30, 60, 90, 120, 180]
    public static let `default` = LiveSmileNudgeSettings()

    public var isEnabled: Bool
    /// 웃지 않는 상태가 이만큼 이어지면 알린다.
    public var intervalSeconds: Int
    public var isHapticEnabled: Bool

    public init(
        isEnabled: Bool = true,
        intervalSeconds: Int = 60,
        isHapticEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.intervalSeconds = Self.nearestAllowedInterval(intervalSeconds)
        self.isHapticEnabled = isHapticEnabled
    }

    /// 목록에 없는 값이 저장돼 있어도 가장 가까운 허용값으로 읽는다.
    /// 예전 버전이 남긴 값이나 손상된 값 때문에 알림이 멈추지 않게 한다.
    static func nearestAllowedInterval(_ seconds: Int) -> Int {
        allowedIntervalSeconds.min { abs($0 - seconds) < abs($1 - seconds) } ?? 60
    }
}

public protocol LiveSmileNudgeSettingsStoring: AnyObject {
    var settings: LiveSmileNudgeSettings { get set }
}

public final class UserDefaultsLiveSmileNudgeSettingsStore: LiveSmileNudgeSettingsStoring {
    private enum Key {
        static let isEnabled = "liveSmileNudgeEnabled"
        static let intervalSeconds = "liveSmileNudgeIntervalSeconds"
        static let isHapticEnabled = "liveSmileNudgeHapticEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var settings: LiveSmileNudgeSettings {
        get {
            let fallback = LiveSmileNudgeSettings.default
            // object(forKey:)로 "저장한 적 없음"과 "false로 저장함"을 구분한다.
            return LiveSmileNudgeSettings(
                isEnabled: defaults.object(forKey: Key.isEnabled) as? Bool ?? fallback.isEnabled,
                intervalSeconds: defaults.object(forKey: Key.intervalSeconds) as? Int ?? fallback.intervalSeconds,
                isHapticEnabled: defaults.object(forKey: Key.isHapticEnabled) as? Bool ?? fallback.isHapticEnabled
            )
        }
        set {
            defaults.set(newValue.isEnabled, forKey: Key.isEnabled)
            defaults.set(newValue.intervalSeconds, forKey: Key.intervalSeconds)
            defaults.set(newValue.isHapticEnabled, forKey: Key.isHapticEnabled)
        }
    }
}

public final class InMemoryLiveSmileNudgeSettingsStore: LiveSmileNudgeSettingsStoring {
    public var settings: LiveSmileNudgeSettings

    public init(settings: LiveSmileNudgeSettings = .default) {
        self.settings = settings
    }
}

/// "지금 한 번 웃어볼까요?"를 사용자에게 알리는 경계.
///
/// 진동과 알림은 플랫폼 API라 앱 타깃이 구현한다. 패키지는 언제 알릴지만 정한다.
@MainActor
public protocol LiveSmileNudging: AnyObject {
    func nudge(withHaptic: Bool)

    /// 세션이 끝날 때 부른다. 이 세션이 띄운 알림을 거둔다.
    ///
    /// 이 알림은 "지금 실시간 확인 중"이라는 맥락에서만 뜻이 있다. 세션이 끝난 뒤에도
    /// 알림센터에 남아 있으면, 나중에 그걸 본 사용자는 미소 알림이 온 줄 알고 누른다 —
    /// 그런데 이 알림에는 딥링크가 없어 아무 일도 일어나지 않는다.
    func clearNudges()
}
