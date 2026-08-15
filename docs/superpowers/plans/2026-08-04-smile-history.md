# 월간 미소 기록 화면 구현 계획

**Goal:** 기존 `SmileMoment`를 이용해 비평가적인 월간 기록 화면을 추가하고 홈의 최근 7일 카드에서 진입하게 한다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, Observation, XCTest

### Task 1: 월간 집계 API

- [x] `SmileMomentRepository.monthlyCounts(containing:calendar:)` 추가
- [x] 월 경계, 빈 날짜, 같은 날 여러 완료를 테스트

### Task 2: 기록 화면 상태

- [x] `SmileHistoryViewModel` 추가
- [x] 월간 합계·활동일·선택일과 이전/다음 달 이동 구현
- [x] 현재 달 이후 이동 제한과 선택 상태를 테스트

### Task 3: SwiftUI 화면과 진입

- [x] `SmileHistoryView`에 월 헤더, 요약, 7열 달력, 선택일 카드 구현
- [x] 홈의 최근 7일 카드를 버튼으로 바꾸고 기록 화면으로 push
- [x] 점수·연속 기록·얼굴 데이터가 없는 접근성 문구 확인

### Task 4: 문서와 검증

- [x] 현재 앱 사양 문서의 기록 화면 부재 설명을 2026-08-04 변경으로 갱신
- [x] `cd CoachingKit && swift test`
- [x] `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`
