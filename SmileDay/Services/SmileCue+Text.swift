import Foundation
import CoachingKit

extension SmileCue {
    /// 가이드 화면에 보이는 문구. 키는 `Coaching.xcstrings`의 `smileCue.<id>`.
    ///
    /// 심볼(`.Coaching.smileCue…`)이 아니라 키 문자열로 조회한다 — id가 데이터라 심볼을 정적으로
    /// 고를 수 없다. 대응 키가 있다는 보증은 `StringCatalogGuaranteeTests`가 진다.
    var text: String {
        String(localized: String.LocalizationValue("smileCue.\(id)"), table: "Coaching")
    }
}
