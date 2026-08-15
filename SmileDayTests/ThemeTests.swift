import XCTest
import SwiftUI
import UIKit
import CoachingKit
@testable import SmileDay

/// 앱 타깃의 색 변환.
///
/// 원시 hex 값과 WCAG 대비는 `CoachingKit`의 `SDPaletteTests`가 지킨다. 여기서는 그 값을
/// SwiftUI `Color`로 감싸는 과정에서 채널이 어긋나지 않는지만 본다 — 시프트 하나가 틀리면
/// 대비 테스트는 그대로 통과하는데 화면의 색만 바뀐다.
final class ThemeTests: XCTestCase {

    /// sRGB 채널을 0~1로 읽는다. iOS에서 `Color`는 `UIColor`로 정확히 되돌릴 수 있다.
    private func channels(_ color: Color) -> (r: Double, g: Double, b: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }

    private func assertChannels(
        _ color: Color,
        _ expected: (r: Double, g: Double, b: Double),
        accuracy: Double = 0.005,
        line: UInt = #line
    ) {
        let actual = channels(color)
        XCTAssertEqual(actual.r, expected.r, accuracy: accuracy, "red", line: line)
        XCTAssertEqual(actual.g, expected.g, accuracy: accuracy, "green", line: line)
        XCTAssertEqual(actual.b, expected.b, accuracy: accuracy, "blue", line: line)
    }

    // MARK: - hex 변환

    func test_hex가_채널_순서대로_풀린다() {
        assertChannels(Color(hex: 0xFF0000), (1, 0, 0))
        assertChannels(Color(hex: 0x00FF00), (0, 1, 0))
        assertChannels(Color(hex: 0x0000FF), (0, 0, 1))
    }

    func test_hex_흑백이_양끝에_닿는다() {
        assertChannels(Color(hex: 0x000000), (0, 0, 0))
        assertChannels(Color(hex: 0xFFFFFF), (1, 1, 1))
    }

    /// 주조색이 노랑이라는 사실이 토큰에서 화면까지 이어진다.
    func test_주조색이_팔레트_값과_같다() {
        assertChannels(SDColor.sun, channels(Color(hex: SDPalette.sun)))
        assertChannels(SDColor.ink, channels(Color(hex: SDPalette.ink)))
    }

    // MARK: - 두 토큰 섞기

    func test_섞기_양끝이_원본과_같다() {
        assertChannels(Color(blending: 0x000000, with: 0xFFFFFF, ratio: 0), (0, 0, 0))
        assertChannels(Color(blending: 0x000000, with: 0xFFFFFF, ratio: 1), (1, 1, 1))
    }

    func test_섞기_중간값이_절반이다() {
        assertChannels(Color(blending: 0x000000, with: 0xFFFFFF, ratio: 0.5), (0.5, 0.5, 0.5))
    }

    /// 범위를 벗어난 비율은 양끝으로 잘린다.
    ///
    /// 자르지 않으면 채널이 0~1 밖으로 나가고, 실시간 확인의 단계 막대에서 칸 색이 뒤집힌다.
    func test_섞기_범위를_벗어난_비율은_잘린다() {
        assertChannels(Color(blending: 0x000000, with: 0xFFFFFF, ratio: -1), (0, 0, 0))
        assertChannels(Color(blending: 0x000000, with: 0xFFFFFF, ratio: 2), (1, 1, 1))
    }

    /// 단계 막대가 실제로 쓰는 조합. 칸이 늘수록 노랑에서 살구로 옮겨간다.
    func test_단계막대_색이_노랑에서_살구로_이어진다() {
        let steps = max(LiveSmileLevel.allCases.count - 1, 1)
        let first = Color(blending: SDPalette.sun, with: SDPalette.apricot, ratio: 0)
        let last = Color(blending: SDPalette.sun, with: SDPalette.apricot, ratio: Double(steps) / Double(steps))

        assertChannels(first, channels(Color(hex: SDPalette.sun)))
        assertChannels(last, channels(Color(hex: SDPalette.apricot)))
    }
}

/// 요약이 왜 떴는지 말하는 규칙.
///
/// 종료를 누르지 않았는데 요약이 나타나면 사용자는 자기가 뭘 잘못 눌렀다고 생각한다.
final class LiveSmileSessionEndReasonTests: XCTestCase {

    /// 스스로 종료를 눌렀으면 설명하지 않는다. 아는 사실을 다시 말하면 잔소리가 된다.
    func test_사용자가_끝냈으면_안내하지_않는다() {
        XCTAssertNil(LiveSmileSessionEndReason.userEnded.notice)
    }

    func test_화면을_벗어났으면_그_이유를_말한다() throws {
        XCTAssertEqual(
            try resolved(LiveSmileSessionEndReason.leftTheApp),
            String(localized: .Coaching.liveSummaryEndedByLeavingApp)
        )
    }

    func test_카메라가_멈췄으면_그_이유를_말한다() throws {
        XCTAssertEqual(
            try resolved(LiveSmileSessionEndReason.interrupted),
            String(localized: .Coaching.liveSummaryEndedByInterruption)
        )
    }

    /// 두 안내는 서로 다른 사건이다. 같은 문구를 쓰면 구분한 의미가 없다.
    func test_두_안내가_서로_다르다() throws {
        XCTAssertNotEqual(
            try resolved(LiveSmileSessionEndReason.leftTheApp),
            try resolved(LiveSmileSessionEndReason.interrupted)
        )
    }

    /// `LocalizedStringResource`는 비교할 수 없어 카탈로그에서 해석한 문장으로 견준다.
    private func resolved(_ reason: LiveSmileSessionEndReason) throws -> String {
        String(localized: try XCTUnwrap(reason.notice))
    }
}
