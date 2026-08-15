# 리마인더 추천 시간 원탭 추가 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리마인더 화면에 빈 시간대(버킷)별 추천 시각을 제시하고 원탭으로 추가할 수 있게 한다.

**Architecture:** `TimeBucket`에 `suggestedHour`(아침 9 / 낮 13 / 저녁 20)를 추가하고, `ReminderListView` 상단에 빈 버킷만 보여주는 추천 섹션을 넣는다. 추가는 기존 `SettingsViewModel.addReminder`를 그대로 쓴다.

**Tech Stack:** Swift 5.10, SwiftUI, XCTest.

**설계 문서:** `docs/superpowers/specs/2026-07-24-reminder-suggested-times-design.md`

---

### Task 1: TimeBucket.suggestedHour (CoachingKit, TDD)

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderPrompt.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가**

`ReminderPromptCatalogTests.swift`에 추가:

```swift
    func test_timeBucket_suggestedHour_valuesAndSelfContainment() {
        XCTAssertEqual(TimeBucket.morning.suggestedHour, 9)
        XCTAssertEqual(TimeBucket.afternoon.suggestedHour, 13)
        XCTAssertEqual(TimeBucket.evening.suggestedHour, 20)
        for bucket in TimeBucket.allCases {
            XCTAssertEqual(TimeBucket(hour: bucket.suggestedHour), bucket,
                           "추천 시각은 자기 버킷 범위 안에 있어야 한다")
        }
    }
```

- [ ] **Step 2: 실패 확인**

Run: `cd CoachingKit && swift test --filter ReminderPromptCatalogTests`
Expected: FAIL to build — `suggestedHour` 없음.

- [ ] **Step 3: 구현**

`ReminderPrompt.swift`의 `TimeBucket`에 추가 (displayName 아래):

```swift
    /// 빈 버킷을 원탭으로 채울 때 제시하는 기본 추천 시각(정시).
    public var suggestedHour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 13
        case .evening: 20
        }
    }
```

- [ ] **Step 4: 통과 확인**

Run: `cd CoachingKit && swift test --filter ReminderPromptCatalogTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderPrompt.swift CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift
git commit -m "feat: add suggested reminder hour per time bucket"
```

---

### Task 2: ReminderListView 추천 섹션

**Files:**
- Modify: `SmileDay/Views/Settings/ReminderListView.swift`

- [ ] **Step 1: 추천 섹션 추가**

`ReminderListView`에 계산 프로퍼티와 섹션을 추가한다. List 최상단(기존 리마인더 목록 Section 앞)에 넣는다:

```swift
    private var missingBuckets: [TimeBucket] {
        let registered = Set(viewModel.reminders.map { TimeBucket(hour: $0.hour) })
        return TimeBucket.allCases.filter { !registered.contains($0) }
    }

    // List 최상단
    if !missingBuckets.isEmpty {
        Section("추천 시간") {
            ForEach(missingBuckets, id: \.self) { bucket in
                HStack {
                    Text("\(bucket.displayName) · \(String(format: "%02d:00", bucket.suggestedHour))")
                        .font(.body.monospacedDigit())
                    Spacer()
                    Button("추가") {
                        Task { try? await viewModel.addReminder(hour: bucket.suggestedHour, minute: 0) }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(SDColor.coral, in: Capsule())
                    .buttonStyle(.borderless)
                }
            }
        }
    }
```

`addReminder`가 refresh를 호출하므로 추가된 버킷 행은 자동으로 사라진다. `.borderless`로 List 행 전체 탭을 막는다.

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Views/Settings/ReminderListView.swift
git commit -m "feat: add one-tap suggested times to reminder list"
```

---

### Task 3: 최종 검증

- [ ] **Step 1: CoachingKit 전체 테스트**

Run: `cd CoachingKit && swift test`
Expected: PASS — 전부 통과.
