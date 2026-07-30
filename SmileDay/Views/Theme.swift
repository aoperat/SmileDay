import SwiftUI
import CoachingKit

/// 모닝 글로우 디자인 토큰.
///
/// 원시 hex 값은 `CoachingKit.SDPalette`에 있다. 앱 타깃에는 테스트 번들이 없어
/// 대비 회귀를 잡을 수 없으므로, 값은 그쪽에 두고 여기서는 감싸기만 한다.
enum SDColor {
    static let coral = Color(hex: SDPalette.coral)
    static let coralDeep = Color(hex: SDPalette.coralDeep)
    static let apricot = Color(hex: SDPalette.apricot)
    static let sun = Color(hex: SDPalette.sun)
    static let cream = Color(hex: SDPalette.cream)
    static let ink = Color(hex: SDPalette.ink)
    static let muted = Color(hex: SDPalette.muted)
    static let shell = Color(hex: SDPalette.shell)
    static let alert = Color(hex: SDPalette.alert)

    /// 흰 글자를 얹으므로 진한 쪽 두 색만 쓴다. 더 밝은 코랄은 흰 글자 대비가 3:1에 못 미친다.
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [coralDeep, coral], startPoint: .leading, endPoint: .trailing)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 두 디자인 토큰 사이의 중간 색. `Color.mix(with:by:)`는 iOS 18부터라 직접 섞는다.
    init(blending start: UInt32, with end: UInt32, ratio: Double) {
        let t = min(max(ratio, 0), 1)
        func channel(_ shift: UInt32) -> Double {
            let from = Double((start >> shift) & 0xFF)
            let to = Double((end >> shift) & 0xFF)
            return (from + (to - from) * t) / 255
        }
        self.init(red: channel(16), green: channel(8), blue: channel(0))
    }
}

/// 위로 웃는 스마일 곡선. rect 좌우 끝을 잇고 아래로 볼록한 2차 곡선.
struct SmileArc: Shape {
    /// 0~1. rect 높이 대비 곡선 깊이.
    var depth: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2 * depth)
        )
        return path
    }
}

struct SDCardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: SDColor.coral.opacity(0.14), radius: 13, y: 5)
    }
}

extension View {
    func sdCard(padding: CGFloat = 16, cornerRadius: CGFloat = 24) -> some View {
        modifier(SDCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

/// 코랄 그라디언트 필 버튼.
struct SDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SDColor.primaryGradient, in: Capsule())
            .shadow(color: SDColor.coral.opacity(0.5), radius: 10, y: 5)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 진한 잉크색 필 버튼 (완료 후 닫기 등).
struct SDInkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(SDColor.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 전체 화면 좌상단 닫기 버튼.
struct SDCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SDColor.ink)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.9), in: Circle())
                .shadow(color: SDColor.ink.opacity(0.15), radius: 6, y: 2)
        }
        .accessibilityLabel("나가기")
    }
}

enum SDFormat {
    /// 앱 카피가 전부 한국어라 날짜 표기도 기기 로캘과 무관하게 한국어로 고정한다.
    static let koreanLocale = Locale(identifier: "ko_KR")
}
