# 미소 습관 전환 기기 검증

- 날짜: 2026-07-27
- 브랜치: `smile-habit-reframe`
- 기준 커밋: `fd7e044` (전환 작업 시작 시점)
- 대상 계획: `docs/superpowers/plans/2026-07-27-smile-habit-reframe.md`

> 얼굴 이미지·영상·원시 얼굴 수치는 이 저장소에 기록하지 않는다. 아래 표에는 PASS/FAIL만 남긴다.

## 1. 자동 검증 (완료)

| 항목 | 명령 | 결과 |
|---|---|---|
| CoachingKit 전체 테스트 | `cd CoachingKit && swift test` | PASS — `Test Suite 'All tests' passed`, 234 tests / 0 failures |
| 앱 타깃 빌드 | `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build` | PASS — `** BUILD SUCCEEDED **` |
| 공백/줄바꿈 오류 | `git diff --check` | PASS — 출력 없음 |
| 앱 타깃의 점수 API 사용 | `rg -n 'InsightEngine\|ScoreCalculator' SmileDay --glob '*.swift'` | PASS — 0건 |
| 제거된 점수 상태 | `rg -n 'weeklyAverageScore\|todayScore\|yesterdayScore\|bucketScores' SmileDay CoachingKit --glob '*.swift'` | PASS — 0건 |

기준선(전환 전) 테스트 수는 160건이었고, 전환 후 234건이다.

## 2. 미해결 선행 위험

`2026-07-27-project-hardening.md`를 이 작업보다 먼저 완료하지 못했다. 아래 P0 항목은 이 전환과 무관하게 그대로 남아 있다.

| 위치 | 내용 |
|---|---|
| `SmileDay/SmileDayApp.swift:19` | `try! ModelContainer(...)` — SwiftData 컨테이너 생성 실패 시 강제 종료 |
| `SmileDay/Services/CameraPreviewView.swift:15` | `fatalError("Metal을 사용할 수 없는 기기입니다")` |
| `SmileDay/Services/CameraPreviewView.swift:27` | `fatalError("init(coder:) is not supported")` |

## 3. TrueDepth 실기기 검증 (미실시)

시뮬레이터에서는 `ARFaceTrackingConfiguration`이 동작하지 않아 아래 항목은 TrueDepth 기기에서 직접 확인해야 한다.

- 기기 / iOS 버전:
- 빌드 / 커밋:
- 검증 일시:

| # | 항목 | 결과 |
|---|---|---|
| 1 | 일반 진입 (홈 → 미소 시간) | |
| 2 | 알림 딥링크 진입 | |
| 3 | 상단에 질문 표시 | |
| 4 | 얼굴 감지 전 "얼굴을 가이드 안에 맞춰주세요" 표시 | |
| 5 | 얼굴 감지 후 "편하게 숨을 쉬고 살짝 미소 지어보세요"로 전환 | |
| 6 | "오늘의 미소 남기기"로 완료 | |
| 7 | 기분만 선택하고 저장 | |
| 8 | 메모만 입력하고 저장 | |
| 9 | 기분·메모 모두 비우고 저장 | |
| 10 | 200자 경계 입력 (201자째부터 입력 차단) | |
| 11 | 완료 직후 홈 즉시 갱신 | |
| 12 | 기록 화면에 회고 표시 | |
| 13 | 백그라운드 → 포그라운드 복귀 | |
| 14 | 앱 재실행 후 데이터 유지 | |
| 15 | 화면 어디에도 점수·전날 대비 상승 미노출 | |

## 4. 스키마 호환 확인 (미실시)

기존 데이터가 있는 상태에서 앱을 업데이트해 확인한다.

| # | 항목 | 결과 |
|---|---|---|
| 1 | 기존 데이터가 있는 앱 업데이트 후 정상 실행 | |
| 2 | 과거 체크인이 활동 캘린더에 표시 | |
| 3 | 과거 레코드의 mood/note nil 안전 | |
| 4 | 기존 `CareSession` 기록 삭제 없음 | |
| 5 | 과거 즐겨찾기 ID가 새 카탈로그에 없어도 크래시 없음 | |
| 6 | 새 회고 저장 후 재실행 시 유지 | |

`CheckInSession`에 추가한 `promptText`, `smileMomentNote`는 모두 optional + 기본값 nil이라 경량 마이그레이션 대상이다. 단위 테스트에서 회고 필드가 없는 레코드의 조회·집계를 검증했지만, 실제 저장소 파일 마이그레이션은 기기 확인이 필요하다.
