import Foundation

/// 디자인 토큰의 원시 색값. 앱 타깃에는 테스트 번들이 없어 여기 두고 대비를 테스트로 고정한다.
/// `SmileDay/Views/Theme.swift`의 `SDColor`가 이 값을 SwiftUI `Color`로 감싼다.
public enum SDPalette {
    public static let coral: UInt32 = 0xF65D73
    public static let coralDeep: UInt32 = 0xE04360
    public static let apricot: UInt32 = 0xFFA94D
    public static let sun: UInt32 = 0xFFC93C
    public static let cream: UInt32 = 0xFFF6EE
    public static let ink: UInt32 = 0x46323C
    /// 보조 텍스트. 흰 배경과 크림 배경 모두에서 본문 기준을 넘겨야 한다.
    public static let muted: UInt32 = 0x7E6A74
    public static let shell: UInt32 = 0xF1E2D6
    /// 저장 실패 같은 문제 상황 문구.
    public static let alert: UInt32 = 0xC8324C
    public static let white: UInt32 = 0xFFFFFF

    /// 본문·캡션에 쓰는 색. 흰 배경과 크림 배경 모두에서 4.5:1 이상이어야 한다.
    public static let bodyTextColors: [UInt32] = [ink, muted, alert]
    /// 흰 글자를 얹는 배경. 굵은 버튼 글자 기준 3:1 이상이어야 한다.
    public static let whiteOnColorBackgrounds: [UInt32] = [coral, coralDeep]
    /// ink 글리프를 얹는 아이콘 칩 배경. 비텍스트 기준 3:1 이상이어야 한다.
    public static let inkOnChipBackgrounds: [UInt32] = [apricot, sun, coral, shell]

    /// WCAG 2.1 상대휘도.
    public static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = channel((hex >> 16) & 0xFF)
        let green = channel((hex >> 8) & 0xFF)
        let blue = channel(hex & 0xFF)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// WCAG 2.1 대비비. 1.0 ~ 21.0.
    public static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let first = relativeLuminance(a)
        let second = relativeLuminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
