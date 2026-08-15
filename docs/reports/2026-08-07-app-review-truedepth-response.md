# App Review 2.1 (TrueDepth) 대응 문서

- 작성일: 2026-08-07
- Submission ID: 48caefc6-152b-4d4d-a91e-1c680c730ab0
- 심사 버전: 1.0 (1)
- 반려 사유: Guideline 2.1 — Information Needed (TrueDepth API 사용 설명 요구)

## 1. 무슨 일인가

버그나 기능 반려가 아니다. **정보 요청**이다. `ARFaceTrackingConfiguration`(TrueDepth)을 쓰는 앱은
초회 제출 때 사실상 항상 이 질문을 받는다. Apple은 얼굴 데이터를 특별 취급하며(개발자 프로그램
라이선스 계약 3.3.3(C)·3.3.3(K)), 두 가지를 확인하려 한다.

1. 앱이 얼굴에서 무엇을 읽고, 어디에 쓰고, 어디에 저장하고, 누구와 공유하는가
2. **그 내용이 개인정보처리방침에 "얼굴 데이터"로 명시되어 있는가**

새 빌드는 필요 없다. App Store Connect 심사 답변(Resolution Center)에 답하면 심사가 재개된다.
단, 5번 질문("방침에서 얼굴 데이터 관련 문구를 인용하라")이 지금 상태로는 약하다 — 아래 2번을 먼저 처리한다.

## 2. 실제 코드가 하는 일 (답변의 근거)

`SmileDay/Services/ARKitLiveSmileMonitor.swift` 기준.

| 항목 | 사실 |
| --- | --- |
| 구성 | `ARFaceTrackingConfiguration`, `maximumNumberOfTrackedFaces = 1`, 광원 추정 on |
| 읽는 blend shape | `mouthSmileLeft`, `mouthSmileRight` **2개뿐** (`makeSample`) |
| 그 외 읽는 값 | `face.transform`(카메라 대비 각도 계산용), `frame.camera.transform`, `frame.lightEstimate.ambientIntensity` |
| 픽셀 | `ARFrame.capturedImage`를 읽는 경로가 **없다** |
| 얼굴 메시/깊이 맵 | 생성·사용하지 않음 |
| 저장 | `LiveSmileMonitorViewModel`에 SwiftData/UserDefaults/파일 접근 **없음** — 메모리에만 존재 |
| 전송 | 앱 전체에 네트워크 코드·서드파티 SDK 없음 |
| 미리보기 | `isShowingPreview = false` 기본값 (`LiveSmileMonitorView.swift:19`), 사용자가 켤 때만 표시 |
| 진입 | 홈의 별도 카드 → 시작 버튼. 온보딩에 없고 핵심 루프에 없음 |
| 사전 고지 | `SharedStrings.liveMonitorIntroPoints`가 시작 전에 5줄로 고지 |
| PrivacyInfo.xcprivacy | `NSPrivacyCollectedDataTypes` 비어 있음 (기기 밖으로 나가는 데이터 없음 — 일관됨) |

## 3. 조치 1 — 개인정보처리방침 3절 교체 **(2026-08-07 배포 완료)**

기존 3절은 "카메라와 실시간 확인"으로, 내용은 맞지만 **"얼굴 데이터"라는 말이 없고 TrueDepth/ARKit을
명시하지 않았다.** 리뷰어는 "face data"를 다루는 절과 그 인용문을 요구했으므로 아래 문안으로 교체했다.
`dolparo` 저장소 `smileday/privacy.html` · 커밋 `25f4ad7` · https://dolparo.com/smileday/privacy 에
반영 확인(최종 수정일 2026-08-07). 아래 인용문은 라이브 페이지와 글자 그대로 일치한다.

---

### 3. 카메라와 얼굴 데이터 (실시간 확인)

"실시간 미소 확인"은 홈 화면의 별도 카드에서 사용자가 직접 열고 시작 버튼을 눌러야만 동작하는 선택
기능입니다. 이 기능을 쓰지 않아도 알림, 5초 미소 가이드, 기록 등 나머지 기능은 모두 그대로 사용할 수
있습니다. 카메라 권한은 이 기능을 시작할 때만 요청하며, 허용하지 않아도 다른 기능은 제한되지 않습니다.

이 기능이 켜져 있는 동안 앱은 Apple의 TrueDepth 카메라와 ARKit 얼굴 추적(ARFaceTrackingConfiguration)을
사용합니다. 앱이 얼굴에서 읽는 값은 다음 세 가지뿐입니다.

- 좌우 입꼬리가 올라간 정도를 나타내는 두 개의 계수 (mouthSmileLeft, mouthSmileRight)
- 얼굴이 카메라를 향하고 있는지 안내하기 위한, 얼굴과 카메라 사이의 각도
- 화면이 너무 어두운지 알려주기 위한 주변 밝기 추정값

이 값들은 화면에 실시간 신호(0–100)와 종료 후 요약 타임라인을 보여주기 위해서만 기기의 메모리 안에서
처리됩니다. 다음 내용이 모두 적용됩니다.

- 사진, 영상, 얼굴 이미지, 깊이 맵, 얼굴 메시(3D 형상)를 만들지 않습니다. 앱은 카메라 프레임의
  픽셀(ARFrame.capturedImage)을 읽지 않습니다.
- 얼굴 인식이나 본인 인증에 사용하지 않으며, 얼굴 특징 정보(생체 템플릿)를 만들지 않습니다.
  앱은 사용자가 누구인지 알 수 없습니다.
- 감정 분석, 외모 평가, 건강 상태 판단에 사용하지 않습니다.
- 얼굴에서 읽은 값과 타임라인을 기기에 저장하지 않습니다. 파일, 사진 보관함, 데이터베이스, 설정값,
  백업, 로그 어디에도 기록하지 않습니다.
- 어떤 서버로도 전송하지 않으며, 제3자에게 제공·공유·판매하지 않습니다. 광고, 마케팅, 분석,
  인공지능 학습에 사용하지 않습니다.
- 화면을 닫거나 앱을 종료하면 해당 값은 메모리에서 사라집니다. 다시 열어도 이전 세션의 값은 남아 있지
  않습니다.

카메라 미리보기 화면은 기본적으로 꺼져 있으며, 사용자가 직접 켰을 때만 해당 세션 동안 표시됩니다.
미리보기는 화면에 보여주기만 하고 저장하거나 전송하지 않습니다.

실시간 확인이 끝난 뒤 기기에 남는 것은 "오늘 몇 번 완료했는지"에 해당하는 기록뿐이며, 여기에는
얼굴에서 읽은 값이 포함되지 않습니다. 실시간 확인을 실행하는 것만으로는 완료 횟수가 늘지 않습니다.

---

5절(외부 전송과 제3자)과 6절(보관 기간과 삭제)은 그대로 두되, 5절 마지막 문장을 다음으로 바꾼다.

> 수집하는 정보가 없으므로 제3자에게 제공하거나 판매하는 정보도 없습니다. 3절의 얼굴 데이터도
> 마찬가지로 제3자에게 제공·공유·판매하지 않습니다.

가능하면 같은 내용의 영문 페이지(`/smileday/privacy/en`)도 함께 올린다. 리뷰어가 직접 읽을 수 있으면
왕복이 한 번 줄어든다. 없어도 아래 답변에 번역을 붙이면 된다.

## 4. 조치 2 — App Store Connect 답변 (영문, 그대로 붙여넣기)

방침 페이지를 먼저 갱신한 뒤 보낸다.

---

App Store Connect 심사 답변은 4,000자 제한이 있다. 아래 본문은 3,949자다 — 문장을 더하면 넘친다.
줄바꿈과 하이픈 목록은 그대로 붙여넣어도 된다.

Thank you for the review. SmileDay's core feature — a repeating reminder to smile for about five seconds — never uses the camera. TrueDepth is used only in one optional feature, "실시간 미소 확인" (Live Smile Check), which the user opens from a separate home-screen card and starts explicitly. The app is fully usable without granting camera access.

1) Information collected via the TrueDepth API

The app runs ARFaceTrackingConfiguration (max 1 face) and reads only three values from ARFaceAnchor:
- two blend shape coefficients, mouthSmileLeft and mouthSmileRight (0.0-1.0): how far each mouth corner has risen;
- the face transform, used only for the face-to-camera angle, to prompt "please face the camera";
- ARFrame.lightEstimate.ambientIntensity, used only to warn that the room is too dark.

The app never reads ARFrame.capturedImage. No photo, video, depth map, or face mesh is produced, saved, or exported; no code path converts a frame into an image. There is no face recognition or identification, no face template or biometric identifier, and no emotion, appearance, or health analysis; the app cannot know who the user is. The live preview (ARSession rendered via ARSCNView) is off by default, display-only, enabled by the user for one session only; its pixels are never read.

2) Purpose, use, storage, retention, deletion, sharing

Purpose: in memory, the two coefficients become one 0-100 signal showing how far the mouth corners have risen from the user's own neutral measured at session start, shown live on screen. On ending, a summary shows a per-second timeline and the smiling-time ratio from the same in-memory data.
- Use: on-screen display only, during the session and its summary. Never for advertising, marketing, analytics, profiling, model training, identification, or authentication.
- Storage: none. The values exist only in RAM. Nothing derived from TrueDepth is written to SwiftData, UserDefaults, the Keychain, the file system, iCloud, backups, or logs.
- Retention and deletion: released when the summary closes or the app terminates. No history, export, or share path; reopening starts from zero.
- Sharing: none.
- Persisted: only the user's local count of completed smiles. It holds no face data, and this feature does not increment it.

3) Third parties and storage location

None, and nowhere. The app has no server or accounts, makes no network requests, contains no analytics, advertising, or third-party SDK, and works offline. Face-derived values never leave device memory, so there is no storage location to identify. This complies with Sections 3.3.3(C) and 3.3.3(K): the face data serves only the feature the user started, never advertising, marketing, or data mining, and is never shared, sold, or stored.

4) Where the privacy policy explains this

https://dolparo.com/smileday/privacy
- Section 3, "카메라와 얼굴 데이터 (실시간 확인)" (Camera and Face Data) is devoted to this. It names TrueDepth and ARKit face tracking, lists the three values, and states the purpose, no storage, no transmission, no third parties, and deletion.
- Section 5, "외부 전송과 제3자": no server, advertising, analytics, or third-party SDK, and the face data in Section 3 is likewise never shared or sold.
- Section 6, "보관 기간과 삭제": retention and deletion.

5) Quoted text on face data (Section 3)

"이 기능이 켜져 있는 동안 앱은 Apple의 TrueDepth 카메라와 ARKit 얼굴 추적(ARFaceTrackingConfiguration)을 사용합니다. (...) 얼굴에서 읽은 값과 타임라인을 기기에 저장하지 않습니다. (...) 어떤 서버로도 전송하지 않으며, 제3자에게 제공·공유·판매하지 않습니다. (...) 화면을 닫거나 앱을 종료하면 해당 값은 메모리에서 사라집니다."

English: "While this feature is running, the app uses Apple's TrueDepth camera and ARKit face tracking. (...) The values read from the face and the timeline are not stored on the device. (...) They are not transmitted to any server, and are not provided, shared, or sold to any third party. (...) When the screen is closed or the app is terminated, these values disappear from memory."

A screen recording is available on request.

## 5. 제출 전 체크리스트

- [x] 방침 페이지 3절 교체 + 5절 문장 보강, 최종 수정일 2026-08-07로 갱신
- [x] `dolparo` 저장소 커밋 `25f4ad7` → push → Vercel 배포 → 라이브 반영 확인
      (같은 커밋에 §6·§7과 고객지원 FAQ의 "앱 안에서 기록을 직접 지울 수 있습니다" 삭제가 함께 나갔다.
      앱에 개별 삭제 기능이 없어 바로잡은 것으로, 두 페이지가 어긋난 채 심사받는 것을 피했다.)
- [ ] (선택) 영문 방침 페이지 게시
- [ ] App Store Connect > 앱 개인정보(App Privacy)가 "Data Not Collected"인지 확인 —
      기기 밖으로 나가는 데이터가 없으므로 이 값이 맞다. `PrivacyInfo.xcprivacy`와도 일치한다.
- [ ] Resolution Center에 위 영문 답변 전송 (새 빌드 업로드 불필요)
- [ ] 재질문이 오면: 스크린 레코딩(실시간 확인 진입 → 사전 고지 → 시작 → 요약 → 닫으면 사라짐) 첨부
