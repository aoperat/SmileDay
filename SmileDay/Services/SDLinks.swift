import Foundation

/// 앱 밖으로 나가는 주소. 문구가 아니라 상수라 카탈로그에 두지 않는다.
///
/// 문자열로 둔다 — `URL(string:)!`은 오타 하나가 실행 중 크래시가 된다. 화면에서 만들어
/// 보고, 만들지 못하면 줄을 그리지 않는다.
enum SDLinks {
    static let privacyPolicy = "https://dolparo.com/smileday/privacy"
    static let support = "https://dolparo.com/smileday/support"
}
