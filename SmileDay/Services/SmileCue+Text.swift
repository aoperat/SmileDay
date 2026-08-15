import Foundation
import CoachingKit

extension SmileCue {
    /// 가이드 화면에 보이는 문구. 키는 `Coaching.xcstrings`의 `smileCue.<id>`.
    ///
    /// 심볼(`.Coaching.smileCue…`)이 아니라 키 문자열로 조회한다 — id가 데이터라 심볼을 정적으로
    /// 고를 수 없다. 대응 키가 있다는 보증은 `StringCatalogGuaranteeTests`가, 실제로 해석된다는
    /// 보증은 `SmileCueTextTests`가 진다.
    ///
    /// 키를 먼저 `String`으로 합친 뒤 넘긴다. `String.LocalizationValue("smileCue.\(id)")`처럼
    /// 보간 리터럴을 직접 넘기면 보간이 **포맷 인자**로 잡혀 `smileCue.%@`를 찾고, 없으니 키가
    /// 그대로 화면에 뜬다 — 실측했다.
    var text: String {
        let key = "smileCue." + id
        return String(localized: String.LocalizationValue(key), table: "Coaching")
    }
}
