# 리마인더 딥링크 + 버킷별 체크인 기록 설계

**상태**: 승인됨
**작성일**: 2026-07-24
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

리마인더 알림([[2026-07-23-reminder-expression-prompts-design]])은 시간대별 표정 질문을 던지지만, 탭하면 그냥 홈이 열릴 뿐이다. 알림에 딥링크 정보가 없고 앱에 `UNUserNotificationCenterDelegate`가 없어서, 사용자는 홈에서 다시 기록 버튼을 찾아 눌러야 한다. 이미 체크인한 날에는 홈 CTA도 사라져 알림을 눌러도 할 일이 없다.

이번 설계의 목표:

1. **알림 탭 → 바로 측정**: 홈을 거치지 않고 코칭 화면으로 진입한다.
2. **질문 연속성**: 알림의 표정 질문이 측정 화면까지 이어져 보인다.
3. **버킷별 기록**: 하루 기록을 아침/낮/저녁 버킷 단위로 쌓는다. 단, 스트릭·홈·주간 통계는 지금처럼 하루 단위를 유지해 부담을 늘리지 않는다.

## 2. 동작 정의

### 알림 탭 라우팅

- 알림 예약 시 `userInfo`에 버킷 rawValue와 질문 문구를 싣는다.
- 알림 탭을 감지하면 코칭 탭으로 전환하고 질문 문구를 측정 화면에 전달한다.
- 콜드 스타트(앱 종료 상태에서 탭)와 러닝 상태 모두 동일하게 동작한다.
- 앱 사용 중 알림이 도착하면 배너로 표시한다(현재는 포그라운드에서 알림이 조용히 사라짐).
- 구버전 알림(userInfo 없음)을 탭하면 지금처럼 홈으로 — 하위 호환.

### 딥링크 진입 시 상태 처리

- 알림 진입은 **항상 측정 화면으로** 보낸다. 해당 버킷에 이미 기록이 있어도 재측정을 허용한다(마지막 기록이 대표값이므로 자연스럽게 갱신). 분기 없음.

### 버킷 기록 규칙

- **스키마 변경 없음.** `CheckInSession.date`의 시(hour)를 `TimeBucket(hour:)`에 넣어 버킷을 유도한다. 과거 기록도 소급 분류된다.
- 같은 버킷에 여러 기록이 있으면 **마지막 기록이 그 버킷의 대표값** (기존 "같은 날은 마지막이 남는다" 규칙의 버킷 버전).
- 버킷 귀속은 **달력일 기준**: 새벽 2시 기록은 그 날짜의 "저녁" 버킷으로 분류된다(저녁 버킷 범위가 17–04시이므로).
- 홈 히어로("완료했어요" 상태 포함), 스트릭, 주간 도트, 7일 평균, 오늘 점수: **전부 기존 로직 그대로.**

### 기록 탭 상세

- 날짜별 상세에 아침/낮/저녁 세 줄을 추가한다. 기록된 버킷은 점수(예: "아침 +2.1°"), 없는 버킷은 "—".
- 하루 대표 점수 표시는 기존 그대로, 버킷 줄은 그 아래 보조 정보.

## 3. 컴포넌트 설계

**UserNotificationReminderScheduler** — 예약 시 userInfo 추가:

```swift
content.userInfo = [
    "bucket": prompt.bucket.rawValue,
    "promptText": prompt.text,
]
```

**NotificationRouter (신규, SmileDay 타겟)** — 알림 탭 신호를 뷰 계층에 전달하는 `@Observable` 객체:

```swift
@Observable
final class NotificationRouter {
    struct CoachingRequest: Equatable {
        let bucket: TimeBucket
        let promptText: String
    }
    var pendingCoaching: CoachingRequest?

    /// userInfo를 파싱해 pendingCoaching을 설정. 파싱 실패 시 아무것도 안 함(홈 유지).
    func handleNotificationTap(userInfo: [AnyHashable: Any])
}
```

**AppDelegate 어댑터 (신규)** — `SmileDayApp`에 `@UIApplicationDelegateAdaptor`로 붙이고 `UNUserNotificationCenterDelegate` 구현:

- `didReceive`: `router.handleNotificationTap(userInfo:)` 호출
- `willPresent`: `.banner` 반환(포그라운드 배너)
- 라우터는 App에서 생성해 environment로 주입, delegate는 launch 시점에 등록

**MainTabView** — `pendingCoaching` 감지 시 `selection = .coaching`으로 전환하고 요청을 소비(nil로 리셋). 코칭 탭에 `promptText` 전달.

**CoachingSessionView** — 선택적 `promptText: String?` 파라미터. 있으면 상단에 질문 오버레이 표시(조명/각도 경고 라벨과 같은 스타일). 일반 진입에서는 nil이라 현재와 동일.

**CoachingKit — 버킷 집계** (`HistoryViewModel` 확장):

```swift
/// 해당 날짜의 버킷별 대표 점수. 같은 버킷은 마지막 기록이 남는다.
func bucketScores(onDayOf date: Date) throws -> [TimeBucket: Double]
```

**HistoryView** — 날짜 상세에 버킷 세 줄 추가. 기존 하루 대표 점수 아래 보조 표시.

## 4. 테스트 관점

- 스케줄러: 예약된 요청의 userInfo에 bucket/promptText가 실리는지, bucket이 예약 hour와 일치하는지
- NotificationRouter: 정상 userInfo 파싱, 필드 누락·미지의 rawValue 시 pendingCoaching이 nil 유지
- 버킷 집계: 같은 버킷 중복 시 마지막 승리, 버킷 미기록 시 누락, 새벽 기록의 저녁 버킷 귀속
- UI(탭 전환, 오버레이)는 관례대로 빌드 검증

## 5. 이번 설계에 포함하지 않는 것

- 알림 롱프레스 액션("지금 기록하기" / "30분 뒤 다시") — 다음 사이클
- 저녁 리캡 화면, 체크인 후 케어 루틴 폴백 — 이번 인프라 위에 얹을 후속 스펙
- 홈 화면의 버킷 표시(진행 도트 3분할 등) — 홈은 하루 단위 유지 결정
- 버킷별 리마인더 문구 개인화
