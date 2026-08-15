import Foundation

/// 디자인 토큰의 원시 색값. 앱 타깃에는 테스트 번들이 없어 여기 두고 대비를 테스트로 고정한다.
/// `SmileDay/Views/Theme.swift`의 `SDColor`가 이 값을 SwiftUI `Color`로 감싼다.
/// **주조색은 노랑이다.** 미소가 이 앱의 가치이므로 화면의 중심색이 그것을 가리켜야 한다.
/// 2026-07-31에 코랄(분홍) 계열을 걷어냈다 — `coral`/`coralDeep`은 더 이상 없다.
///
/// 노랑으로 바꾸면서 규칙이 하나 뒤집혔다. **주조색 위의 글자는 흰색이 아니라 `ink`다.**
/// 흰 글자는 `sun` 위에서 1.7:1로 큰 글자 기준(3:1)에도 한참 못 미친다. 그래서
/// `whiteOnColorBackgrounds`가 비었고, 대신 `inkOnPrimaryBackgrounds`가 생겼다.
public enum SDPalette {
    /// 주조색. 버튼·스플래시·그래프의 "미소"가 이 색이다.
    public static let sun: UInt32 = 0xFFC93C
    /// 주조색 그라디언트의 진한 끝. 그래프에서 "미소" 칸에도 쓴다.
    public static let apricot: UInt32 = 0xFFA94D
    /// 밝은 배경 위에 올리는 노랑 계열의 진한 끝 — 아이콘 틴트와 스위치.
    ///
    /// `sun`은 크림 배경 위에서 1.4:1이라 아이콘으로 쓸 수 없다. 같은 계열에서 충분히
    /// 어두운 값을 따로 둔다(크림 위 5.1:1이라 글자로 써도 된다).
    public static let sunDeep: UInt32 = 0x9A5B00
    public static let cream: UInt32 = 0xFFF6EE
    public static let ink: UInt32 = 0x46323C
    /// 보조 텍스트. 흰 배경과 크림 배경 모두에서 본문 기준을 넘겨야 한다.
    public static let muted: UInt32 = 0x7E6A74
    public static let shell: UInt32 = 0xF1E2D6
    /// 저장 실패 같은 문제 상황 문구.
    public static let alert: UInt32 = 0xC8324C
    public static let white: UInt32 = 0xFFFFFF

    /// 본문·캡션에 쓰는 색. 흰 배경과 크림 배경 모두에서 4.5:1 이상이어야 한다.
    public static let bodyTextColors: [UInt32] = [ink, muted, alert, sunDeep]
    /// 흰 글자를 얹는 배경. 주조색이 노랑이 되면서 하나도 남지 않았다.
    ///
    /// 비워둔 채로 남긴다. 흰 글자를 받을 만큼 어두운 배경색이 다시 생기면 여기 넣어야
    /// 대비 테스트가 따라온다 — 목록을 지우면 그 안전장치가 사라진다.
    public static let whiteOnColorBackgrounds: [UInt32] = []
    /// `ink` 글자를 얹는 주조색 배경. 굵은 버튼 글자 기준 3:1 이상이어야 한다.
    public static let inkOnPrimaryBackgrounds: [UInt32] = [sun, apricot]
    /// ink 글리프를 얹는 아이콘 칩 배경. 비텍스트 기준 3:1 이상이어야 한다.
    public static let inkOnChipBackgrounds: [UInt32] = [apricot, sun, shell]

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
