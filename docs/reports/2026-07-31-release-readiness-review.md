# SmileDay 출시 준비 점검 보고서

- 작성일: 2026-07-31
- 기준 브랜치/커밋: `feature/live-smile-monitor` / `bd8fb70` + 현재 출시 설정 변경
- 점검 시작 시 작업 트리: clean. 점검 중 Xcode 프로젝트의 출시 설정 변경이 추가됨
- 목적: App Store 첫 출시 직전 코드, 번들, 개인정보, 서명, 메타데이터, 실기기 검증 상태 판정
- 이전 전체점검: `2026-07-31-project-review.md`

## 1. 출시 판정

**현재 판정은 조건부 보류다.**

앱 코드에서 즉시 출시를 막는 P0 크래시, 데이터 외부 전송, 카메라 사진 생성, 핵심 5초 흐름 불능은 발견하지 않았다. 패키지 테스트 224개가 모두 통과했고, 최신 HEAD 뒤 생성된 Release simulator 앱 번들에는 개인정보 매니페스트와 코드·아이콘 자산만 들어 있다.

다만 아래 출시 절차상 P0가 닫히기 전에는 심사 제출하지 않는다.

1. 공개 개인정보처리방침 URL을 만들고 App Store Connect와 앱 설정 화면 양쪽에 연결한다.
2. 실제 연락 가능한 지원 URL을 준비한다.
3. App Store Connect의 App Privacy 응답을 현재 구현과 대조해 게시한다.
4. 배포용 Archive를 만들고 서명 팀·Bundle ID를 확인한 뒤 TestFlight 업로드와 설치를 검증한다.

## 2. 검증 결과

### CoachingKit

실행:

```bash
cd CoachingKit
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-release-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/smileday-release-clang \
swift test --disable-sandbox
```

결과:

- `Test Suite 'All tests' passed`
- 224 tests, 0 failures
- SwiftData notification registration 경고가 있었지만 테스트 실패는 없었다.
- 마지막 Swift Testing runner의 `0 tests in 0 suites passed`는 XCTest suite와 별도인 정상 출력이다.

### 앱 소스와 리소스

- `xcrun swiftc -frontend -parse`로 앱 Swift 소스 전체 파싱 통과
- `git diff --check` 통과
- `SmileDay/PrivacyInfo.xcprivacy` plist lint 통과
- 앱·패키지 활성 Swift 소스에 `fatalError`, `try!`, 금지 사용자 문구 없음
- 활성 코드에 `URLSession`, Network framework, 측정값 파일 쓰기 경로 없음
- `ARFrame.capturedImage`는 코드 주석에만 있으며 실제 접근 없음
- AppIcon light/dark/tinted는 모두 1024×1024, alpha 없음
- 최신 아이콘 light/dark와 tinted 자산 육안 확인 완료

### Release 번들

현재 출시 설정 변경 뒤인 2026-07-31 15:23에 생성된 `Release-iphonesimulator/SmileDay.app`을 검사했다.

- Bundle ID: `dvelo.smileDay`
- Version/build: `1.0 (1)`
- Minimum OS: iOS 17.0
- Development region: Korean
- Device family: iPhone
- Supported orientation: portrait
- `ITSAppUsesNonExemptEncryption = false`
- 최신 카메라 사용 설명 포함
- `PrivacyInfo.xcprivacy` 포함 및 lint 통과
- Markdown, marketing PNG, `.omc`, agent replay/state 파일 미포함
- simulator 앱이라 ad-hoc 서명이며 배포 서명 판정에는 사용하지 않았다.

이번 자동화 환경에서 직접 실행한 `xcodebuild`는 소스 컴파일 전에 `CoreSimulatorService` 연결 실패와 `sandbox-exec: sandbox_apply: Operation not permitted`로 중단됐다. 이는 앱 컴파일 오류가 아니다. 이후 Xcode가 현재 설정으로 만든 최신 Release 결과물을 위와 같이 검사했다.

### 서명

- 앱 target의 Debug/Release 설정은 Automatic signing, Team `45BNT5RDHP`
- 2026-07-31 15:09 생성된 Debug iphoneos 앱도 Team `45BNT5RDHP`로 서명됨
- project-level과 target-level Team은 모두 `45BNT5RDHP`로 통일됨
- Bundle ID는 자동 생성 꼬리표가 붙은 `dvelo.SmileDay.rq4duls43r`에서 `dvelo.smileDay`로 변경했다. 꼬리표 `rq4duls43r`은 Team ID가 아니라 서명 인증서 CN의 식별자였다(인증서 OU=`45BNT5RDHP`가 실제 Team ID).
- 로컬 프로비저닝 프로파일 `iOS Team Provisioning Profile: dvelo.smileDay`(Team `45BNT5RDHP`)가 이미 존재하며, `generic/platform=iOS` Release 빌드가 이 프로파일로 서명에 성공했다(`codesign`: Identifier=`dvelo.smileDay`, TeamIdentifier=`45BNT5RDHP`).
- App Store Connect에 이 App ID로 앱 레코드가 생성돼 있는지는 저장소 밖 계정 정보라 확인하지 못했다.

## 3. P0 — 제출 전 반드시 해결

### P0-1. 공개 개인정보처리방침과 앱 내부 링크 없음

저장소와 설정 화면에는 개인정보 안내 문구는 있지만 공개 정책 URL과 그 링크가 없다. Privacy manifest는 사용자용 개인정보처리방침을 대신하지 않는다.

정책에는 최소한 다음 현재 동작을 명시한다.

- 완료 시각, 알림 설정, 사용자 알림 문구와 앱 설정은 기기에만 저장
- 실시간 확인의 사진·영상·입꼬리 신호·타임라인은 저장하거나 전송하지 않음
- 서버, 광고, 분석, 제3자 SDK 없음
- 앱 삭제 시 로컬 기록 삭제
- 연락 방법

App Review Guidelines는 개인정보처리방침 링크를 App Store Connect와 앱 내부의 쉽게 찾을 수 있는 위치에 요구한다. 설정의 “데이터 저장 위치” 아래 링크가 적절하다.

### P0-2. App Store Connect 필수 메타데이터 미검증

저장소에서 아래 항목을 확인할 수 없었다.

- App Privacy 응답과 게시 상태
- Support URL
- 설명, 키워드, 카테고리, 연령 등급
- 심사 연락처와 심사 메모
- iPhone 스크린샷
- 가격, 배포 지역, 출시 방식

현재 코드 근거로는 외부 전송과 제3자 SDK가 없고 실시간 데이터도 화면을 닫으면 사라진다. Apple은 기기 안에서만 처리되는 데이터는 App Privacy의 “수집”으로 보지 않는다고 안내한다. 최종 응답은 제출자가 실제 배포본과 정책을 대조해 확정한다.

### P0-3. 배포 Archive와 TestFlight 미검증

Release simulator 빌드는 통과 근거가 있지만 App Store 배포용 Archive, distribution provisioning, Organizer validation, 업로드 처리 결과는 아직 확인하지 못했다.

첫 업로드 전 확인:

1. Xcode Organizer에서 Generic iOS Device 대상 Archive
2. Team `45BNT5RDHP`와 App Store Connect App ID 확인
3. Bundle ID `dvelo.smileDay` 확인
4. Version/build `1.0 (1)` 확인
5. Validate App 성공
6. TestFlight 업로드·처리 성공
7. TestFlight 설치 후 신규 설치와 업데이트 경로 점검

## 4. P1 — 출시 후보 빌드에서 완료

### P1-1. 실기기 E2E 공백

자동 테스트가 아래 iOS 경계를 대신하지 못한다.

- 반복 알림 등록, 변경, 비활성화, 문구 순환
- 잠금화면 “웃었어요” background-only 저장
- “가이드 열기”와 일반 알림 탭 딥링크
- 기존 설치의 알림 action category 백필
- TrueDepth 권한 허용/거부, 얼굴 이탈, 어두움, 프리뷰 토글
- background, scene inactive, 전화/카메라 인터럽트 시 즉시 중지
- 실시간 요약 종료 뒤 측정값·타임라인 비영속성
- TrueDepth 미지원 기기에서 나머지 앱 정상 동작
- App Privacy Report에서 예상하지 않은 네트워크 접속 없음

현재 환경에서는 CoreDevice service가 끊겨 연결 기기를 열거하지 못했다.

### P1-2. SwiftData 저장 실패 원자성

- `SmileMomentRepository.save`는 insert 뒤 `ModelContext.save()` 실패 시 삽입을 명시적으로 취소하지 않는다.
- `SmileReminderScheduleRepository.save`는 기존 객체 필드를 바꾼 뒤 save 실패 시 원래 값을 복원하지 않는다.

같은 context의 후속 save에서 실패했다고 안내한 변경이 뒤늦게 저장될 가능성이 있다. 저장소 단위 원복이나 독립 transaction 경계와 실패 주입 테스트가 필요하다.

### P1-3. 완료 저장 실패의 재시도 UX

5초 완료 저장이 실패하면 “다시 시도해주세요”라고 표시하지만 화면에는 닫기만 있고 같은 완료를 재저장할 수 없다. 재시도 버튼을 제공하거나 실제 행동에 맞는 문구로 바꾼다.

## 5. P2 — 정리 권장

- 현재 미커밋인 iPhone 전용·세로 고정·한국어 region·Team 통일·수출 규정 설정을 검토 후 커밋
- `ITSAppUsesNonExemptEncryption = false`가 실제 암호화 사용과 수출 규정 답변에 맞는지 제출자가 최종 확인
- 설치 이름을 “SmileDay”로 유지할지 “스마일데이”로 표시할지 결정
- 첫 출시 후 build number를 업로드마다 증가시키는 규칙 기록

## 6. 개인정보·카메라 가드레일 판정

현재 구현은 제품 가드레일과 일치한다.

- 핵심 알림 → cue → 5초 → 완료 흐름은 카메라를 사용하지 않는다.
- 실시간 모드는 사용자가 “시작하기”를 누른 뒤에만 권한과 ARSession을 시작한다.
- 프리뷰는 매 세션 기본 꺼짐이며 토글로만 켠다.
- background/scene inactive/닫기에서 세션을 멈춘다.
- 입꼬리 좌우 계수, 카메라 방향, 밝기만 메모리에서 읽는다.
- `ARFrame.capturedImage`를 읽지 않고 still image 경로가 없다.
- 실시간 요약은 `SmileMoment`에 기록되지 않는다.
- Privacy manifest는 tracking false, collected data empty, UserDefaults required reason `CA92.1`이다.

카메라 사용 설명은 “화면 표시”와 “저장/전송하지 않음”을 분리해 설명한다.

## 7. 권장 출시 순서

1. 개인정보처리방침 페이지 작성 및 설정 화면 링크 추가
2. 지원 페이지와 App Store Connect 필수 메타데이터 작성
3. 현재 출시 설정 변경 검토·커밋
4. P1 저장 실패 원자성과 재시도 UX 수정
5. iPhone/TrueDepth 기기와 미지원 기기 실기기 체크리스트 수행
6. Archive → Validate → TestFlight
7. TestFlight 신규 설치·업데이트·알림·카메라·비영속성 최종 확인
8. 심사 제출

## 8. 공식 기준

- App Store Connect 앱 개인정보: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App Store Connect 앱 정보: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- App Store 버전 필수 정보: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- 스크린샷 업로드: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- 빌드 업로드: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

## 9. 다음 점검 시 갱신 규칙

- 이 문서는 `bd8fb70`과 현재 미커밋 출시 설정의 출시 준비 스냅샷이다.
- P0/P1 변경 뒤 테스트, Release Archive, 실기기, TestFlight 결과를 갱신한다.
- 새로운 전체점검을 수행하면 이 문서를 갱신하거나 더 최신 날짜 보고서로 대체하고 루트 `AGENTS.md` 링크도 함께 바꾼다.
