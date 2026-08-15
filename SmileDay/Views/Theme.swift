import SwiftUI
import UIKit
import CoachingKit

/// 모닝 글로우 디자인 토큰.
///
/// 원시 hex 값은 `CoachingKit.SDPalette`에 있다. 앱 타깃에는 테스트 번들이 없어
/// 대비 회귀를 잡을 수 없으므로, 값은 그쪽에 두고 여기서는 감싸기만 한다.
enum SDColor {
    static let sun = Color(hex: SDPalette.sun)
    static let apricot = Color(hex: SDPalette.apricot)
    static let sunDeep = Color(hex: SDPalette.sunDeep)
    static let cream = Color(hex: SDPalette.cream)
    static let ink = Color(hex: SDPalette.ink)
    static let muted = Color(hex: SDPalette.muted)
    static let shell = Color(hex: SDPalette.shell)
    static let alert = Color(hex: SDPalette.alert)

    /// 주조색 그라디언트. **여기에 얹는 글자는 `ink`다** — 흰 글자는 노랑 위에서 1.7:1이다.
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [apricot, sun], startPoint: .leading, endPoint: .trailing)
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
            .shadow(color: SDColor.apricot.opacity(0.16), radius: 13, y: 5)
    }
}

extension View {
    func sdCard(padding: CGFloat = 16, cornerRadius: CGFloat = 24) -> some View {
        modifier(SDCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

/// 주조색(노랑) 그라디언트 필 버튼.
struct SDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            // 흰 글자가 아니다. 노랑 위 흰 글자는 1.7:1이고, ink는 7.7:1이다.
            .foregroundStyle(SDColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SDColor.primaryGradient, in: Capsule())
            .shadow(color: SDColor.apricot.opacity(0.5), radius: 10, y: 5)
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
        .accessibilityLabel(Text(.closeAccessibilityLabel))
    }
}

enum SDFormat {
    /// 흘러간 시간. "45초" / "3분" / "3분 20초".
    ///
    /// 세션 길이와 알림 간격이 같은 규칙을 쓴다. 예전에는 설정 화면과 요약 화면에 글자만 다른
    /// 같은 함수가 따로 있었다 — 한쪽에서 "1분 0초"를 고쳐도 다른 쪽은 그대로였다.
    static func duration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        guard minutes > 0 else { return "\(remainder)초" }
        return remainder == 0 ? "\(minutes)분" : "\(minutes)분 \(remainder)초"
    }

    /// 알림 반복 주기. "30분마다" / "3시간마다".
    ///
    /// 위 `duration`과 규칙이 다르다. 30분을 `분 / 60`으로 적으면 "0시간마다"가 되므로
    /// 한 시간 미만은 분으로 적고, 되풀이한다는 뜻의 "마다"가 붙는다.
    /// 두 함수를 나란히 두는 이유가 이것이다 — 규칙이 다르다는 사실이 눈에 보여야 한다.
    static func reminderInterval(minutes: Int) -> String {
        minutes < 60 ? "\(minutes)분마다" : "\(minutes / 60)시간마다"
    }
}

/// iOS 설정 앱에서 이 앱의 화면을 연다.
///
/// 알림 권한과 카메라 권한은 둘 다 iOS가 한 번만 묻고, 거부되면 앱 안에서는 되돌릴 수 없다.
/// 그래서 네 화면이 각자 이 안내를 띄우는데, 예전에는 URL을 만들고 여는 세 줄이 다섯 자리에
/// 복사돼 있었다. 주소를 만들지 못하면 아무 일도 하지 않는다 — 열 곳이 없는데 열었다고
/// 말하지 않는다.
enum SDSystemSettings {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
