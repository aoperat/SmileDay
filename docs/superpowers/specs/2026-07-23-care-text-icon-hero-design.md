# 케어 실행 화면 - 아이콘+타이머 링 히어로 설계안

## 배경
`CarePlayerView`는 루틴별 영상(`videoFileName`)이 있으면 재생하고, 없으면 "영상 준비 중" 텍스트 플레이스홀더를 보여준다. 그런데 `SmileDay/Resources/care_*.mp4` 5개는 실제 촬영 영상이 아니라 720p·3초짜리 더미 파일이라, 파일이 존재한다는 이유만으로 계속 이 더미 영상이 재생되고 플레이스홀더는 노출되지 않는다.

실제 영상이 준비되기 전까지 텍스트/아이콘 기반의 히어로 영역을 정식 경험으로 삼기로 했다. 영상이 준비되면 같은 파일명으로 mp4를 다시 넣기만 하면 기존 로직 그대로 영상이 재생되므로, 이번 변경은 "영상 없을 때"의 화면만 다룬다.

## 요구사항
- `CarePlayerView`의 영상 영역(현재 else 분기: "영상 준비 중" 플레이스홀더)을 아이콘 + 타이머 링 히어로로 교체.
- 히어로는 현재 스텝의 진행 상태를 실시간으로 보여준다: 남은 시간만큼 비워지는(카운트다운) 원형 링, 링 안의 스텝별 아이콘(SF Symbol), 링 아래 스텝 제목과 반복 횟수.
- 배경은 `routine.category.thumbnailGradient`를 사용해 루틴 목록의 썸네일과 톤을 맞춘다.
- 스텝별로 서로 다른 SF Symbol 아이콘을 명시적으로 지정한다 (텍스트 매칭이 아니라 데이터 필드로).
- 실제 영상이 준비된 루틴은 기존처럼 `VideoPlayer`로 재생되는 경로를 그대로 유지한다.
- 스텝 리스트(`StepRow`)는 변경하지 않는다.
- 더미 mp4 5개는 삭제한다.

## 설계

### 1. 데이터 모델
`CoachingKit/Sources/CoachingKit/CareRoutine.swift`의 `CareStep`에 `systemImage: String` 필드를 추가한다. 각 스텝 생성 시 아래 매핑에 따라 명시적으로 값을 지정한다:

| 동작 종류 | SF Symbol |
|---|---|
| 데우기 (손바닥 비비기) | `hands.and.sparkles.fill` |
| 입모양 (올리기 · 벌리기) | `mouth.fill` |
| 쓸어올리기 · 쓸어내기 · 쓸기 | `hand.draw.fill` |
| 원 그리기 | `arrow.triangle.2.circlepath` |
| 누르기 | `hand.point.down.fill` |
| 두드리기 | `hand.tap.fill` |
| 호흡 | `lungs.fill` |

5개 루틴 총 15개 스텝 각각에 위 표를 적용해 `systemImage` 인자를 채운다 (자세한 매핑은 구현 계획에서 스텝별로 명시).

### 2. UI (`CarePlayerView`)
- `videoArea`의 `else` 분기를 새 `StepHeroView`로 교체한다.
  - 배경: `routine.category.thumbnailGradient`, 높이 210 (기존 `videoArea`와 동일한 프레임 크기 유지).
  - 중앙: `Circle().trim(from: 0, to: progress)` 형태의 카운트다운 링(굵기 6pt, 흰색 계열) — `progress`는 `remainingSeconds / (step.seconds * step.reps)`로 계산해 시간이 지날수록 링이 비워진다.
  - 링 안쪽: 현재 스텝의 `systemImage` 아이콘 (약 40pt, 흰색).
  - 링 아래: 스텝 제목(볼드, 흰색) + `step.reps > 1`이면 "×n" 텍스트.
- `if let player { VideoPlayer(...) }` 분기는 변경하지 않는다 — 실제 영상이 번들에 들어오면 그대로 재생된다.
- 아래 진행 바, 단계 카운터, `StepRow` 리스트는 변경하지 않는다.

### 3. 리소스
- `SmileDay/Resources/care_relax_brow.mp4`, `care_lift_smile.mp4`, `care_depuff_morning.mp4`, `care_lift_cheek.mp4`, `care_morning_1min.mp4` 5개 파일을 삭제한다.

### 4. 테스트
- `CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift` 신규 추가: `CareRoutine.catalog`의 모든 스텝이 빈 문자열이 아닌 `systemImage`를 갖는지 검증하는 sanity 테스트.

## 범위 밖
- 스텝 리스트(`StepRow`)나 진행 바, 추천 카드 등 히어로 영역 외 다른 UI 변경
- 실제 영상 촬영/추가
- 카테고리별 썸네일 그라디언트 자체의 변경
