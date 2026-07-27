# SmileDay 프로젝트 점검 보고서

- 작성일: 2026-07-27
- 기준 브랜치/커밋: `main` / `fd7e044`
- 점검 범위: 앱·패키지 구조, 빌드 설정, 자동 테스트, 강제 종료 경로, 사용자 문구 정책, 문서 정합성
- 주의: 점검 당시 작업 트리에 기존 수정 및 미추적 파일이 다수 존재했다. 이 보고서는 해당 변경을 삭제하거나 되돌리지 않은 상태를 기준으로 한다.

## 1. 결론

핵심 로직의 자동 테스트는 안정적이지만, 배포 전 해결해야 할 설정 및 시작 안정성 문제가 남아 있다.

1. `CoachingKit` 전체 158개 XCTest가 통과했다.
2. 앱 프로젝트의 최소 지원 버전은 문서와 패키지의 iOS 17 선언과 달리 `26.5`로 설정되어 있다.
3. SwiftData 저장소 초기화와 Metal 프리뷰 초기화에 실제 실행 가능한 강제 종료 경로가 있다.
4. 정책상 피해야 할 `lift` 의미 명칭이 도메인 코드에 남아 있다. 사용자 화면의 현재 표시명은 “입꼬리”지만 명칭 정리가 필요하다.
5. 앱 빌드는 점검 환경의 CoreSimulatorService 및 사용자 캐시 접근 제한 때문에 완료 여부를 판정하지 못했다.

현재 최우선 작업은 대응 설계와 계획이 작성된 `project-hardening` 작업이다.

- 설계: `SmileDay/docs/superpowers/specs/2026-07-27-project-hardening-design.md`
- 계획: `SmileDay/docs/superpowers/plans/2026-07-27-project-hardening.md`

## 2. 확인된 구조

- `CoachingKit/`: SwiftData 모델, 저장소, `@Observable` ViewModel, 점수·인사이트·리마인더 등 플랫폼 독립 로직과 XCTest
- `SmileDay/`: SwiftUI 화면, ARKit/Metal 카메라, 알림 등 Apple 플랫폼 서비스
- 데이터 처리: 사진·영상 원본을 저장하지 않고 얼굴 측정 수치와 사용자 설정을 온디바이스에 보관
- 의존성: Apple 프레임워크만 사용하며 외부 패키지 없음
- 앱 언어와 정책: 사용자 문구는 한국어, 로케일은 `ko_KR`, 의료·외모 개선 효과를 단정하는 표현은 금지

구조 자체는 루트 지침의 “새 로직은 `CoachingKit`에 테스트와 함께 추가하고 앱 타깃은 UI와 플랫폼 래퍼만 둔다”는 원칙과 일치한다.

## 3. 검증 결과

### 3-1. CoachingKit 테스트

실행 명령:

```bash
cd CoachingKit
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/smileday-clang-cache \
swift test --disable-sandbox
```

결과:

- `Test Suite 'All tests' passed`
- 158 tests, 0 failures
- Swift Testing runner의 마지막 `0 tests in 0 suites passed`는 XCTest 결과와 별개이며 실패가 아님
- 테스트 도중 CoreData 알림 등록 경고가 반복됐으나 테스트 실패는 발생하지 않음

기본 `swift test`는 사용자 홈의 clang 캐시에 쓸 수 없어 실패했다. 이는 소스 실패가 아니라 점검 환경 권한 문제였고, 허용된 임시 캐시와 SwiftPM 샌드박스 비활성화로 재검증했다.

### 3-2. 앱 빌드

실행 명령:

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-clang-cache \
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/smileday-derived-data \
  CODE_SIGNING_ALLOWED=NO build
```

결과: **환경 제한으로 미판정**

- CoreSimulatorService 연결 실패
- 사용자 SwiftPM/clang 캐시 접근 거부
- 패키지 그래프 해석 단계에서 종료되어 앱 소스 컴파일 성공·실패를 판정할 수 없음

권한 제한이 없는 Xcode 환경에서 같은 명령을 다시 실행해야 한다.

## 4. 주요 발견 사항

### P0 — 최소 지원 버전 불일치

- `CoachingKit/Package.swift`: `.iOS(.v17)`
- 프로젝트 설명과 제품 목표: iOS 17+
- `SmileDay.xcodeproj/project.pbxproj`: Debug/Release 모두 `IPHONEOS_DEPLOYMENT_TARGET = 26.5`

현재 프로젝트 설정은 의도한 지원 범위를 충족하지 않는다. 앱 타깃을 17.0으로 통일하고 generic simulator build로 iOS 17 API 호환성을 확인해야 한다.

### P0 — 앱 시작 시 SwiftData 초기화 실패가 강제 종료로 연결

`SmileDay/SmileDayApp.swift`가 `try! ModelContainer(...)`를 사용한다. 저장소 생성이나 마이그레이션에 실패하면 복구 안내 없이 앱이 종료될 수 있다.

실패 상태를 명시적으로 보관하고 한국어 오류 화면을 보여주되, 사용자 데이터를 자동 삭제하거나 빈 저장소로 몰래 대체하지 않아야 한다.

### P0 — Metal 프리뷰 생성 실패가 강제 종료로 연결

`SmileDay/Services/CameraPreviewView.swift`에서 Metal device 또는 command queue 생성 실패 시 `fatalError`를 호출한다. 측정 불가 상태를 오류 콜백과 UI로 전달하는 복구 가능한 흐름이 필요하다.

`@available(*, unavailable)`로 차단된 coder initializer의 `fatalError`는 실제 실행 경로와 구분해서 판단한다.

### P1 — 정책과 도메인 명칭 정합성

`CareCategory.lift`와 관련 참조가 패키지·앱·테스트에 남아 있다. 현재 사용자 표시명은 “입꼬리”이므로 직접 노출 문제는 제한적이지만, 금지 표현 정책과 코드 의미를 일치시키는 편이 안전하다.

기존 저장 데이터 호환성을 위해 `case mouthCorner = "lift"`처럼 raw value는 유지해야 한다.

문서에는 과거 예시와 정책 설명 때문에 “리프팅” 등의 문자열이 남아 있다. 검색 결과를 무조건 삭제 대상으로 보지 말고, 현재 앱 소스의 사용자 노출 문자열과 실행 중 생성되는 문구를 우선 판정해야 한다.

### P1 — TrueDepth 실기기 검증 공백

시뮬레이터에서는 ARKit 얼굴 추적을 검증할 수 없다. iOS 17 이상 TrueDepth 지원 iPhone에서 권한 허용·거부, 얼굴 이탈, 어두운 환경, 각도 초과, 백그라운드 복귀, 저장 및 재실행 유지까지 확인해야 한다.

검증 결과는 별도의 날짜 기반 보고서에 기기 모델, iOS 버전, 빌드/커밋, PASS/FAIL만 남기고 실제 얼굴 이미지나 개인 측정 원시값은 저장소에 추가하지 않는다.

### P2 — 문서 최신성

`2026-07-24-data-inventory-and-ideas.md`는 데이터 활용 아이디어 보고서이며 현재 프로젝트 전체 상태의 기준 문서가 아니다. 일부 아이디어 문구는 현재 건강 효능 표현 정책과 맞지 않으므로 구현 근거로 사용할 때 최신 설계 문서를 우선해야 한다.

또한 기능 문서는 `SmileDay/docs/superpowers/`와 루트 `docs/superpowers/` 두 트리에 나뉘어 있다. 새 기능을 확장할 때 대상 기능의 기존 문서 위치를 먼저 확인하고, 앱 기능의 기본 설계·계획은 `SmileDay/docs/superpowers/`의 짝을 유지한다.

## 5. 권장 작업 순서

1. `2026-07-27-project-hardening-design.md`를 읽고 대응 계획을 순서대로 수행
2. iOS 최소 타깃을 17.0으로 통일
3. SwiftData와 Metal의 실제 강제 종료 경로 제거
4. `CareCategory` 명칭을 raw value 호환 방식으로 변경하고 회귀 테스트 추가
5. `CoachingKit` 전체 테스트와 앱 generic simulator build 재실행
6. TrueDepth 실기기 체크리스트 수행 및 결과 보고서 작성
7. 사용자 노출 문구만 대상으로 건강 효능 표현을 최종 점검

## 6. 다음 점검 시 갱신 규칙

- 이 문서는 2026-07-27의 스냅샷이다.
- 이후 코드 변경으로 영향을 받은 항목은 현재 소스와 테스트로 다시 확인한다.
- 프로젝트 전체를 다시 점검했다면 이 문서를 갱신하거나 더 최신 날짜의 보고서로 대체한다.
- 새 보고서를 만들 경우 루트 `AGENTS.md`의 “latest project-wide review” 링크도 함께 갱신한다.
