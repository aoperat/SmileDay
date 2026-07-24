# 룰 기반 코칭 4종 설계

- 날짜: 2026-07-24
- 상태: 승인됨
- 배경: 데이터 수집 확장(2026-07-23)으로 비대칭·진짜미소·긴장도·신뢰도 지표가 쌓이기 시작했지만 어디서도 활용되지 않는다. AI 없이 룰 기반으로 이 지표를 사용자 체감 기능(체크인 인사이트 + 케어 추천)으로 연결한다.

## 목표

1. 체크인 직후 저장 완료 화면에 개인화된 인사이트 1줄을 보여준다.
2. 케어 탭의 "오늘의 추천"이 항상 lift 고정인 것을 인사이트 기반 카테고리 추천으로 교체한다.
3. 판정은 개인 히스토리(최근 7일) 상대 비교로 하고, 신뢰도 낮은 측정은 코칭에 쓰지 않는다.
4. 로직은 순수 컴포넌트로 분리해 유닛 테스트하고, 추후 AI 멘트로 교체 가능한 구조로 만든다.

## 1. InsightEngine (CoachingKit, 신규)

### 입력

SwiftData 모델이 아닌 값 타입을 받는다 (순수 로직 유지):

```swift
public struct CheckInRecord {
    public let date: Date
    public let browTension: Double
    public let smileAsymmetry: Double?   // 확장 전 레코드는 nil
    public let duchenneScore: Double?
    public let deviceAngleOK: Bool
    public let lightingQuality: Double
    public let trackingLossCount: Int?   // payload 디코드 결과. 없으면 nil
}
```

`CheckInSession → CheckInRecord` 매퍼를 함께 제공한다 (payload를 디코드해 trackingLossCount 추출).

### 출력

```swift
public struct CheckInInsight: Equatable {
    public enum Kind: Equatable {
        case lowReliability
        case highTension
        case asymmetry(weakSide: Side)   // Side: .left / .right (덜 올라간 쪽)
        case lowDuchenne
    }
    public let kind: Kind
    public let message: String           // 사용자 노출 문구
    public let recommendedCategory: CareCategory?  // lowReliability는 nil
}
```

`InsightEngine.evaluate(today: CheckInRecord, history: [CheckInRecord]) -> CheckInInsight?`

### 판정 규칙 (우선순위 순, 최초 1개만 반환)

**공통 정의**
- 신뢰 불가 기록: `deviceAngleOK == false` OR `lightingQuality < 0.3` OR `trackingLossCount >= 3`
  (0.3은 `LightingEvaluator.darkThreshold(300) / referenceIntensity(1000)`와 일치)
- 기준 집합: history 중 오늘 제외 최근 7일의 **신뢰 가능한** 기록. 지표별로 해당 값이 nil인 기록은 그 지표 계산에서 제외.

**규칙 1 — 신뢰도 (lowReliability)**
- 조건: 오늘 기록이 신뢰 불가
- 동작: "측정이 조금 흔들렸어요. 내일은 밝은 곳에서 정면으로 찍어봐요" 반환, **이후 규칙 평가 중단**
- recommendedCategory: nil (케어 추천은 기존 fallback 유지)

**규칙 2~4 공통 게이트**
- 기준 집합에서 해당 지표 값이 3개 미만이면 그 규칙은 평가하지 않음 (데이터 부족)

**규칙 2 — 긴장도 (highTension)**
- 조건: `오늘 browTension > 평균 + max(0.5 × 표준편차, 0.05)`
- 문구: "오늘은 미간 긴장이 평소보다 높아요. 릴랙스 케어로 풀어줘요"
- recommendedCategory: `.relax`

**규칙 3 — 비대칭 (asymmetry)**
- 조건: `|오늘 smileAsymmetry| > |히스토리 asymmetry| 평균 + max(0.5 × 표준편차, 0.03)`
- weakSide: 오늘 asymmetry(좌−우) > 0이면 `.right`(오른쪽이 덜 올라감), < 0이면 `.left`
- 문구: "오늘은 {왼/오른}쪽 입꼬리가 덜 올라갔어요. 리프팅으로 균형을 맞춰봐요"
- recommendedCategory: `.lift`

**규칙 4 — 진짜미소 (lowDuchenne)**
- 조건: `오늘 duchenneScore < 평균 − max(0.5 × 표준편차, 0.05)`
- 문구: "입은 웃는데 눈은 아직이에요. 아침 스마일 스트레칭이 도움 돼요"
- recommendedCategory: `.morning`

최소편차 상수(0.05 / 0.03 / 0.05)는 `InsightEngine` 내부 상수로 두고 추후 실데이터로 튜닝한다.

## 2. 저장 완료 화면 노출

- `SaveConfirmView`에 `var insightMessage: String? = nil` 추가. 점수 아래·무드 피커 위에 1줄 카드로 표시. nil이면 렌더링 없음 (기존 화면 불변).
- `CoachingTabView`: 체크인 완료 콜백에서 `SessionRepository`로 오늘 기록 + 최근 7일 기록을 조회 → 매퍼 → `InsightEngine.evaluate` → 결과 message를 `SaveConfirmView`에 전달.

## 3. 케어 추천 교체

`CareViewModel.makeRecommendation` 변경:

1. 최신 체크인(오늘 또는 어제)과 그 이전 7일 기록으로 `InsightEngine.evaluate` 실행
2. 인사이트가 있고 `recommendedCategory != nil`이면: 해당 카테고리의 첫 루틴 + 인사이트 문구를 reason으로 추천
3. 인사이트가 없거나 카테고리가 nil이면: **기존 scoreDelta 기반 로직 그대로 fallback** (기존 동작·기존 테스트 보존)

## 4. 범위 제외

- 홈 화면 반영, 히스토리 화면 변경
- AI/LLM 멘트 생성 (이 엔진의 message를 나중에 LLM 출력으로 교체하는 것이 후속 단계)
- mood 데이터 활용
- 임계값 원격 구성/실험(A-B 테스트)

## 5. 테스트

1. 규칙별 발동/비발동 경계값 (임계 직전/직후)
2. 우선순위: 긴장도+비대칭 동시 발동 시 긴장도만 반환
3. 신뢰도: 오늘 기록 신뢰 불가 시 lowReliability 반환 + 다른 규칙 억제
4. 데이터 부족: 신뢰 기록 3개 미만이면 nil (지표별 nil 값 제외 확인 포함)
5. 히스토리 평균 계산에서 신뢰 불가 기록 제외
6. 비대칭 방향(weakSide) 판정
7. 매퍼: payload 없는 구버전 CheckInSession → trackingLossCount nil로 매핑
8. CareViewModel: 인사이트 있을 때 카테고리 추천, 없을 때 기존 로직 fallback (기존 테스트 유지 확인)
