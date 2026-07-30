# 알림 메시지 관리 구현 계획

**Goal:** 고정 알림 문구를 사용자가 관리하는 순서형 메시지 목록으로 교체한다.

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-30-reminder-message-management-design.md`

## Task 1: 메시지 모델과 저장소

- [x] `ReminderMessage`와 기본 메시지 카탈로그를 추가한다.
- [x] UserDefaults 및 인메모리 저장소를 추가한다.
- [x] 추가·수정·삭제·순서 변경을 담당하는 뷰 모델을 추가한다.
- [x] 유효성 검사와 저장소 테스트를 추가한다.

## Task 2: 알림 예약 연결

- [x] `ReminderScheduling`이 순서형 메시지 목록을 받게 한다.
- [x] 반복 알림 시각에 메시지를 순서대로 배정한다.
- [x] 알림 제목은 앱 이름, 본문은 관리 문구로 표시한다.
- [x] 스케줄 뷰 모델 전달 테스트를 추가한다.

## Task 3: 설정 화면

- [x] 메시지 개수와 관리 화면 진입 행을 추가한다.
- [x] 추가·수정 편집기와 삭제, 드래그 순서 변경을 추가한다.
- [x] 변경 후 알림 설정 저장이 필요함을 안내한다.

## Task 4: 검증

- [x] `cd CoachingKit && swift test` — 170 tests, 0 failures
- [x] `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`
  - 당시에는 실행 환경이 중첩 `sandbox-exec`를 허용하지 않아 패키지 해석 단계에서 중단됐다.
    대신 CoachingKit을 iOS Simulator 대상으로 빌드하고 변경된 설정 화면과 알림 서비스를 `swiftc -typecheck`로 검증했다.
  - 2026-07-30에 같은 명령이 `** BUILD SUCCEEDED **`로 통과했다. 남은 제약이 아니라 당시 환경 문제였다.
