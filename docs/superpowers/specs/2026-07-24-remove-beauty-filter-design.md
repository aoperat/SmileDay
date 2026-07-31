# 카메라 프리뷰 뷰티 필터 제거 설계

- 날짜: 2026-07-24
- 상태: 승인됨
- 배경: 코칭 측정·베이스라인 캡처 프리뷰에 표시 전용 보정 체인(웜톤, 밝기/채도, 소프트 글로우, 비네트)이 적용되어 있다. 실제 얼굴 상태를 보면서 측정·케어하는 앱 성격상 보정된 화면은 제품 방향과 맞지 않아 전부 제거한다.

## 변경 내용

1. `SmileDay/Services/FaceBeautyFilter.swift` 삭제 — 웜톤·밝기/채도·글로우·비네트 체인 전체 제거.
2. `FilteredCameraPreviewView.update(with:)`가 원본 프레임을 그대로 그린다: `CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)`. 세로 화면용 회전과 aspect-fill 크롭은 효과가 아니라 화면 맞춤이므로 유지.
3. 이름 정리: `FilteredCameraPreviewView` → `CameraPreviewView` (파일명 포함). 참조 지점 2곳(`ARKitFaceTrackingSession.previewView`, `ARFacePreviewRepresentable`) 함께 수정.

## 대안 검토

예전 ARSCNView 프리뷰로 완전 되돌리기는 기각 — ARSession 직접 사용 구조 위에 블렌드셰이프 수집(2026-07-23)이 얹혀 있어 되돌리면 측정 경로가 깨진다. Metal 프리뷰 자체는 유지하고 필터만 제거한다.

## 검증

- 앱 빌드 성공 (`xcodebuild -sdk iphonesimulator`)
- CoachingKit 테스트 전체 통과 (필터는 표시 전용이라 측정 로직 영향 없음 — 회귀 없어야 정상)
- 시뮬레이터는 카메라 미지원이므로 실제 프리뷰 화면 확인은 실기기 수동 QA
