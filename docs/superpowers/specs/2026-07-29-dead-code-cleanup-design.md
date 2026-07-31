# 빈도 중심 전환 후 죽은 코드 정리 설계

- 날짜: 2026-07-29
- 상태: 제안됨
- 상위 제품 설계: `2026-07-29-smile-frequency-window-reminders-design.md`
- 배경: 카메라·점수·기록·케어·상황 카드 UI는 새 Root 흐름에서 제거됐지만, 이를 지원하던 패키지 로직과 테스트가 여전히 빌드된다.

## 1. 목적

현재 제품의 핵심 루프는 다음 하나다.

```text
반복 알림
→ 비평가적 문구
→ 5초 미소
→ 완료 시각 저장
→ 오늘과 최근 7일 횟수 확인
```

이 루프와 기존 데이터 호환에 기여하지 않는 코드는 삭제한다. SwiftData 기존 저장소를 열기 위해 필요한 모델 타입과 저장 프로퍼티는 화면에서 사용하지 않더라도 유지한다.

## 2. 확인된 상태

2026-07-29 정적 참조 검사에서 앱 Swift 소스로부터 도달할 수 없는 `CoachingKit` 소스가 25개 파일, 약 2,149줄 확인됐다. 호환 모델의 사용하지 않는 편의 API를 먼저 제거하면 `FaceMeasurement.swift`와 `ReminderPrompt.swift`도 전체 삭제할 수 있다.

현재 `swift test`는 390개 XCTest가 통과한다. 이 중 상당수는 앱에서 사용하지 않는 과거 기능을 테스트하므로, 테스트 통과만으로 제품 코드가 살아 있다고 판단하지 않는다.

이 정리 뒤 선택형 실시간 미소 확인 모드를 새로 추가한다. 과거 기준선·체크인·점수 저장 파이프라인을 되살리지 않고, `2026-07-29-live-smile-monitor-design.md`에 따라 프리뷰와 영속 저장이 없는 최소 측정 경계를 새로 만든다. 따라서 이 문서의 레거시 측정 코드 삭제 판단은 유지한다.

## 3. 삭제 원칙

### 삭제한다

- 카메라·얼굴 측정·점수 계산 로직
- 기준선 촬영과 점수형 체크인 ViewModel
- 과거 홈·기록·인사이트·회고 로직
- 케어·미소 연습·상황 카드 CRUD 로직
- 시간대별 질문, nudge, 개별 알림 편집 로직
- 위 코드만 검증하는 테스트 더블과 XCTest
- 앱 테마의 미사용 토큰과 미사용 도형 계산 함수

### 유지한다

- 활성 모델: `SmileMoment`, `SmileReminderSchedule`
- 활성 저장소와 ViewModel: 미소 완료, 반복 스케줄, 홈, 온보딩, 5초 가이드
- 기존 저장소 호환 모델:
  - `Baseline`
  - `CheckInSession`
  - `ReminderSetting`
  - `CareSession`
  - `CustomSmileCard`
- 기존 개별 pending notification을 취소하는 데 필요한 최소 조회·취소 경로
- 이미 예약된 신·구 알림 payload를 인식하는 파서

## 4. 영속성 경계

`PersistenceSchema.models`에서 기존 모델을 제거하지 않는다.

```swift
[
    Baseline.self,
    CheckInSession.self,
    ReminderSetting.self,
    CareSession.self,
    SmileMoment.self,
    CustomSmileCard.self,
    SmileReminderSchedule.self,
]
```

호환 모델에서는 SwiftData 스키마를 구성하는 저장 프로퍼티를 유지한다. 다음과 같은 비영속 편의 API는 앱 참조가 없다면 제거할 수 있다.

- `Baseline.measurement`, `ageWeeks`, `isOverdueForReset`
- `CustomSmileCard.slot`, `guide`
- 새 레코드 생성에만 쓰이던 과거 기능 전용 initializer 인자

저장 프로퍼티의 이름·타입·optional 여부·기본값은 이번 정리에서 바꾸지 않는다. 모델 삭제나 저장 프로퍼티 변경이 필요하면 별도의 버전드 스키마 마이그레이션 설계를 작성한다.

## 5. 활성 API 축소

### 기존 개별 알림

새 반복 스케줄 저장 후 과거 pending notification을 취소하려면 기존 `ReminderSetting.notificationID` 목록만 필요하다.

- `ReminderRepository`는 최소 레거시 조회 경계로 축소하거나 `LegacyReminderRepository`로 명확히 이름을 바꾼다.
- 개별 알림 추가·수정·삭제 및 시간대 집계 API는 제거한다.
- `ReminderScheduling.cancel(id:)`는 유지한다.
- 호출되지 않는 `scheduleRollingWindow(...)` 구현은 제거한다.

### 미소 가이드

활성 화면은 상황 카드 카탈로그가 아니라 `SmileCue` 문구와 고정 5초 실행을 사용한다.

- `SmileGuideLibrary`, 숨김 카드 저장소, 카드 관리 ViewModel은 제거한다.
- `SmileGuide`는 활성 타이머 저장에 필요한 최소 값만 남긴다.
- 내장 상황 카드 목록, `DaySlot`, 별칭 조회는 제거한다.
- `CustomSmileCard` 타입과 저장 프로퍼티는 스키마 호환을 위해 남긴다.

### 알림 payload와 완료 기록

현재 화면은 payload의 ID 값이 아니라 “유효한 미소 알림을 탭했다”는 신호만 소비한다. 그러나 기기에 이미 예약된 알림과 `SmileMoment.guideID` 저장 필드가 있으므로 이번 정리에서는 필드를 즉시 삭제하지 않는다.

- 파싱 호환 테스트는 유지한다.
- 쓰기 전용 필드 축소는 최소 한 번의 배포·마이그레이션 검증 뒤 별도 작업으로 판단한다.

## 6. 테스트 전략

- 삭제되는 기능 전용 테스트는 소스와 함께 제거한다.
- 테스트 개수 감소 자체를 실패로 보지 않는다.
- 다음 회귀 테스트는 반드시 유지하거나 강화한다.
  - 기존 스키마로 만든 저장소를 현재 스키마로 다시 열 수 있음
  - 다섯 레거시 모델의 레코드와 주요 저장값이 유지됨
  - 새 미소 완료와 반복 스케줄 저장·재열기
  - 새 반복 스케줄 확정 뒤 기존 notification ID 취소
  - 신·구 알림 payload 파싱
  - 5초 가이드의 중복 저장 방지
  - 오늘·최근 7일 횟수와 다음 알림 계산

## 7. 범위 제외

- 기존 사용자 데이터 삭제
- SwiftData 저장 프로퍼티 이름이나 타입 변경
- `SmileMoment.guideID` 제거
- 알림 payload 포맷의 비호환 변경
- 새 기능, 새 화면, 새 사용자 문구 추가
- 사용자 데이터의 자동 정리 또는 마이그레이션

## 8. 완료 기준

- 앱 Swift 소스에서 카메라·점수·기록·케어·상황 카드 기능 코드로 이어지는 참조가 없다.
- 정리 대상으로 합의한 죽은 소스와 전용 테스트가 삭제됐다.
- 다섯 기존 모델이 `PersistenceSchema`에 계속 등록돼 있다.
- 기존 저장소 재열기 테스트가 통과한다.
- `CoachingKit` 전체 테스트가 통과한다.
- iOS 17 generic simulator 앱 빌드가 통과한다.
- `git diff --check`가 통과하고 사용자 기존 변경이 보존된다.
