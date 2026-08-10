# 스마일데이 앱 전체 사양 명세

- 작성일: 2026-08-03
- 대상: `feature/live-smile-monitor` 브랜치 (최신 커밋 `59a08d9`)
- 범위: 앱이 실제로 그리는 모든 화면, 저장하는 모든 데이터, 알림·카메라 동작
- 검증: `swift test` 259개 통과 (`Test Suite 'All tests' passed`, 0 failures)

> **2026-08-04 변경:** 월간 기록 화면을 추가했다. 홈의 최근 7일 카드에서 진입하며 월별 날짜별 횟수, 월간 합계, 웃어본 날 수와 선택일 횟수를 보여준다. 점수·연속 기록·얼굴 데이터는 표시하지 않는다. 변경 후 `swift test` 285개와 iOS simulator 빌드가 통과했다.

> **2026-08-05 변경:** 첫 App Store 등록 전에 브랜드와 앱 식별자를 맞추기 위해 번들 ID를 `dvelo.smileDay`에서 `dolparo.smileDay`로 변경했다.

---

## 0. 먼저 답: 월간 기록 페이지가 있다

**있다.** 홈의 최근 7일 카드를 누르면 월간 기록 화면으로 이동한다.

기록을 보여주는 지점은 홈 화면의 카드 두 개가 전부다.

| 지점 | 보여주는 값 | 형태 |
|---|---|---|
| 홈 · 오늘 카드 | 오늘 완료 횟수 | 숫자 1개 (`3번`) |
| 홈 · 최근 7일 카드 | 7일치 일별 횟수 + 합계 | 점 7개 + 각 점 아래 숫자 |
| 기록 화면 | 월별 날짜별 횟수, 월간 합계, 활동일, 선택일 횟수 | 7열 달력 + 요약 카드 |

기록 화면은 기존 `SmileMoment`를 월 단위로 집계하며 새 저장 모델을 만들지 않는다. 다음 값은 의도적으로 화면에 표시하지 않는다.

- 완료 시각(시·분)
- 완료 경로(`manual` / `notification` / `notification-action`)
- `guideID`
- 연속 기록, 목표 달성률, 전월 대비

---

## 1. 제품 정의

평소 잘 웃지 않는 사람이 하루 몇 번 잠깐 웃도록 돕는 한국어 iOS 앱. 서버가 없고 모든 데이터는 기기에만 있다.

핵심 루프 — 기록을 남기는 유일한 경로:

```
반복 알림 → 비평가적 문구 → 약 5초 미소 → 완료 저장 → 오늘·최근 7일 횟수
```

이 루프는 카메라를 쓰지 않는다. 온보딩에도 카메라가 없고, 미소를 완료하는 데 카메라가 필요한 순간이 없다.

부가 모드 하나: **실시간 미소 확인**. 홈의 보조 카드에서만 진입하며, 완료 횟수에 더해지지 않는다.

---

## 2. 화면 인벤토리

독립 화면 9개, 인라인 상태 뷰 2개. 탭 바가 없고 홈이 유일한 허브다.

| # | 화면 | 파일 | 진입 | 표시 방식 |
|---|---|---|---|---|
| 1 | 스플래시 | `Views/Splash/SplashView.swift` | 앱 실행 | 1.3초 고정 |
| 2 | 시작 실패 | `Views/AppStartupFailureView.swift` | SwiftData 컨테이너 오픈 실패 | 전체 화면 |
| 3 | 온보딩 (3단계) | `Views/Onboarding/SmileMVPOnboardingView.swift` | 최초 실행 | 전체 화면 |
| 4 | **홈** | `Views/Home/SmileMVPHomeView.swift` | 온보딩 완료 후 | `NavigationStack` 루트 |
| 5 | 미소 가이드 | `Views/Coaching/SmileGuideView.swift` | 홈 CTA · 알림 탭 | `fullScreenCover` |
| 6 | 실시간 미소 확인 | `Views/Coaching/LiveSmileMonitorView.swift` | 홈 보조 카드 | `fullScreenCover` |
| 6-1 | └ 세션 요약 | `Views/Coaching/LiveSmileSessionSummaryView.swift` | 종료 버튼 | 6번 내부 상태 |
| 7 | 기록 | `Views/Home/SmileHistoryView.swift` | 홈 최근 7일 카드 | `navigationDestination` (push) |
| 8 | 설정 | `Views/Settings/SmileMVPSettingsView.swift` | 홈 툴바 기어 | `navigationDestination` (push) |
| 9 | 메시지 관리 | `Views/Settings/ReminderMessageManagementView.swift` | 설정 → 알림 문구 | push |
| 9-1 | └ 메시지 편집기 | 같은 파일 (`ReminderMessageEditor`) | 항목 탭 / + 버튼 | `sheet` (`.medium`) |
| — | 데이터 로드 실패 카드 | `AppStartupFailureView.swift` (`AppDataLoadFailureView`) | 조회 실패 시 | 루트·홈·설정에 인라인 |
| — | 카메라 프리뷰 | `Views/Coaching/LiveSmileCameraPreview.swift` | 6번에서 토글 ON | `ARSCNView` 임베드 |

### 2.1 내비게이션 그래프

```
앱 실행
 └ SplashView (1.3s)
    ├ [컨테이너 실패] AppStartupFailureView (막다른 길, 복구 안내만)
    ├ [온보딩 미완료 또는 반복 스케줄 없음] 온보딩 3단계
    │    목적 → 알림 이유 → 시간 설정 ─(완료/건너뛰기)→ 홈
    └ [완료] SmileMVPHomeView
         ├ "지금 한 번 웃기" ──────→ SmileGuideView (fullScreenCover)
         ├ 실시간 미소 확인 카드 ──→ LiveSmileMonitorView (fullScreenCover)
         │                              └ 종료 → LiveSmileSessionSummaryView → 닫기
         ├ 다음 알림 카드 (문제 상태일 때만 탭 가능)
         │    ├ 권한 거부 → iOS 설정 앱
         │    └ 그 외 → 설정 화면
         ├ 최근 7일 카드 ─────────→ 기록 (push)
         └ 툴바 기어 ─────────────→ 설정 (push)
                                      └ 알림 문구 → 메시지 관리 (push)
                                                       └ 항목/+ → 편집기 (sheet)

알림 탭 / "가이드 열기" → AppDelegate → NotificationRouter → 홈이 SmileGuideView 오픈
알림 "웃었어요" → 앱 열지 않고 백그라운드에서 SmileMoment 저장
```

**진입 분기 조건** (`RootView.loadRootState`): `hasCompletedOnboarding`(UserDefaults) **AND** `SmileReminderSchedule` 레코드 존재. 개별 알림 시절 사용자는 스케줄이 없으므로 온보딩의 시간 설정 단계를 다시 본다.

---

## 3. 화면별 상세 명세

### 3.1 스플래시

- 배경: 주조색 그라디언트(살구→노랑), 위에 `SmileArc` 곡선 + "스마일데이" + "웃으면 좋잖아요"
- 글자색은 `ink`. 노랑 위 흰 글자는 대비 1.7:1이라 쓰지 않는다.
- 표시 시간 1.3초 고정. 그동안 온보딩 상태 조회와 `ReminderActionBackfill`이 돈다.

### 3.2 온보딩 (3단계)

| 단계 | 아이콘 | 제목 | 액션 |
|---|---|---|---|
| 1 목적 | `face.smiling` | 스마일데이 | "다음" |
| 2 알림 이유 | `bell.badge` | 잊지 않도록 알려드릴게요 | "시간 정하기" |
| 3 시간 설정 | — | 미소 알림 | "이 시간으로 시작하기" / "알림 없이 시작하기" |

- 1단계에서 명시 약속: "표정을 찍거나 점수를 매기지 않아요. 웃어본 횟수만 이 기기에 기록해요."
- 3단계 컨트롤(`ReminderPatternControls`): 시작 시간 · 종료 시간 `DatePicker`, 반복 주기 `Picker`, "하루 N번 알려드려요" 요약
- 온보딩에서는 **저장 버튼을 누르기 전까지 아무것도 예약하지 않는다** (`appliesChangesImmediately: false`). 시간을 고르는 중에 권한 대화상자가 뜨지 않게 하려는 의도.
- "알림 없이 시작하기"는 `alert`로 한 번 더 확인한다. `confirmationDialog`가 아닌 이유는 `.cancel` 역할 버튼 문구가 시스템에 덮여 "알림 받을래요" 선택지가 사라지기 때문.
- 권한 거부 시 별도 alert로 "iOS는 한 번만 물어본다"는 사실과 설정 앱 경로를 안내하고, 막지 않고 진행시킨다.
- 접근성 큰 글씨에서 문구가 잘리지 않도록 `GeometryReader` + `ScrollView` + `minHeight` 구조.

### 3.3 홈 (`SmileMVPHomeView`)

카드 4개를 세로로 쌓는다. 순서 = 우선순위.

**① 오늘 카드**
- "오늘 미소" / `N번` (40pt bold rounded monospacedDigit) / 부제
- 부제: 0회면 "아직 오늘의 미소가 없어요", 그 외 "오늘 웃어본 순간이 하나씩 쌓이고 있어요."
- 주 CTA "지금 한 번 웃기" → `SmileGuideView`
- 접근성 라벨 통합: "오늘 미소 N번"

**② 실시간 미소 확인 카드 (보조)**
- 아이콘 `waveform` + 제목 + 요약 + `chevron.right`
- 주 CTA보다 시각적으로 약하게 둔다. TrueDepth 미지원 기기에서도 카드는 그대로 보이고, 지원 여부는 들어가서 안내한다.

**③ 다음 알림 카드**
- `ReminderDeliveryState` 4상태로 분기. 예약된 일정만 보고 시각을 적지 않고 **권한까지 확인한 결과만** 그린다.

| 상태 | 조건 | 표시 | 탭 동작 |
|---|---|---|---|
| `scheduled` | 스케줄 ON + 권한 허용 + 다음 시각 계산됨 | "다음 알림" + `HH:mm` | 없음 |
| `blockedByPermission` | 스케줄 ON + 권한 거부 | "알림이 오지 않아요" + 사유 | iOS 설정 앱 |
| `permissionNotRequested` | 스케줄 ON + 미결정 | "알림을 켜면 잊지 않아요" | 앱 설정 화면 |
| `off` | 스케줄 OFF 또는 시각 계산 불가 | "알림이 꺼져 있어요" | 앱 설정 화면 |

문제 상태에서는 카드 전체가 버튼이 된다.

**④ 최근 7일 카드**
- 오늘로 끝나는 7일. 기록 없는 날도 `count: 0`으로 포함.
- 점 하나 = 하루. 웃은 날은 그라디언트 채움 + `sunDeep` 테두리, 안 웃은 날은 `shell` 단색 + 테두리 없음. (노랑은 흰 카드 위에서 1.5:1이라 채움만으로 형태가 안 읽혀 테두리로 윤곽을 만든다.)
- 점 아래 횟수(0이면 `·`), 그 아래 요일 한 글자
- 우상단 "총 N번"

**갱신 시점** — 놓치기 쉬운 경로까지 모두 연결돼 있다:
`onAppear` / `scenePhase == .active` / 설정 화면에서 돌아왔을 때(push는 scenePhase가 안 바뀜) / 가이드 커버가 닫힐 때 / `notificationRouter.recordedWithoutGuideCount` 변화(앱이 떠 있는 채로 배너 버튼을 눌렀을 때).

### 3.4 미소 가이드 (`SmileGuideView`)

카메라를 켜지 않고 권한도 묻지 않는다.

- 상태 3개: `ready` → `running(remainingSeconds:)` → `completed`
- 화면을 열자마자 세지 않는다. "시작"을 눌러야 카운트다운 시작.
- 길이 **5초** (`SmileGuideCatalog.defaultDurationSeconds`)
- 문구: `SmileCueCatalog`의 8개 중 하나를 순환 선택 (`smileCueNextIndex` UserDefaults 커서)
- 그래픽: 코드로 그린 `SmileFaceGraphic` (사용자 얼굴 아님). 시작 시 입꼬리 곡선이 올라간다.
- 완료 시: "오늘 한 번 더 웃어봤어요" + `UIImpactFeedbackGenerator(.soft)`
- 중간에 닫으면 기록하지 않는다 (`cancel()`이 `runToken` 증가로 지연 완료 차단)
- **저장 실패 시**: 실패 문구 + "다시 시도" 버튼. 재시도는 5초를 다시 세지 않고 **처음 완료 시각**으로 저장한다 (자정을 넘겨 눌러도 웃은 날이 바뀌지 않게).
- Reduce Motion에서 숫자 전환·얼굴 애니메이션 생략

### 3.5 실시간 미소 확인 (`LiveSmileMonitorView`)

내부 상태 6개를 한 화면에서 분기한다: `intro` → (권한 안내) → `measuring` → `summary`, 그리고 `restart`(중단), `failure`(실패).

**시작 전 안내 (5줄, `liveMonitorIntroPoints`)**
1. 전면 카메라가 켜지고 iOS 초록 표시가 나타난다
2. 카메라 화면은 기본 OFF, 버튼으로 켜고 끈다
3. 끝나면 그래프를 보여주고 얼굴 사진은 남기지 않는다
4. 그래프는 화면을 닫으면 사라진다
5. 배터리가 평소보다 빨리 준다

**권한 흐름** (`LiveSmileStartDecision`) — 세션을 켜기 **전에** 권한을 끝낸다. 세션이 돌 때 권한 대화상자가 뜨면 앱이 inactive가 되고 화면이 이를 "카메라 쓰다 이탈"로 읽어 세션을 멈추는 문제가 있었다.

| 상태 | 동작 |
|---|---|
| 허용됨 | 바로 측정 시작 |
| 미결정 | `AVCaptureDevice.requestAccess` → 허용 시 측정, 거부 시 안내 |
| 거부됨 | 안내 화면 + "카메라 허용 설정하기" (iOS 설정 앱) |
| 미지원 기기 | 측정 시작 → `unsupportedDevice` 실패 화면. 권한은 묻지 않는다 |

**측정 화면 구성 (위→아래)**
1. 프라이버시 배지 — "카메라 사용 중 · 영상과 측정값은 저장하지 않아요" (항상 표시)
2. 카메라 화면 토글 (기본 OFF, 매 세션 OFF로 시작)
3. 프리뷰 (ON일 때만, 240pt, 좌우 반전 없음, 얼굴 메시/3D 오버레이 없음)
4. **단계 표시** — 4칸 막대. 숫자를 보여주지 않는다. 색은 노랑→살구 (성공/실패의 초록·빨강이 아님)
5. 타임라인 띠 (12pt)
6. 상태 문구 또는 "Smile!" 넛지 표시
7. "이 표시는 웃음의 좋고 나쁨이 아니라…" 고정 안내
8. "다시 보정" / "종료"

**측정 파라미터**

| 항목 | 값 | 위치 |
|---|---|---|
| 보정 시간 | 2초 | `LiveSmileMonitorViewModel.calibrationDuration` |
| 지수 이동 평균 계수 | 0.2 | `smoothingAlpha` |
| 화면 갱신 상한 | 초당 10회 | `minimumPublishInterval = 0.1` |
| 단계 히스테리시스 | 0.03 | `levelHysteresis` |
| 신호 표시 스팬 | 0.45 | `LiveSmileSignalEvaluator.displaySpan` |
| 시선 허용 각도 | ±40° | `gazeToleranceDegrees` |
| 어두움 임계 | 300 lux | `darkAmbientIntensity` |
| 타임라인 칸 | 1초 | `LiveSmileSessionRecorder.bucketDuration` |
| 넛지 프레임 간격 상한 | 1초 | `maxNudgeFrameGap` |

**단계 경계** (`LiveSmileLevel`) — 아래쪽을 좁게 둬서 첫 변화를 바로 알아차리게 하고, 위로 갈수록 넓게 둬서 더 크게 웃으라고 밀지 않는다.

| 단계 | 하한 | 문구 |
|---|---|---|
| `resting` | 0 | 편하게 있다가 천천히 미소 지어보세요 |
| `starting` | 0.10 | 미소 신호가 올라오고 있어요 |
| `holding` | 0.30 | 미소가 이어지고 있어요 |
| `clear` | 0.60 | 미소 신호가 또렷하게 잡혀요 |

**신호 정의**: `(좌 입꼬리 + 우 입꼬리) / 2`를 세션 시작 시 편한 표정 평균과 비교해 올라온 만큼을 0~1로 정규화. 편한 표정보다 낮으면 0 — **음수 신호나 "찡그림 점수"를 만들지 않는다.** 좌우 비대칭은 감점이 아니라 그냥 평균에 들어간다. 미간·눈가·턱, 감정 추론 값은 읽지 않는다.

**품질 문제 우선순위**: 자세(카메라를 보는가) → 조명 → 단계. 흔들린 신호에 단계를 붙이면 사용자가 자기 표정을 탓하게 되므로 원인을 먼저 말한다. 품질 문제 중에는 `level`을 `nil`로 지워 마지막 단계가 현재 표정으로 오독되지 않게 한다.

**세션 요약**
- 헤드라인: 측정 시간 (`N분 M초`)
- 큰 숫자: **"얼굴이 보인 동안 미소" 비율** — 분모가 카메라를 켠 시간이 아니라 판정 가능했던 시간
- 그 아래 "알 수 없음 N%" 항상 병기 (분모가 달라 한 막대에 쌓지 않음)
- 1초 칸 타임라인 띠(34pt) + 범례 3개 (미소 / 안 웃음 / 알 수 없음)
- 신뢰도 3상태 (상호배타): `noMeasurement` / `low` / `reliable`
  - 신뢰 조건: 판정 가능 시간 ≥ 60초 **AND** unknown 비율 ≤ 50%
  - 미달 시 "인식된 시간이 짧아 이 숫자는 참고만 해주세요"
- 하단 고정: "이 비율은 웃음의 좋고 나쁨이 아니라, 카메라가 입꼬리 움직임을 감지한 시간의 비율이에요."

**1초 칸 판정 규칙** (`LiveSmileSessionRecorder`)
- 프레임의 절반 미만만 판정 가능하면 그 1초는 `unknown`
- 동수는 `notSmiling` — 적게 세는 쪽으로 기운다
- 프레임이 오지 않은 칸은 `unknown`으로 채운다. `unknown`은 "안 웃었다"가 아니라 "알 수 없다"
- 타이머를 쓰지 않고 프레임 도착 시각으로 칸을 계산한다. 시계가 거꾸로 가도 이미 닫힌 칸을 되돌리지 않는다
- 종료 시 마지막 부분 칸과 마지막 프레임 이후 시간까지 채운다 (끝머리를 빼면 unknown 분모가 줄어 세션이 실제보다 믿을 만해 보인다)

**띠 렌더링**: `Canvas` 1개로 그린다. 칸마다 뷰를 만들면 1시간 세션에서 3,600개가 된다. 픽셀 열 단위로 접되 **미소 우선**으로 칠한다 — 342pt 띠의 1시간 세션에서 칸 하나는 0.095pt라 혼자 웃은 1초가 사라진다. 숫자 비율은 초 단위 그대로 계산하므로 이 우선순위가 비율을 부풀리지 않는다.

**생명주기**
- 측정 중에만 `isIdleTimerDisabled = true` (세워두고 보는 화면), 모든 종료 경로에서 원복
- 백그라운드 진입 시 즉시 카메라 OFF, 자동 재개하지 않음
- 측정한 게 있으면 실패·중단·닫기 어느 경로든 **말없이 버리지 않고 요약을 먼저 보여준다**

### 3.6 설정 (`SmileMVPSettingsView`)

`List` 5개 섹션. **저장 버튼이 없다** — 바꾸면 즉시 적용(`appliesChangesImmediately: true`), 500ms 디바운스 후 1회 저장.

| 섹션 | 내용 |
|---|---|
| 권한 안내 | 권한 거부 시에만 표시. 안내 문구 + 설정 앱 열기 |
| 반복 설정 | 미소 알림 토글, 시작/종료 시간, 반복 주기, "하루 N번" 요약, 검증 문구 |
| 알림 문구 | "메시지 관리" 링크 + 현재 개수 |
| 실시간 확인 알림 | 웃지 않으면 알리기 토글, 알림 간격, 진동 토글 |
| 데이터 저장 위치 | 기기 저장 / 미전송 / 앱 삭제 시 함께 삭제 (읽기 전용 3줄) |

- **알림 끄기는 alert로 한 번 확인**한다 (앱의 유일한 흐름을 멈추는 일이라). 켜기는 되돌리기 쉬우니 즉시 반영.
- 취소하면 토글이 저절로 제자리로 돌아온다 — 바인딩이 `viewModel.isEnabled`를 읽기 때문.
- 푸터가 저장 상태를 말한다: "저장 중…" ↔ "바꾸면 바로 적용돼요. 놓친 알림은 다시 울리거나 한꺼번에 보내지 않아요."
- 넛지 설정은 디바운스 없이 즉시 UserDefaults에 쓴다.

### 3.7 메시지 관리 (`ReminderMessageManagementView`)

- 목록: 탭하면 수정, 스와이프 삭제, `EditButton`으로 순서 변경
- 상단 `+` 로 추가
- 편집기: `sheet` + `.medium` detent, `TextEditor`, 실시간 글자 수 `N/100`
- 검증 규칙: 공백만 불가 / 100자 이하 / 중복 텍스트 불가 / **최소 1개는 남겨야 함**
- 알림 예약 시 시간 순서대로 순환 사용 (`messages[index % count]`)

---

## 4. 데이터 명세

### 4.1 저장되는 것

**SwiftData — 활성 모델**

| 모델 | 필드 | 의미 |
|---|---|---|
| `SmileMoment` | `date: Date` | 완료 시각 |
| | `guideID: String` | 완료 당시 가이드 ID (`anytime-soft` 고정) |
| | `sourceRawValue: String` | `manual` / `notification` / `notification-action` |
| `SmileReminderSchedule` | `startHour/Minute`, `endHour/Minute` | 활동 시간창 |
| | `intervalMinutes` | 60/120/180/240 중 하나 |
| | `isEnabled` | 알림 ON/OFF |
| | `notificationGroupID` | 예약 그룹 UUID |
| | `updatedAt` | 마지막 저장 시각 |

**SwiftData — 호환 전용 (UI가 절대 읽지 않음)**
`Baseline`, `CheckInSession`, `CareSession`, `ReminderSetting`, `CustomSmileCard`.
기존 사용자의 저장소가 열리도록 남겨둔 것이다. 삭제하거나 저장 속성을 바꾸려면 버전 마이그레이션 설계가 필요하다. 앱 타깃 코드에서의 참조는 0건 — `PersistenceSchema.models` 등록이 전부다.

**UserDefaults**

| 키 | 값 |
|---|---|
| `hasCompletedSmileOnboarding` | Bool |
| `smileCueNextIndex` | Int (문구 순환 커서) |
| `reminderMessages.v1` | JSON `[ReminderMessage]` |
| `liveSmileNudgeEnabled` | Bool (기본 true) |
| `liveSmileNudgeIntervalSeconds` | Int (기본 60, 허용 30/60/90/120/180) |
| `liveSmileNudgeHapticEnabled` | Bool (기본 true) |
| `hasBackfilledReminderActions` | Bool (알림 버튼 백필 1회 실행 표식) |

**파일시스템**: `tmp/reminder-thumbnails/` 에 알림 첨부용 PNG 사본. 예약할 때마다 통째로 비우고 다시 만든다. (`UNNotificationAttachment`가 파일을 시스템 저장소로 **옮기기** 때문에 알림마다 사본이 필요하다.)

### 4.2 저장되지 않는 것 — 절대 조항

실시간 미소 확인이 만드는 값은 **어디에도 남지 않는다**. SwiftData·UserDefaults·파일시스템·네트워크 전부.

- 프레임 이미지: `ARFrame.capturedImage`를 읽는 코드 경로 자체가 없다 — 저장할 대상이 애초에 생기지 않는다
- blend shape 원값, 신호값, 단계, 보정 기준값: 메모리에서만 산다
- 세션 타임라인·비율·세션 시간: 요약 화면을 닫으면 사라진다
- 캡처·내보내기·공유 경로 없음
- 실시간 확인 실행은 **완료 횟수에 더해지지 않는다** — 웃기를 완료한 것과 다른 행동이다

> 2026-07-31에 분 단위 스냅샷 격자를 의도적으로 제거했다. 자기 얼굴이 격자로 늘어서면 사용자가 스스로를 판정하게 되고, 그건 이 앱이 거부하는 일이다. 타임라인이 "언제"에 이미 답한다. **사진을 다시 넣지 말 것.**

### 4.3 월간 기록 화면

- `SmileMomentRepository.monthlyCounts`가 월의 모든 날짜를 0회 날짜까지 채워 반환한다.
- `SmileHistoryViewModel`이 월간 합계, 한 번 이상 웃어본 날 수와 선택일 횟수를 만든다.
- 활동일은 같은 주조색으로 표시하며 횟수에 따른 색 강약이나 등급을 사용하지 않는다.
- 이전 달은 이동할 수 있고 다음 달은 현재 달까지만 허용한다.
- 완료 시각, 완료 경로, 가이드 ID는 저장 호환과 내부 판단을 위해 남지만 사용자 화면에는 표시하지 않는다.
- 사용자가 개별 기록을 삭제하거나 내보내는 기능은 아직 없다. 앱 삭제가 전체 로컬 기록을 지우는 유일한 수단이다.

---

## 5. 알림 명세

### 5.1 예약 방식

- `UNCalendarNotificationTrigger(repeats: true)` — 시각마다 **매일 반복** 트리거 1개
- 식별자: `{groupID}-daily-{HHmm}`
- 발생 시각: `startTime`부터 `intervalMinutes` 간격으로 `endTime` **이하**까지
- 예: 09:00~21:00 / 180분 → 09, 12, 15, 18, 21시 = 하루 5번
- 주기 선택지: 1/2/3/4시간. 권장 기본값 09:00~21:00 · 3시간
- 내용: 제목 "스마일데이", 본문은 사용자 메시지 순환, 사운드 기본, 첨부는 앱 아이콘 아트워크

**교체 순서** — 알림을 잃지 않는 것이 최우선:
1. 새 그룹 전체 등록 → 2. 스케줄 저장 → 3. 이전 그룹 취소 → 4. 레거시 개별 알림 취소

등록이 중간에 실패하면 이미 추가한 것을 되감고 **기존 알림과 저장값은 그대로 둔다**. 저장이 실패하면 새 그룹을 취소한다.

### 5.2 알림 액션 (길게 눌러서 표시)

| 액션 | 식별자 | 동작 |
|---|---|---|
| 가이드 열기 | `open-guide` | 앱을 앞으로 가져와 `SmileGuideView` 오픈 (본문 탭과 동일) |
| 웃었어요 | `smile-recorded` | **앱을 열지 않고** `SmileMoment(.notificationAction)` 저장 |

"웃었어요"는 iOS가 앱을 백그라운드로만 깨우므로 `WindowGroup` body가 만들어지지 않는다. 그래서 뷰 계층의 컨테이너가 아니라 `PersistenceController.shared`로 SwiftData에 닿는다.

**확인 피드백이 없는 것은 의도**다. `UIFeedbackGenerator`는 foreground-active가 아니면 문서화된 no-op이라 진동을 줄 수 없다. 알림이 사라지는 것 자체가 iOS가 주는 유일한 피드백이며, 미리 알림 앱의 "완료로 표시"와 같은 동작이다.

### 5.3 하위 호환 계약 (변경 금지)

| 값 | 이유 |
|---|---|
| `SmileGuideCatalog.default.id = "anytime-soft"` | 저장된 `SmileMoment.guideID`와 예약된 알림 payload에 들어 있음 |
| `ReminderNotificationCategory.identifier = "smile-reminder"` | 예약된 알림이 이 문자열을 담고 있음 |
| `ReminderNotificationAction` raw values | 위와 같음 — 바꾸면 눌린 버튼을 해석할 수 없음 |
| payload key `reminderID` / `guideID` | 위와 같음 |
| payload 레거시 파싱 `bucket` / `promptText` | 가이드 이전 버전 알림이 아직 예약돼 있을 수 있음 |
| `cancel(id:)`의 `{id}-{0..13}` 형식 | 옛 롤링 윈도우 알림을 지우려면 같은 규칙으로 식별자를 만들어야 함 |

`ReminderActionBackfill`은 알림 버튼이 생기기 전에 예약한 사용자를 위해 실행마다 1회 시도한다 — 새 그룹을 완전히 등록한 뒤 기존 그룹을 교체하며, 실패해도 화면을 막지 않고 다음 실행에서 재시도한다.

### 5.4 실시간 확인 중 넛지 알림

- 별개 알림 (`live-smile-nudge`, 식별자 재사용으로 배너가 쌓이지 않음)
- 설정한 시간만큼 `resting` 단계가 이어지면 발화, 발화 후 0부터 다시 셈
- 얼굴이 안 보이는 동안은 시간을 세지 않는다 (프레임 간격 1초 초과면 누적 제외)
- 진동 + 알림 + 화면의 "Smile!" 3초 표시 (알림 권한이 없으면 진동만)
- `userInfo` 비움 — 탭해도 딥링크하지 않는다. 사용자는 이미 그 화면에 있다.

---

## 6. 디자인 · 접근성 사양

### 6.1 팔레트 (Morning Glow)

| 토큰 | HEX | 용도 |
|---|---|---|
| `sun` | `#FFC93C` | 주조색 |
| `apricot` | `#FFA94D` | 그라디언트 끝, 미소 구간 |
| `sunDeep` | `#9A5B00` | 강조 텍스트, 아이콘, 테두리 (흰 배경 5.4:1) |
| `cream` | `#FFF6EE` | 배경 |
| `ink` | `#46323C` | 본문 (노랑 위 7.7:1) |
| `muted` | `#7E6A74` | 보조 텍스트 |
| `shell` | `#F1E2D6` | 비활성·빈 상태 |
| `alert` | `#C8324C` | 오류 |

- **앱 전체를 `.preferredColorScheme(.light)`로 고정**한다. 밝은 전용 팔레트라 시스템 다크 모드의 흰 기본 글씨가 흰 카드·크림 배경에서 사라진다.
- 주조색 위 글자는 항상 `ink`. 흰 글자는 1.7:1이라 쓰지 않는다.
- 대비 회귀는 `SDPaletteTests`가 잡는다 (앱 타깃엔 테스트 번들이 없어 원시 값을 패키지에 둠).

### 6.2 접근성

- 큰 글씨 대응: 온보딩·가이드·요약·시작 실패 화면이 `ScrollView` + `minHeight` 구조. 잘리면 안 되는 것(카메라를 찍지 않는다는 약속, 저장 재시도 버튼, 복구 안내)이 잘리지 않게 한 조치.
- Reduce Motion: 카운트다운 숫자 전환, 얼굴 애니메이션, 단계 막대 보간, 프리뷰 페이드, 넛지 등장을 모두 생략.
- VoiceOver:
  - 카드 단위 `accessibilityElement(children: .combine)`
  - 단계 막대는 프레임마다 값을 읽지 않도록 `.ignore` + 고정 라벨/값 ("4단계 중 2단계")
  - 상태·단계가 **바뀔 때만** `AccessibilityNotification.Announcement` 발화
  - 요약의 띠·범례는 위 비율이 이미 말하므로 `accessibilityHidden`
  - 프리뷰는 `accessibilityHidden`
- 날짜·차트 축은 기기 로캘과 무관하게 `ko_KR` 고정.

### 6.3 카피 원칙

- 전부 한국어. 공용 문자열은 `Views/SharedStrings.swift`.
- 건강 표현 금지 (App Store 1.4.1): "리프팅", "젊어진다", "교정한다", "치료" 사용 안 함. 습관 인식 프레이밍만 사용.
- 랭킹·연속 기록 손실 표현 없음. 0회인 날은 실패가 아니라 중립.
- "점수"라고 부르는 유일한 숫자는 실시간 모드의 센서 신호이며, 저장되지도 세션 간 비교되지도 좋고 나쁨으로 규정되지도 않는다.

---

## 7. 아키텍처 · 플랫폼 사양

### 7.1 빌드 설정

| 항목 | 값 |
|---|---|
| 번들 ID | `dolparo.smileDay` |
| 버전 | 1.0 (빌드 1) |
| 최소 iOS | 17.0 |
| 기기 | iPhone 전용 (`TARGETED_DEVICE_FAMILY = 1`) |
| 방향 | 세로 고정 |
| Swift | 5.0 모드 |
| 권한 문구 | `NSCameraUsageDescription` 1개 (알림은 런타임 요청이라 plist 키 없음) |

### 7.2 레이어

**`CoachingKit/`** — 플랫폼 독립 로직 전부. SwiftData 모델, 리포지토리, `@Observable` 뷰모델, 값 타입. macOS도 타깃해서 시뮬레이터 없이 `swift test`가 돈다. **새 로직은 테스트와 함께 여기에 넣는다.**

**`SmileDay/`** — 앱 타깃. SwiftUI 뷰 + 플랫폼 서비스. CoachingKit 프로토콜 2개를 구현한다:
- `ReminderScheduling` ← `UserNotificationReminderScheduler`
- `LiveSmileMonitoring` ← `ARKitLiveSmileMonitor`

뷰가 뷰모델을 만들고 구체 서비스를 주입한다. 테스트는 가짜를 주입한다.

**컨테이너**: `PersistenceController.shared`가 `Result<ModelContainer, Error>`를 들고 있다. 뷰 밖에 있는 이유는 알림 액션이 백그라운드 실행에서 같은 저장소에 써야 하기 때문. 실패해도 크래시하지 않고 `AppStartupFailureView`로 안내한다 — 여기서 크래시하면 저장소를 못 여는 사용자가 앱을 아예 못 쓴다.

### 7.3 실패 처리 요약

| 실패 | 대응 |
|---|---|
| 컨테이너 오픈 실패 | `AppStartupFailureView` (복구 안내, 데이터 삭제 안 함) |
| 조회 실패 | `AppDataLoadFailureView` 인라인 + "다시 시도" |
| 완료 저장 실패 | 가이드에서 명시 + 원래 시각으로 재시도. 실패한 삽입은 롤백해 다음 save에 딸려 들어가지 않게 함 |
| 알림 등록 실패 | 기존 알림 유지 + "기존 알림은 그대로 유지했어요" |
| 알림 권한 거부 | 홈 카드 + 설정 섹션 + 온보딩 alert 3중 안내 |
| 카메라 권한 거부 | 측정 전 안내 화면 + 설정 앱 경로 |
| 미지원 기기 | 실시간 모드 진입 후 안내 (홈 카드는 그대로 노출) |
| AR 세션 실패·인터럽션 | 측정한 게 있으면 요약 먼저, 없으면 실패 화면 |
| 알림 액션 저장 실패 | 조용히 종료 (백그라운드라 알릴 수단이 없음) |

---

## 8. 검증 현황

- **CoachingKit 테스트 259개 전부 통과** (`swift test`, 0 failures, 0.95초)
  - 테스트 파일 26개. 실시간 모드 6개, 알림 6개, 리포지토리·뷰모델·패턴·팔레트 등
  - `swift test` 출력 마지막 줄 "0 tests in 0 suites passed"는 Swift Testing 러너 것이라 실패가 아니다. `Test Suite 'All tests' passed`를 확인해야 한다.
- **SwiftUI 뷰에는 자동화 테스트가 없다.** 뷰 계층 변경의 검증은 `xcodebuild` 성공이 전부다.
- lint 설정 없음.

---

## 9. 문서와 실제의 차이

작업 중 확인한 것들:

1. **`weekActiveDayCount`는 호출처 없는 죽은 API다.** 테스트 4개가 붙어 있어 살아 있는 것처럼 보인다.
2. 사용자가 개별 완료 기록을 삭제하거나 내보내는 기능은 없다.

---

## 부록: 사용자가 조정할 수 있는 값 전부

| 설정 | 범위 | 기본값 | 저장 위치 |
|---|---|---|---|
| 미소 알림 ON/OFF | Bool | ON | SwiftData |
| 시작 시간 | 00:00~23:59 | 09:00 | SwiftData |
| 종료 시간 | 시작 시간보다 늦어야 함 | 21:00 | SwiftData |
| 반복 주기 | 1/2/3/4시간 | 3시간 | SwiftData |
| 알림 문구 | 1~N개, 각 100자 이하 | 기본 8개 | UserDefaults |
| 넛지 ON/OFF | Bool | ON | UserDefaults |
| 넛지 간격 | 30/60/90/120/180초 | 60초 | UserDefaults |
| 넛지 진동 | Bool | ON | UserDefaults |
| 카메라 화면 표시 | Bool | OFF (매 세션 초기화) | 저장 안 함 |
