# 프로젝트 안정성 정리 Design Spec

> 날짜: 2026-07-27  
> 상태: 계획 수립  
> 배경: 프로젝트 구조 점검에서 배포 타깃 불일치, 초기화 강제 종료, 정책상 혼동 가능한 내부 명칭, 실기기 검증 공백이 확인되었다.

## Goal

SmileDay의 선언된 지원 범위(iOS 17+)와 실제 빌드 설정을 일치시키고, 앱 시작 및 카메라 프리뷰 초기화 실패를 복구 가능한 사용자 경험으로 바꾼다. 또한 건강 효능을 연상시킬 수 있는 내부 명칭을 표정 습관 중심 용어로 정리하고, TrueDepth 실기기 검증 절차를 반복 가능한 체크리스트로 남긴다.

## Non-goals

- 점수 계산식, 인사이트 임계값, 기준선 측정 알고리즘은 변경하지 않는다.
- SwiftData 스키마와 기존 사용자 기록 형식은 변경하지 않는다.
- ARKit을 다른 얼굴 추적 엔진으로 교체하지 않는다.
- 지원 기기 범위에 TrueDepth 미지원 기기를 새로 포함하지 않는다.

## Decisions

### 1. 배포 타깃은 iOS 17.0으로 통일한다

`CoachingKit/Package.swift`가 선언한 `.iOS(.v17)` 및 프로젝트 목적과 일치하도록 Xcode 프로젝트의 Debug/Release `IPHONEOS_DEPLOYMENT_TARGET`을 `17.0`으로 설정한다. 앱 타깃에 명시적인 값을 두어 프로젝트 기본값에 우연히 의존하지 않게 한다.

### 2. SwiftData 초기화 실패는 전용 복구 화면으로 표시한다

`SmileDayApp`의 `try!`를 제거한다. `ModelContainer` 생성 결과를 성공/실패 상태로 보관하고, 실패 시 데이터 삭제나 자동 초기화를 수행하지 않은 채 한국어 오류 안내와 앱 재시도 방법을 보여준다. 사용자의 기존 데이터를 암묵적으로 지우는 복구는 이 작업 범위에서 금지한다.

### 3. Metal 미지원은 추적 세션 오류로 전달한다

카메라 프리뷰 렌더러 생성 실패가 프로세스 종료로 이어지지 않게 한다. `ARKitFaceTrackingSession`은 렌더러를 선택적으로 보유하고, Metal을 만들 수 없으면 대체 검은 프리뷰를 제공하면서 `FaceTrackingError.previewUnavailable`을 `onError`로 전달한다. 기준선/코칭 화면은 동일한 한국어 오류 문구를 표시하고 저장·측정 완료를 진행하지 않는다.

`required init(coder:)`의 `fatalError`는 해당 초기화 경로가 `@available(*, unavailable)`로 컴파일 차단되어 있으므로 런타임 장애 경로와 구분한다. 이번 변경에서는 제거하지 않는다.

### 4. `.lift`는 의미 중심 이름으로 변경하되 raw value 호환성을 유지한다

`CareCategory.lift`를 `CareCategory.mouthCorner`로 변경하고 raw value는 기존 `"lift"`를 유지한다.

```swift
public enum CareCategory: String, CaseIterable, Sendable {
    case mouthCorner = "lift"
    case relax
    case depuff
    case morning
}
```

현재 카테고리가 SwiftData에 직접 저장되지는 않지만, UserDefaults·향후 마이그레이션·외부 디버그 데이터와의 호환성을 위해 raw value를 유지한다. 루틴 ID와 영상 파일명(`lift-smile`, `care_lift_smile`)은 리소스 식별자이므로 이번 범위에서는 바꾸지 않는다. 사용자 노출 문구는 계속 “입꼬리”를 사용한다.

### 5. 실기기 검증을 릴리스 체크리스트로 문서화한다

Face ID/TrueDepth 지원 기기에서 권한 허용·거부, 기준선, 체크인, 조명/각도 안내, 앱 백그라운드 전환, 알림 딥링크를 확인한다. 개인 얼굴 수치나 화면 녹화 파일은 저장소에 첨부하지 않는다.

## Acceptance Criteria

- 프로젝트와 패키지의 최소 지원 버전이 모두 iOS 17.0이다.
- SwiftData 저장소 생성 실패와 Metal 렌더러 생성 실패에 사용자 데이터 삭제 및 `fatalError`가 없다.
- 앱 시작 실패 화면과 카메라 실패 문구가 한국어다.
- 소스의 의미적 카테고리 참조에 `.lift`가 남지 않고, `CareCategory.mouthCorner.rawValue == "lift"`이다.
- CoachingKit 전체 XCTest와 iOS 시뮬레이터 빌드가 통과한다.
- TrueDepth 실기기 체크리스트 결과가 문서에 기록된다.

