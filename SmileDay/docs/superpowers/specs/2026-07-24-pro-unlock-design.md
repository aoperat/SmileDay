# Pro 1회성 구매(잠금 해제) 설계

- 날짜: 2026-07-24
- 상태: 보류 — `2026-07-28-notification-smile-mvp-design.md`의 핵심 루프 검증 후 별도 수익화 설계로 재검토
- 배경: 최초 수익화 시도. 서버 없이(StoreKit만으로) 처리 가능한 비소모성(non-consumable) 1회성 구매로 시작한다. 무료 사용자도 핵심 습관 루프(첫 설정 → 미소 시간 → 기분·한 줄 기록 → 최근 7일 → 리마인더 1개)는 완결되게 두고, Pro는 습관을 오래 이어가고 좋은 순간을 다시 보는 기능만 확장한다. 결제 전환과 손익을 검증하기 전에는 유료 사용자 획득 광고를 집행하지 않는다.

## 0. 선행 조건 (2026-07-27 추가)

`2026-07-28-notification-smile-mvp-design.md`의 알림→5초 미소→완료 루프가 **구현되고 사용자 검증까지 끝나기 전에는 StoreKit 작업을 시작하지 않는다.**

이유: 이전 유료 경계(케어 루틴 전체, 시간대별 점수 상세)는 얼굴 평가 중심 가치에 기대고 있었다. 그 가치는 제품 정의에서 제거되었으므로, 같은 경계를 그대로 팔면 이제는 존재하지 않는 것을 파는 셈이 된다.

- MVP 구현 완료 + `2026-07-28-notification-smile-mvp.md`의 Task 13 검증 통과가 착수 조건이다.
- Pro는 **얼굴 상세 분석이 아니라** 미소 습관을 오래 이어가고 좋은 순간을 다시 보는 기능으로만 설명한다.
- 아래 Pro 후보 중 **최소 3개가 실제로 완성되기 전에는 판매하지 않는다.** 구현되지 않은 혜택은 페이월에 표시하지 않는다.

## 목표

1. `ProEntitlementStoring` 프로토콜과 순수 로직 게이팅 규칙을 CoachingKit에 추가해 유닛 테스트한다.
2. StoreKit2 비소모성 상품 1개(`dvelo.SmileDay.pro.unlock`)를 구매/복원할 수 있는 서비스를 앱 타겟에 추가한다.
3. 아래 §2의 무료/Pro 경계를 구현한다. 무료 핵심 루프는 절대 잠그지 않는다.
4. 잠금 해제 유도용 페이월 화면 1개를 추가한다.
5. 설치→구매 전환율과 순수취액으로 광고 허용 단가를 계산할 수 있게 출시·홍보 기준을 정의한다.

## 1. ProEntitlement (CoachingKit, 신규)

```swift
public protocol ProEntitlementStoring: AnyObject {
    var isPro: Bool { get }
}

@Observable
public final class ProEntitlement: ProEntitlementStoring {
    public private(set) var isPro: Bool
    public init(isPro: Bool = false) { self.isPro = isPro }
    public func setPro(_ value: Bool) { isPro = value }
}
```

테스트용 페이크는 별도 클래스로 만들지 않고 `ProEntitlement(isPro:)`를 그대로 사용한다(단순 값 보관 객체라 페이크가 따로 필요 없음).

## 2. 게이팅 규칙 (무료 경계)

### 무료 핵심 (절대 잠그지 않는다)

- 매일 미소 시간 — 횟수 제한 없음
- 기본 시간대 질문 (`ReminderPromptCatalog`)
- 기분 선택과 한 줄 좋은 순간 기록
- 최근 7일 활동과 이번 달 웃어본 날 캘린더
- 기본 쉬어가기 콘텐츠 (`SmilePractice.catalog`)
- 리마인더 1개

핵심 루프의 어떤 단계도 유료로 막지 않는다. 사용자가 오늘 웃어보고 그 순간을 남기는 일은 무료로 완결되어야 한다.

### Pro 후보 (최소 3개 완성 전에는 판매하지 않는다)

| 혜택 | 상태 | 비고 |
|---|---|---|
| 아침·낮·저녁 다중 리마인더 | 구현 가능 | 기존 `ReminderRepository`로 충분 |
| 전체 좋은 순간 보관함 | 미구현 | 현재는 `HistoryViewModel.recentMomentLimit`(20개)로 제한 |
| 주간 돌아보기 | 미구현 | 이미 저장하는 데이터에서 파생 |
| 추가 질문·쉬어가기 콘텐츠 팩 | 미구현 | 콘텐츠 작성 필요 |
| 사용자 지정 질문 | 미구현 | 새 저장 필드 필요 |
| 기록 내보내기 | 미구현 | |

**규칙 A — 리마인더 최대 1개 (무료)**
- `SettingsViewModel`에 `entitlement: ProEntitlementStoring` 의존성 추가.
- `public var canAddReminder: Bool { entitlement.isPro || reminders.count < 1 }`
- `addReminder(hour:minute:)`는 `canAddReminder == false`면 아무 것도 하지 않고 조용히 리턴한다(에러 던지지 않음 — UI가 버튼 자체를 페이월로 바꾸므로 이중 방어 목적).

**규칙 B — 좋은 순간 보관함 (구현 후 적용)**
- 무료는 `HistoryViewModel.recentMomentLimit`까지, Pro는 전체 기간을 본다.
- 저장은 무료·Pro 동일하다. **기록 자체를 막지 않는다** — 다시 보는 범위만 다르다.

**규칙 C — 주간 돌아보기 (구현 후 적용)**
- 새 화면이므로 구현 전에는 페이월에 표시하지 않는다.

> 삭제된 규칙: "케어 루틴 전체"와 "시간대별 점수 상세"는 얼굴 평가 중심 가치에 기대고 있어 제거했다.
> 쉬어가기 기본 콘텐츠는 전부 무료이며, 기록 화면의 시간대별 미소 시간 횟수도 무료다.

## 3. StoreKit 구매 서비스 (SmileDay 앱 타겟, 신규)

`SmileDay/Services/StoreKitProPurchaser.swift`:

```swift
import StoreKit
import CoachingKit

@MainActor
public final class StoreKitProPurchaser {
    public static let productID = "dvelo.SmileDay.pro.unlock"

    public enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    public enum PurchaseError: Error {
        case productNotFound
        case verificationFailed
    }

    private let entitlement: ProEntitlement
    private var updatesTask: Task<Void, Never>?

    public init(entitlement: ProEntitlement) {
        self.entitlement = entitlement
    }

    deinit {
        updatesTask?.cancel()
    }

    public func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
    }

    public func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                entitlement.setPro(true)
                return
            }
        }
        entitlement.setPro(false)
    }

    public func purchase() async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [Self.productID]).first else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseError.verificationFailed
            }
            await transaction.finish()
            entitlement.setPro(true)
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else { return }
        await transaction.finish()
        await refreshEntitlement()
    }
}
```

- 로컬 테스트용 StoreKit 구성 파일 `SmileDay/Configuration.storekit`에 비소모성 상품 1개(초기 검증 가격 `₩5,900`, 표시명 "SmileDay Pro")를 정의한다. 실제 가격/문구는 App Store Connect 등록 시 확정한다 — 이 파일은 시뮬레이터 테스트용 placeholder.
- `CoachingKit`은 플랫폼 무관 패키지라 StoreKit import 불가 → 이 서비스는 반드시 앱 타겟에 둔다(CoachingKit 안의 `ProEntitlement`만 참조).
- 앱 시작 시 거래 업데이트 관찰을 시작해 Ask to Buy처럼 보류 후 승인되는 거래와 앱 외부에서 갱신되는 상태를 반영한다.

## 4. 배선

- `RootView` (또는 `MainTabView` 상위)에서 `ProEntitlement()` 1개, `StoreKitProPurchaser(entitlement:)` 1개를 생성해 `.environment(_:)`로 하위에 주입하고, `.task { await purchaser.refreshEntitlement() }`로 앱 시작 시 기존 구매 여부를 복원한다.
- `SettingsViewModel`과 잠금이 적용되는 뷰모델 생성 지점(각 View의 `onAppear`)에서 environment의 `ProEntitlement`를 생성자에 전달한다.

## 5. 페이월 화면 (신규)

`SmileDay/Views/Store/ProPaywallView.swift` — 잠긴 기능을 탭했을 때 sheet로 띄운다.
- **실제로 구현된 혜택만 나열한다.** 미구현 항목은 표시하지 않는다.
- 얼굴 분석·점수·외모 개선을 유료 가치로 설명하지 않는다. "미소 습관을 오래 이어가고 좋은 순간을 다시 보기"로 설명한다.
- 자동 갱신 구독으로 오해하지 않도록 “한 번 구매로 계속 이용”을 명시
- "구매하기" 버튼 → `purchaser.purchase()` 호출. 완료 시에만 닫고, 취소는 조용히 유지하며, 보류는 “승인 대기 중”으로 안내
- "구매 복원" 버튼 → `purchaser.restore()`
- 가격 텍스트는 `Product.displayPrice`를 읽어와 하드코딩하지 않는다.

## 6. 잠금 UI 반영 지점

- `ReminderListView`: `canAddReminder == false`면 "리마인더 추가" 섹션의 버튼이 페이월을 연다(입력 필드는 비활성화 대신 숨김).
- `HistoryView`의 좋은 순간 목록: 무료 한도를 넘는 과거 항목 자리에 "Pro에서 전체 보기" 행을 둔다. 이미 보이는 항목을 가리거나 블러 처리하지 않는다.
- `SettingsView`: "Pro" 섹션 추가 — 구매 상태 표시 + 구매/복원 버튼(이미 Pro면 "Pro 활성화됨" 텍스트만).
- 쉬어가기 탭과 미소 시간 흐름에는 잠금 UI를 두지 않는다.

## 7. 가격과 수익성 검증

- 상품 유형: 비소모성 1회 구매
- 초기 검증 가격: `₩5,900`
- 가격은 코드나 사용자 문구에 하드코딩하지 않고 항상 StoreKit의 `Product.displayPrice`를 표시한다.
- §0의 선행 조건을 통과하고 Pro 후보 중 최소 3개가 완성되기 전에는 판매를 시작하지 않는다.
- `₩5,900`은 확정 영구 가격이 아니라 최초 전환 검증 가격이다. 최소 100건의 적격 설치 또는 통계적으로 판단 가능한 표본이 쌓인 뒤 `₩9,900` 후보와 함께 재검토한다.
- “할인”, “정상가”, “출시 특가”는 실제 App Store Connect 가격 이력과 종료 조건이 없는 한 표시하지 않는다.
- Small Business Program의 15% 수수료 적용 여부를 확인하기 전에는 수취액 계산에 임의로 적용하지 않는다.

광고 손익 계산:

```text
설치당 순매출(ARPI)
= Pro 실수취액 × 설치→Pro 구매 전환율

목표 광고 설치단가
<= 설치당 순매출 × 0.5
```

순매출의 최대 절반만 획득 비용으로 쓰고 나머지는 개발·지원·환불·세금 여유로 남긴다. 실제 전환율이 없는 상태에서 예상 전환율만으로 유료 광고를 시작하지 않는다.

출시 단계:

1. StoreKit 구매·복원과 실기기 안정성 검증
2. 커뮤니티·지인·콘텐츠 등 유기적 유입으로 초기 사용자 확보
3. App Store Connect에서 다운로드, 구매, 수취액, 유지율 확인
4. 설치→구매 전환율과 설치당 순매출 계산
5. 검색 광고의 실제 설치단가가 목표 광고 설치단가 이하일 때만 소액 실험

## 8. 범위 제외

- AI 해석/멘트 기능 (별도 요금제 트랙, 이번 스펙 범위 아님)
- 서버/계정/기기 간 동기화
- 구독 상품, 프로모션 코드, 패밀리 공유
- 얼굴 점수·좌우 비교·표정 상세 분석을 유료 기능으로 되살리는 일
- 무료 핵심 루프(미소 시간, 기분·한 줄 기록, 최근 7일, 기본 쉬어가기 콘텐츠)를 잠그는 일

Pro 전환율이 낮다면 기존 기능을 더 잠그기 전에 유료 가치 자체를 별도 설계한다. 후보는 주간 돌아보기, 전체 좋은 순간 보관함, 사용자 지정 질문처럼 이미 저장하는 데이터에서 파생되는 기능이다. 해당 기능은 이 문서에 즉시 끼워 넣지 않고 별도 spec↔plan 쌍으로 설계한다.

## 9. 테스트

1. `ProEntitlement`: 초기값 false, `setPro(true)` 후 true
2. `SettingsViewModel.canAddReminder`: 리마인더 0개+무료 → true / 1개+무료 → false / 1개+Pro → true
3. `SettingsViewModel.addReminder`: 무료+이미 1개 있을 때 호출해도 리마인더가 늘지 않음(조용히 무시)
4. 좋은 순간 보관함 잠금(구현 후): 무료는 `HistoryViewModel.recentMomentLimit`까지, Pro는 전체 노출. 저장 자체는 두 상태 모두 동일
5. 기존 `SettingsViewModelTests` 전체 통과(entitlement 기본값 false로 생성자 인자 추가해도 기존 동작 불변 확인)
6. 페이월에 StoreKit 가격과 “한 번 구매” 문구가 표시되고, 구매·취소·보류·복원이 앱 종료 없이 처리됨
7. App Store Connect 출시 전 상품 가격, 현지화, Paid Apps 계약, 수수료 프로그램 적용 여부를 별도 확인
