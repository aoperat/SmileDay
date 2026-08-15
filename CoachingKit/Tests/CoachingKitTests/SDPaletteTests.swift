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

    /// 주조색이 노랑이 되면서 기본 버튼 글자는 흰색이 아니라 `ink`다.
    /// 본문 기준(4.5:1)까지 넘기므로 작은 글씨를 얹어도 된다.
    func test_inkOnPrimaryBackgrounds_meetBodyTextMinimum() {
        XCTAssertFalse(SDPalette.inkOnPrimaryBackgrounds.isEmpty)
        for background in SDPalette.inkOnPrimaryBackgrounds {
            let ratio = SDPalette.contrastRatio(SDPalette.ink, background)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "ink on \(name(background))")
        }
    }

    /// 회귀 방지: 노랑 위에 흰 글자를 얹으려는 시도를 여기서 막는다.
    /// 이 값들이 `whiteOnColorBackgrounds`에 들어가면 위 테스트가 바로 깨져야 한다.
    func test_primaryBackgrounds_cannotCarryWhiteText() {
        for background in SDPalette.inkOnPrimaryBackgrounds {
            XCTAssertLessThan(
                SDPalette.contrastRatio(SDPalette.white, background),
                3.0,
                "\(name(background))는 흰 글자를 받을 수 없다 — ink를 써야 한다"
            )
            XCTAssertFalse(SDPalette.whiteOnColorBackgrounds.contains(background))
        }
    }

    /// 최근 7일 점처럼 흰 카드 위에 놓이는 표시는 윤곽이 3:1을 넘어야 한다(WCAG 1.4.11).
    ///
    /// 주조색만으로는 안 된다는 것이 이 테스트의 요지다. `sun`은 흰 배경에서 1.5:1이라
    /// 채우기만 해서는 형태가 사라지고, 그래서 `sunDeep` 테두리를 두른다.
    /// 이 관계가 뒤집히면 점을 단색으로 되돌려도 되는 것으로 오해할 수 있다.
    func test_primaryFillAloneCannotCarryAShapeOnWhite() {
        XCTAssertLessThan(
            SDPalette.contrastRatio(SDPalette.sun, SDPalette.white),
            3.0,
            "sun만으로 흰 배경 위 도형을 그릴 수 없다 — sunDeep 테두리가 필요하다"
        )
        XCTAssertGreaterThanOrEqual(
            SDPalette.contrastRatio(SDPalette.sunDeep, SDPalette.white),
            3.0,
            "테두리는 흰 배경에서 윤곽을 만들 수 있어야 한다"
        )
    }

    /// 아이콘 틴트와 스위치에 쓰는 색. 밝은 표면 위에서 글자로 써도 될 만큼 어두워야 한다.
    func test_sunDeep_isReadableOnLightSurfaces() {
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.sunDeep, SDPalette.cream), 4.5)
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.sunDeep, SDPalette.white), 4.5)
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

    /// 그래프의 "미소" 칸(`apricot`)과 "안 웃음" 칸(`shell`)은 1pt 열로 나란히 그려진다.
    /// 주조색 `sun`을 그대로 쓰면 둘이 붙어 보여서 진한 쪽을 쓴다 — 그 판단을 고정한다.
    func test_timelineSmilingColor_separatesFromNotSmiling() {
        let apricotVsShell = SDPalette.contrastRatio(SDPalette.apricot, SDPalette.shell)
        let sunVsShell = SDPalette.contrastRatio(SDPalette.sun, SDPalette.shell)

        XCTAssertGreaterThan(
            apricotVsShell,
            sunVsShell,
            "apricot이 shell과 더 잘 갈리므로 그래프의 미소 칸은 apricot이다"
        )
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

    /// 스플래시는 주조색 그라디언트 위에 앱 이름과 문구를 얹는다. 흰 글자가 아니라 `ink`다.
    func test_splashText_isReadableOnThePrimaryGradient() {
        for background in [SDPalette.sun, SDPalette.apricot] {
            XCTAssertGreaterThanOrEqual(
                SDPalette.contrastRatio(SDPalette.ink, background),
                4.5,
                "ink on \(name(background))"
            )
        }
    }
}
