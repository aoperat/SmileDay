import Foundation

/// v1 저장 데이터를 v2 모양으로 옮긴다.
///
/// 1.x는 기본 문구를 텍스트로 저장했다. 사용자가 한 항목만 고쳐도 기본 8개가 통째로 그 시점
/// 언어로 굳는 구조였다. 여기서는 **1.x가 실제로 출하한 한국어 원문**과 정확히 같은 항목만
/// "손대지 않은 기본값"으로 보고 `text = nil`로 되돌린다.
///
/// 비교값은 아래 상수다. **카탈로그를 조회하면 안 된다** — 카탈로그는 현재 언어로 해석되므로
/// 영어 기기에서는 영어가 나와 영원히 불일치하고, 그 사용자만 한국어 알림에 갇힌다.
/// 마이그레이션 데이터는 역사적 사실이지 지역화 대상이 아니다.
public enum ReminderMessageMigration {
    /// 1.x 빌드의 `ReminderMessageCatalog.defaults` 원문. 절대 수정하지 않는다.
    static let legacyKoreanDefaults: [String: String] = [
        "gentle-five-seconds": "지금 괜찮다면 5초만 편안하게 미소 지어보세요.",
        "release-shoulders": "잠깐 어깨 힘을 빼고 입꼬리를 살짝 올려볼까요?",
        "warm-greeting": "반가운 사람에게 인사하듯 가볍게 미소 지어보세요.",
        "comfortable-is-enough": "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요.",
        "remember-gratitude": "고마운 사람을 떠올리며 잠깐 미소 지어볼까요?",
        "relax-expression": "화면에서 눈을 떼고 얼굴의 힘을 가볍게 풀어볼까요?",
        "kind-to-self": "오늘의 나에게 따뜻한 표정을 보내볼까요?",
        "bright-as-comfortable": "지금 잠깐, 편한 만큼 밝게 웃어볼까요?",
    ]

    /// 멱등이다 — 이미 nil인 항목은 그대로, 사용자 문구는 그대로.
    public static func promoteUntouchedDefaults(_ messages: [ReminderMessage]) -> [ReminderMessage] {
        messages.map { message in
            guard let text = message.text,
                  legacyKoreanDefaults[message.id] == text else { return message }
            return ReminderMessage(id: message.id, text: nil)
        }
    }
}
