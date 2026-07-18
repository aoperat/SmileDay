# 표정 코치 iOS 앱 구현 계획

**상태**: 승인됨 (사용자 제공 초안 그대로 채택)
**작성일**: 2026-07-18
**프로젝트**: SmileDay (Xcode + SwiftUI)

Xcode + SwiftUI 네이티브 구현을 위한 계획 문서. 지금까지 논의된 전문가 평가(안면 재활, UX, 컴퓨터비전)와 개선된 정보구조를 반영했다.

## 1. 포지셔닝 재확인

안면 재활 전문가 검토 결과, "훈련하면 입꼬리가 리프트된다"는 표현은 근거가 약하다. 앱스토어 심사(Guideline 1.4.1, 의료/건강 클레임)에서도 문제가 될 수 있다. 앱 전체의 문구와 온보딩 카피는 다음 원칙을 따른다.

- 사용 금지 표현: "리프팅", "젊어진다", "교정한다", "치료"
- 사용 권장 표현: "무표정일 때의 얼굴 긴장 습관을 인지한다", "표정 습관을 기록한다"
- 온보딩에 "의학적 효과를 보장하지 않으며, 심한 비대칭이나 안면마비가 의심되면 전문의 상담을 권장한다"는 문구를 1회 고지

## 2. 기술 스택

| 영역 | 선택 | 비고 |
|---|---|---|
| UI | SwiftUI | iOS 17 타겟 권장 (SwiftData 사용 위해) |
| 아키텍처 | MVVM | View - ViewModel(ObservableObject/@Observable) - Service |
| 얼굴 분석 (주) | ARKit `ARFaceTrackingConfiguration` + `ARFaceAnchor.blendShapes` | TrueDepth 카메라 필요, 52종 블렌드셰이프 계수를 바로 제공해 각도 계산을 직접 안 해도 됨 |
| 얼굴 분석 (폴백) | Vision `VNDetectFaceLandmarksRequest` | TrueDepth 미지원 기기 대응, 정적 사진 랜드마크 좌표 직접 계산 필요 |
| 카메라 캡처 | AVFoundation (Vision 경로용) / ARSession (ARKit 경로용) | |
| 로컬 저장 | SwiftData | 얼굴 데이터·사진은 기기 밖으로 나가지 않음 (서버 없음) |
| 알림 | `UNUserNotificationCenter` 로컬 알림 | 서버 푸시 불필요 — 지난 웹앱 검토에서 나온 iOS 웹푸시 불안정 문제가 네이티브에서는 아예 해소됨 |
| 차트 | Swift Charts | 주간 추이 그래프 |

**ARKit을 주 엔진으로 쓰는 이유**: `mouthSmileLeft/Right`, `mouthFrownLeft/Right`, `browDownLeft/Right`, `browInnerUp` 같은 블렌드셰이프가 이미 입꼬리·미간 상태를 의미 단위로 제공한다. 별도로 랜드마크 좌표를 받아 각도를 계산할 필요가 없어 정확도와 개발 속도 모두에서 유리하다. 다만 TrueDepth 카메라(Face ID 탑재 기종)가 필요하므로, 미지원 구형 기기는 Vision 프레임워크로 랜드마크 좌표 기반 각도 계산 경로를 따로 둔다.

## 3. 정보구조 (개선안 반영)

지난 사용성 분석에서 지적된 두 가지, 카메라 진입점 중복과 기준선 재설정 누락을 반영한 최종 구조.

```
앱 실행
 └ 최초 1회: 기준선 촬영 (온보딩)
      ↓
 TabView
 ├ 홈        오늘 할 일 카드 1개만 (코칭 시작 여부)
 ├ 코칭      체크인과 실시간 코칭을 하나로 통합한 카메라 허브
 │            → 세션 종료 시 "저장 확인" 화면
 ├ 기록      주간/월간 추이 그래프, 히스토리 캘린더, 루틴 완료 기록
 └ 설정      리마인더 시간 관리, 기준선 재설정, 데이터 저장 위치, 계정
```

## 4. 데이터 모델 (SwiftData)

```swift
@Model
final class Baseline {
    var capturedAt: Date
    var mouthCornerLeft: Double   // blendShape 계수 0~1
    var mouthCornerRight: Double
    var browTension: Double
}

@Model
final class CheckInSession {
    var date: Date
    var mouthCornerLeft: Double
    var mouthCornerRight: Double
    var browTension: Double
    var lightingQuality: Double   // 측정 신뢰도 플래그용
    var deviceAngleOK: Bool
    var scoreDelta: Double        // 기준선 대비 변화량
}

@Model
final class ReminderSetting {
    var time: DateComponents
    var isEnabled: Bool
}

@Model
final class RoutineCompletion {
    var date: Date
    var routineType: String
    var completed: Bool
}
```

`lightingQuality`, `deviceAngleOK` 필드는 컴퓨터비전 전문가 검토에서 지적된 "조명·각도 오차가 트래킹 신뢰도를 해친다"는 문제에 대응하기 위한 필드다. 측정 시점의 신뢰도를 함께 저장해, 나중에 그래프에서 "신뢰도 낮은 측정치"를 흐리게 표시하거나 제외할 수 있게 한다.

## 5. 화면 구성 (SwiftUI View 매핑)

| 화면 | View | 핵심 컴포넌트 | 의존 서비스 |
|---|---|---|---|
| 온보딩 | `BaselineCaptureView` | ARSession 미리보기, 얼굴 가이드 오버레이 | `FaceTrackingService` |
| 홈 | `HomeView` | 오늘의 할 일 카드, 스트릭 인디케이터 | `SessionRepository` |
| 코칭 | `CoachingSessionView` | 카메라 프리뷰, 실시간 게이지 오버레이, 조명 경고 배너 | `FaceTrackingService`, `LightingMonitor` |
| 저장 확인 | `SessionSummarySheet` | 완료 체크 아이콘, 어제 대비 점수 비교 | `SessionRepository` |
| 기록 | `HistoryView` | Swift Charts 주간 그래프, 캘린더 히트맵 | `SessionRepository` |
| 설정 | `SettingsView` | 리마인더 리스트, 기준선 재설정 행(경과 주 수 표시), 데이터 위치 안내 | `ReminderService`, `BaselineRepository` |

## 6. Xcode 프로젝트 구조 제안

```
ExpressionCoach/
├── App/
│   └── ExpressionCoachApp.swift
├── Models/
│   ├── Baseline.swift
│   ├── CheckInSession.swift
│   ├── ReminderSetting.swift
│   └── RoutineCompletion.swift
├── Services/
│   ├── FaceTrackingService.swift      // ARKit 경로
│   ├── VisionFallbackService.swift    // Vision 경로 (TrueDepth 미지원 기기)
│   ├── LightingMonitor.swift
│   ├── ReminderService.swift          // UNUserNotificationCenter 래퍼
│   └── SessionRepository.swift        // SwiftData CRUD
├── Views/
│   ├── Onboarding/BaselineCaptureView.swift
│   ├── Home/HomeView.swift
│   ├── Coaching/CoachingSessionView.swift
│   ├── Coaching/SessionSummarySheet.swift
│   ├── History/HistoryView.swift
│   └── Settings/SettingsView.swift
├── ViewModels/
│   ├── CoachingViewModel.swift
│   ├── HomeViewModel.swift
│   └── HistoryViewModel.swift
└── Resources/
    └── Assets.xcassets
```

> **참고**: 현재 실제 Xcode 타겟 이름은 `SmileDay`이며, 앱 표시 문구는 위 "포지셔닝 재확인" 원칙(효능 클레임 배제)을 따르되 프로젝트/타겟 이름은 기존 `SmileDay`를 유지한다. 위 트리의 `ExpressionCoach/`는 내부 설계상 명칭이며 실제 폴더 구조는 `SmileDay/` 하위에 동일하게 구성한다.

## 7. 개발 마일스톤

**Phase 1 — MVP (2~3주 예상)**
온보딩(기준선 촬영), 코칭 화면(ARKit 블렌드셰이프 읽기 + 게이지 오버레이), 세션 저장(SwiftData), 홈 화면 단순 버전. TrueDepth 기기만 우선 지원.

**Phase 2 — 트래킹/루틴**
기록 탭(Swift Charts 그래프), 루틴 리스트 및 타이머, 로컬 리마인더 알림.

**Phase 3 — 견고화**
Vision 프레임워크 폴백 경로(TrueDepth 미지원 기기), 조명/각도 신뢰도 감지 및 경고 UI, 기준선 재설정 플로우, 접근성(VoiceOver) 검토.

**Phase 4 — 출시 준비**
개인정보처리방침 작성(카메라·얼굴 데이터가 기기 내부에만 저장됨을 명시), App Store 심사 대비 건강 클레임 문구 재검토, TestFlight 베타.

## 8. 리스크 체크리스트

- 얼굴 데이터는 기기 로컬(SwiftData)에만 저장하고 서버 전송 없음을 개인정보처리방침과 온보딩에 명시
- App Store 심사 가이드라인 1.4.1(신체적 피해 관련 클레임) 대비, 효능 표현을 "인지·기록" 중심으로 유지
- TrueDepth 미지원 기기(주로 구형 iPhone SE 등) 비율 확인 후 Vision 폴백 우선순위 결정
- 카메라 권한 요청 문구(`NSCameraUsageDescription`)에 얼굴 데이터 로컬 처리 방침을 포함
- 심한 안면 비대칭·마비가 의심되는 사용자를 위한 전문의 상담 안내 문구 위치 확정

## 9. Phase 1 구현 계획 수립 전 확인이 필요한 사항

스펙 자체 검토 과정에서 Phase 1(MVP) 상세 구현 계획을 세우기 전에 명확히 해야 할 항목을 정리했다. 이 항목들은 다음 단계(writing-plans)에서 질문 또는 가정으로 다뤄진다.

- **코칭 세션의 종료 조건**: 사용자가 수동으로 "완료" 버튼을 누르는 방식인지, 타이머(예: 30초/1분) 자동 종료인지 미정.
- **`scoreDelta` 계산 공식**: 기준선 대비 변화량을 어떤 가중치로 합산하는지(입꼬리 좌/우 + 미간 긴장을 단순 평균/가중 평균 등) 미정.
- **기준선 재설정 권장 시점**: 설정 화면에 "경과 주 수"를 표시한다고만 되어 있고, 몇 주 경과 시 재설정을 권장할지(예: 4주) 기준이 없음.
- **`RoutineCompletion.routineType`의 실제 값 목록**: Phase 2 루틴 리스트에 어떤 루틴 종류가 포함되는지 아직 정의되지 않음.

이 항목들은 설계를 막는 수준은 아니며, Phase 1 상세 계획 수립 시 확정한다.
