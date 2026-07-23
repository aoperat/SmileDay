# 데이터 수집 확장 설계

- 날짜: 2026-07-23
- 상태: 승인됨
- 배경: 향후 AI 기능(맞춤 루틴 추천, AI 리포트, 코칭 멘트 생성)의 재료가 될 데이터를 지금부터 쌓는다. ARKit이 프레임마다 제공하는 52개 블렌드셰이프 중 현재 5개만 사용하고 나머지를 버리고 있으며, 세션 통계·행동 데이터도 저장하지 않는다. 이 데이터는 소급 수집이 불가능하므로 스키마를 한 번에 설계해 확장한다.

## 목표

1. 추가 권한 없이, 이미 흐르고 있는 ARKit 데이터를 최대한 보존한다.
2. 스냅샷 1개가 아닌 세션 단위 통계(유지력·안정성)를 저장한다.
3. 케어 루틴의 행동 데이터(소요 시간, 이탈 지점)를 저장한다.
4. 기분 이모지 1탭 입력으로 무드-표정 상관 데이터를 확보한다.
5. 프라이버시 원칙 유지: 수치만, 온디바이스만. 원본 이미지/프레임은 저장하지 않는다.

## 1. CheckInSession 확장 (하이브리드 스키마)

기존 컬럼(`date`, `mouthCornerLeft/Right`, `browTension`, `lightingQuality`, `deviceAngleOK`, `scoreDelta`)은 그대로 유지한다.

### 타입 컬럼 추가 (쿼리/차트용)

| 필드 | 타입 | 의미 |
|---|---|---|
| `smileMean` | `Double?` | 세션 동안 미소 강도(좌우 평균)의 평균 |
| `smileMax` | `Double?` | 세션 동안 미소 강도 최대값 |
| `smileStability` | `Double?` | 미소 강도 표준편차 (낮을수록 안정) |
| `smileAsymmetry` | `Double?` | 좌우 입꼬리 차이 (mouthSmileLeft − mouthSmileRight의 세션 평균) |
| `duchenneScore` | `Double?` | cheekSquint+eyeSquint 기반 "진짜 미소" 지표의 세션 평균 |
| `mood` | `String?` | 기분 이모지 raw value. 미선택 시 nil |

### JSON blob 추가 (미래 보험)

- `payload: Data?` — 아래 `CheckInPayload`를 JSON 인코딩
- `payloadVersion: Int` — 기본값 1

```swift
struct CheckInPayload: Codable {
    /// 체크인 확정 순간의 블렌드셰이프 52개 전체 (키: ARKit blendShape rawValue)
    var blendshapesFinal: [String: Double]
    /// 선별 지표 12개의 세션 통계
    var sessionStats: [String: MetricStats]   // MetricStats { mean, max, std }
    /// 얼굴 각도 원본 (deviceAngleOK 불리언과 별개로 원본 보존)
    var pitchDegrees: Double?
    var yawDegrees: Double?
    /// 세션 메타
    var captureDurationSeconds: Double
    var trackingLossCount: Int
}
```

선별 지표 12개: mouthSmileLeft/Right, browDownLeft/Right, browInnerUp, eyeSquintLeft/Right, cheekSquintLeft/Right, jawOpen, mouthPressLeft/Right.

새 필드는 전부 optional 또는 기본값이 있어 SwiftData 경량 마이그레이션이 자동 처리한다. 기존 데이터는 새 필드가 nil인 채로 유지된다.

## 2. 캡처 파이프라인

### FaceMeasurement 확장

- `blendShapes: [String: Double]` 추가 — 52개 전체. 기본값 `[:]`로 기존 테스트/목 구현이 깨지지 않는다.
- `pitchDegrees: Double?`, `yawDegrees: Double?` 추가 — `ARKitFaceTrackingSession`이 이미 계산하는 각도의 원본값.
- 기존 필드(`mouthCornerLeft/Right`, `browTension`)와 `ScoreCalculator`는 변경 없음.

### SessionMetricsAccumulator (신규, CoachingKit)

- 트래킹 중 매 프레임 `FaceMeasurement`를 받아 지표별 mean/max/std를 스트리밍 계산한다 (Welford 알고리즘 — 프레임 원본을 쌓지 않으므로 메모리 사용이 일정).
- 트래킹 유실 횟수, 세션 길이(첫 프레임~확정 시각)도 집계한다.
- 순수 로직 컴포넌트로 UI/ARKit 의존 없음 → 단위 테스트 대상.

### CoachingViewModel 변경

- `CoachingViewModel`이 accumulator를 소유하고, `onUpdate`마다 프레임을 전달한다.
- `complete()`에서 accumulator 결과로 `CheckInPayload`와 타입 컬럼 값을 만들어 `SessionRepository.saveCheckIn`(시그니처 확장)에 넘긴다.

## 3. CareSession 보강

기존 `date`, `routineID`에 추가:

| 필드 | 타입 | 의미 |
|---|---|---|
| `startedAt` | `Date?` | 루틴 시작 시각 |
| `durationSeconds` | `Double?` | 실제 소요 시간 |
| `completedSteps` | `Int?` | 완료한 스텝 수 |
| `totalSteps` | `Int?` | 루틴의 전체 스텝 수 |
| `wasCompleted` | `Bool` | 완주 여부. 기본값 true (기존 데이터는 전부 완주 기록) |

**중도 이탈도 저장한다.** 현재는 완주 시에만 기록하는데, 루틴 화면에서 나갈 때도 진행 상황을 저장하도록 `CareViewModel`에 이탈 저장 API를 추가한다. "어느 스텝에서 포기하는가"가 루틴 개선·추천의 핵심 데이터다.

## 4. 기분 이모지 UI

- 위치: 체크인 완료 화면 (`CoachingViewModel.Phase.completed`).
- 이모지 5개 (😊 🙂 😐 😞 😫) + 건너뛰기. 탭 1회로 완료.
- 저장 방식: 측정 데이터는 `complete()`에서 즉시 저장하고, 이모지 선택 시 방금 저장된 세션의 `mood`를 업데이트한다. 저장을 미루지 않으므로 유저가 선택 없이 나가도 측정 데이터는 안전하다.

## 5. 범위 제외

- HealthKit 연동 (수면·마음챙김) — 권한 마찰이 있어 별도 스펙.
- 원본 이미지/프레임 저장 — 프라이버시 원칙상 하지 않는다.
- AI 기능 자체 (추천 엔진, LLM 리포트) — 데이터가 쌓인 뒤 별도 스펙.
- 서버 전송 — 모든 데이터는 온디바이스에만 저장한다.

## 6. 테스트

1. `SessionMetricsAccumulator`: 알려진 프레임 시퀀스 → 기대 mean/max/std 일치 (Welford 정확성 포함).
2. `CheckInPayload` 인코딩/디코딩 라운드트립.
3. 마이그레이션: 구버전 스키마로 만든 스토어가 새 스키마로 열리고 기존 레코드가 유지되는지.
4. 케어 이탈 저장: 중도 이탈 시 `wasCompleted == false`와 진행 스텝 수가 기록되는지.
5. 무드 업데이트: 저장 후 이모지 선택 시 해당 세션에 반영되는지, 건너뛰면 nil 유지되는지.
