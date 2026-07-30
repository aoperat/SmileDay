import XCTest
@testable import CoachingKit

final class SDPaletteTests: XCTestCase {
    private func name(_ hex: UInt32) -> String { String(format: "#%06X", hex) }

    func test_contrastRatio_isSymmetricAndBounded() {
        XCTAssertEqual(SDPalette.contrastRatio(0x000000, 0xFFFFFF), 21.0, accuracy: 0.01)
        XCTAssertEqual(SDPalette.contrastRatio(0xFFFFFF, 0x000000), 21.0, accuracy: 0.01)
        XCTAssertEqual(SDPalette.contrastRatio(0x7E6A74, 0x7E6A74), 1.0, accuracy: 0.001)
    }

    /// 본문과 캡션은 흰 카드 위에도, 크림 배경 위에도 올라간다.
    func test_bodyTextColors_meetAAOnBothBackgrounds() {
        for color in SDPalette.bodyTextColors {
            let onWhite = SDPalette.contrastRatio(color, SDPalette.white)
            let onCream = SDPalette.contrastRatio(color, SDPalette.cream)
            XCTAssertGreaterThanOrEqual(onWhite, 4.5, "\(name(color)) on white")
            XCTAssertGreaterThanOrEqual(onCream, 4.5, "\(name(color)) on cream")
        }
    }

    /// 버튼 라벨은 15pt 굵은 글씨라 큰 글자 기준 3:1이 적용된다.
    func test_whiteOnColorBackgrounds_meetLargeTextMinimum() {
        for background in SDPalette.whiteOnColorBackgrounds {
            let ratio = SDPalette.contrastRatio(SDPalette.white, background)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "white on \(name(background))")
        }
    }

    func test_inkGlyphOnChipBackgrounds_meetNonTextMinimum() {
        for background in SDPalette.inkOnChipBackgrounds {
            let ratio = SDPalette.contrastRatio(SDPalette.ink, background)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "ink on \(name(background))")
        }
    }

    /// 흰 글자를 쓰면 안 되는 밝은 배경이 whiteOnColorBackgrounds에 섞여 들어오지 않게 한다.
    func test_lightChipBackgrounds_areNotUsedForWhiteText() {
        for background in [SDPalette.sun, SDPalette.apricot] {
            XCTAssertFalse(
                SDPalette.whiteOnColorBackgrounds.contains(background),
                "\(name(background))는 흰 글자를 받기에 너무 밝다"
            )
        }
    }

    func test_countdownColor_isReadableOnCream() {
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.ink, SDPalette.cream), 4.5)
    }

    /// 시작 화면과 새 핵심 화면의 제목·보조 문구 조합.
    func test_reachableScreenText_isReadableOnCreamAndCards() {
        for textColor in [SDPalette.ink, SDPalette.muted] {
            XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(textColor, SDPalette.cream), 4.5)
            XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(textColor, SDPalette.white), 4.5)
        }
    }

    func test_coralDeepDecorativeIcons_areVisibleOnLightSurfaces() {
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.coralDeep, SDPalette.cream), 3.0)
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.coralDeep, SDPalette.white), 3.0)
    }
}
