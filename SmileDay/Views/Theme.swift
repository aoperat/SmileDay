import SwiftUI

/// 모닝 글로우 디자인 토큰.
enum SDColor {
    static let coral = Color(hex: 0xF65D73)
    static let coralDeep = Color(hex: 0xE04360)
    static let coralWarm = Color(hex: 0xFB7E62)
    static let apricot = Color(hex: 0xFFA94D)
    static let sun = Color(hex: 0xFFC93C)
    static let mint = Color(hex: 0x3BAF8C)
    static let lilac = Color(hex: 0xB79CE4)
    static let cream = Color(hex: 0xFFF6EE)
    static let ink = Color(hex: 0x46323C)
    static let muted = Color(hex: 0xA08B96)
    static let shell = Color(hex: 0xF1E2D6)

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [coral, coralWarm], startPoint: .leading, endPoint: .trailing)
    }

    static var gaugeGradient: LinearGradient {
        LinearGradient(colors: [apricot, coral], startPoint: .bottom, endPoint: .top)
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

    /// 곡선 위 위치(t: 0~1)의 좌표. 도트 배치용.
    static func point(t: CGFloat, in rect: CGRect, depth: CGFloat = 1.0) -> CGPoint {
        let x = rect.minX + rect.width * t
        let y = rect.minY + rect.height * 2 * depth * 2 * t * (1 - t)
        return CGPoint(x: x, y: y)
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

/// 진한 잉크색 필 버튼 (측정 종료 등).
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

/// 카메라 화면 좌상단 닫기 버튼.
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

    static func signedDegrees(_ value: Int) -> String {
        value >= 0 ? "+\(value)°" : "\(value)°"
    }

    static func signedDegrees(_ value: Double, fractionDigits: Int = 1) -> String {
        signedNumber(value, fractionDigits: fractionDigits) + "°"
    }

    /// 부호 포함 소수 표기. 표시 자릿수로 반올림한 뒤 부호를 정하므로 "-0.0"이 나오지 않는다.
    static func signedNumber(_ value: Double, fractionDigits: Int = 1) -> String {
        let scale = pow(10.0, Double(fractionDigits))
        var rounded = (value * scale).rounded() / scale
        if rounded == 0 { rounded = 0 } // -0.0 → +0.0 정규화
        let magnitude = abs(rounded).formatted(.number.precision(.fractionLength(fractionDigits)))
        return (rounded < 0 ? "-" : "+") + magnitude
    }
}
