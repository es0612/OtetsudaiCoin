# Issue #84 記録日カレンダー可視化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 記録画面の `.compact` DatePicker を、選択中の子どもの記録がある日を緑ドットで示すインライン月カレンダーに置換し、記録漏れ・二重登録に事前に気づけるようにする。

**Architecture:** ロジック（記録日集合の算出・月移動・日選択）は `RecordViewModel` に追加して unit-test 可能にし、表示は純プレゼンテーショナルな `RecordCalendarView`（`Presentation/Components/`）へ分離。reload は data-lifecycle 入口（`loadData`/`selectChild`/月移動/`selectDay`）にのみ集約し、write 操作内では呼ばない（#73 学び）。`Image(systemName:)` を使わず blocker を発生させない設計で component test を書く。

**Tech Stack:** SwiftUI, `@Observable` ViewModel, XCTest + ViewInspector, Core Data 経由の `HelpRecordRepository`。

**設計 spec:** `docs/superpowers/specs/2026-06-05-issue-84-recorded-days-calendar-design.md`
**Branch:** `feat/issue-84-recorded-days-calendar`（spec commit `6cecfc3` 済み）

---

## File Structure

- **Modify** `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`
  追加状態 `displayedMonth` / `recordedDays`、メソッド `loadRecordedDaysForDisplayedMonth` / `goToPreviousMonth` / `goToNextMonth` / `canGoToNextMonth` / `selectDay` / `startOfMonth`、reload trigger を `loadData` と `selectChild` 末尾に追記。
- **Create** `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift`
  月カレンダーの純表示コンポーネント。状態は引数、操作はクロージャ。
- **Modify** `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`
  `dateSection` の DatePicker を `RecordCalendarView` に置換、旧 `.onChange(of: recordedDate)` を撤去（`selectDay` 内で代替）。
- **Modify (test)** `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`
  ViewModel ロジックのテスト追加。
- **Create (test)** `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`
  コンポーネント behavior テスト。

**テスト実行コマンド（共通）:**
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:<指定> 2>&1 | tee /tmp/issue84-test.log | tail -40
```
判定は `grep -F "** TEST FAILED" /tmp/issue84-test.log` が無いこと＋ `grep -E "Test Suite .* passed|Failing tests:" /tmp/issue84-test.log` で確認（background chain の exit 0 を鵜呑みにしない — CLAUDE.md flake 学び）。

---

## Task 1: ViewModel — `recordedDays` 算出と `startOfMonth`

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`
- Test: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Write failing tests**（`RecordViewModelTests.swift` の末尾 `}` の直前、`// MARK: - #73` 群の後に追記）

```swift
    // MARK: - #84 recordedDays (記録がある日の集合)

    @MainActor
    func test_recordedDays_initiallyEmpty() {
        XCTAssertEqual(viewModel.recordedDays, [])
    }

    @MainActor
    func test_loadRecordedDays_noSelectedChild_clearsSet() {
        // Given: 何か入っている / selectedChild = nil
        viewModel.recordedDays = [1, 2, 3]
        viewModel.selectedChild = nil

        // When (selectedChild == nil は同期的に空集合化)
        viewModel.loadRecordedDaysForDisplayedMonth()

        // Then
        XCTAssertEqual(viewModel.recordedDays, [])
    }

    @MainActor
    func test_loadRecordedDays_filtersBySelectedChildAndMonth() async {
        // Given: childA の 3/5, 3/20 が対象。childB の 3/5・2月・4月 は除外。
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        let cal = Calendar.current
        func noon(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 5)),   // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 20)),  // 対象
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 5)),   // 除外(別child)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 2, 28)),  // 除外(前月)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 4, 1)),   // 除外(翌月)
        ]
        viewModel.selectedChild = childA
        viewModel.displayedMonth = RecordViewModel.startOfMonth(noon(2026, 3, 15))

        // When
        viewModel.loadRecordedDaysForDisplayedMonth()
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [5, 20] }

        // Then
        XCTAssertEqual(viewModel.recordedDays, [5, 20])
    }
```

- [ ] **Step 2: Run tests to verify they fail（コンパイルエラー必至なので red 実行は skip 可）**

`recordedDays` / `loadRecordedDaysForDisplayedMonth` / `startOfMonth` 未定義で `BUILD FAILED`。CLAUDE.md「red verification skip 条件 (a) コンパイルエラー確定」に該当するため skip。skip 理由は commit メッセージに明記。

- [ ] **Step 3: Implement**（`RecordViewModel.swift`）

`existingRecordCounts` の宣言（`var existingRecordCounts: [UUID: Int] = [:]`）の直後に追加:
```swift
    var displayedMonth: Date = RecordViewModel.startOfMonth(Date())
    var recordedDays: Set<Int> = []
```
`private var loadCountsTask: Task<Void, Never>?` の直後に追加:
```swift
    private var loadRecordedDaysTask: Task<Void, Never>?
```
`normalizeToNoon` の直前（クラス末尾の private static 群の near）に追加:
```swift
    static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    @MainActor
    func loadRecordedDaysForDisplayedMonth() {
        loadRecordedDaysTask?.cancel()

        guard let child = selectedChild else {
            recordedDays = []
            return
        }

        let cal = Calendar.current
        let monthStart = RecordViewModel.startOfMonth(displayedMonth)
        guard let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) else {
            return
        }

        loadRecordedDaysTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let records = try await self.helpRecordRepository.findByDateRange(from: monthStart, to: monthEnd)
                guard !Task.isCancelled else { return }
                let days = Set(
                    records
                        .filter { $0.childId == child.id }
                        .map { cal.component(.day, from: $0.recordedAt) }
                )
                await MainActor.run {
                    self.recordedDays = days
                }
            } catch {
                // 取得失敗は無視 (UX 影響低・既存 errorMessage を上書きしない)
            }
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordedDays_initiallyEmpty \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_loadRecordedDays_noSelectedChild_clearsSet \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_loadRecordedDays_filtersBySelectedChildAndMonth \
  2>&1 | tee /tmp/issue84-test.log | tail -40
```
Expected: PASS（`Failing tests:` 無し）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#84): recordedDays 算出と loadRecordedDaysForDisplayedMonth を追加

選択中の子ども・表示中の月に記録がある日を Set<Int> で算出。
findByDateRange + childId filter + day 抽出。取得失敗は無視 (既存 count と同方針)。
red は型未定義のコンパイルエラー確定のため skip。

Refs #84"
```

---

## Task 2: ViewModel — 月移動と日選択

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`
- Test: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Write failing tests**（Task 1 のテスト群の直後に追記）

```swift
    @MainActor
    func test_canGoToNextMonth_falseForCurrentMonth_trueForPast() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)
        XCTAssertFalse(viewModel.canGoToNextMonth(today: today))

        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        XCTAssertTrue(viewModel.canGoToNextMonth(today: today))
    }

    @MainActor
    func test_goToPreviousMonth_movesDisplayedMonthBack() {
        let cal = Calendar.current
        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        viewModel.goToPreviousMonth()

        XCTAssertEqual(
            viewModel.displayedMonth,
            cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        )
    }

    @MainActor
    func test_goToNextMonth_cappedAtCurrentMonth() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        // 過去月からは進める
        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        viewModel.goToNextMonth(today: today)
        XCTAssertEqual(viewModel.displayedMonth, cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!)

        // 今日の月で頭打ち (no-op)
        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)
        viewModel.goToNextMonth(today: today)
        XCTAssertEqual(viewModel.displayedMonth, RecordViewModel.startOfMonth(today))
    }

    @MainActor
    func test_selectDay_setsRecordedDateNoon_ignoresFuture() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)

        // 過去日は選択され noon 正規化される
        viewModel.selectDay(10, today: today)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: viewModel.recordedDate)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 10)
        XCTAssertEqual(comps.hour, 12)

        // 未来日 (16) は無視され recordedDate は 10 のまま
        viewModel.selectDay(16, today: today)
        XCTAssertEqual(cal.component(.day, from: viewModel.recordedDate), 10)
    }
```

- [ ] **Step 2: Run tests to verify they fail（コンパイルエラー確定のため skip 可）**

`canGoToNextMonth` / `goToPreviousMonth` / `goToNextMonth` / `selectDay` 未定義で `BUILD FAILED`。red skip、理由を commit に明記。

- [ ] **Step 3: Implement**（`RecordViewModel.swift`、`loadRecordedDaysForDisplayedMonth` の直後）

```swift
    func canGoToNextMonth(today: Date = Date()) -> Bool {
        displayedMonth < RecordViewModel.startOfMonth(today)
    }

    @MainActor
    func goToPreviousMonth() {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = RecordViewModel.startOfMonth(prev)
        loadRecordedDaysForDisplayedMonth()
    }

    @MainActor
    func goToNextMonth(today: Date = Date()) {
        guard canGoToNextMonth(today: today) else { return }
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = RecordViewModel.startOfMonth(next)
        loadRecordedDaysForDisplayedMonth()
    }

    @MainActor
    func selectDay(_ day: Int, today: Date = Date()) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return }
        // 未来日は無視 (View 側でも disabled だが二重防御)
        if cal.startOfDay(for: date) > cal.startOfDay(for: today) { return }
        recordedDate = RecordViewModel.normalizeToNoon(date)
        // 旧 DatePicker .onChange 相当: 選択日の per-task 件数 (#73) を更新
        loadExistingCountsForCurrentDateAndChild()
    }
```
注: `normalizeToNoon` は既存 `private static`。同クラス内なので参照可。

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_canGoToNextMonth_falseForCurrentMonth_trueForPast \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_goToPreviousMonth_movesDisplayedMonthBack \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_goToNextMonth_cappedAtCurrentMonth \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_selectDay_setsRecordedDateNoon_ignoresFuture \
  2>&1 | tee /tmp/issue84-test.log | tail -40
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#84): 月移動 (canGo/go Previous/Next) と selectDay を追加

displayedMonth を月単位で移動 (next は今日の月で頭打ち)。selectDay は noon 正規化で
recordedDate をセットし未来日を無視、per-task 件数 reload も呼ぶ (旧 DatePicker onChange 相当)。
today 注入で日付境界テストを決定的に (#112 学び)。red は型未定義で skip。

Refs #84"
```

---

## Task 3: ViewModel — reload trigger を data-lifecycle 入口に接続

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift:110`（`loadData` 末尾）と `selectChild` 末尾
- Test: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Write failing test**（Task 2 群の直後）

```swift
    @MainActor
    func test_selectChild_triggersRecordedDaysReload() async {
        let cal = Calendar.current
        func noon(_ d: Int) -> Date {
            let base = RecordViewModel.startOfMonth(Date())
            return cal.date(byAdding: DateComponents(day: d - 1, hour: 12), to: base)!
        }
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(3)),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(7)),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(9)),
        ]
        // displayedMonth は init で当月。childA を選択 → {3}
        viewModel.selectChild(childA)
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [3] }

        // When: childB に切替 → {7, 9}
        viewModel.selectChild(childB)

        // Then
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [7, 9] }
        XCTAssertEqual(viewModel.recordedDays, [7, 9])
    }
```

- [ ] **Step 2: Run test to verify it FAILS（behavioral edge case — red を必ず実行）**

reload trigger 未接続なら `selectChild(childA)` 後も `recordedDays` が空のままで `waitUntil` がタイムアウト → FAIL。CLAUDE.md「reload 経路など behavioral edge case の red は必ず実行」に従い実行する。

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_selectChild_triggersRecordedDaysReload \
  2>&1 | tee /tmp/issue84-test.log | tail -40
```
Expected: FAIL（`Failing tests:` に当該テスト、waitUntil timeout）

- [ ] **Step 3: Implement**（reload trigger 2 箇所）

`loadData()` 末尾、既存 `loadExistingCountsForCurrentDateAndChild()`（`RecordViewModel.swift:110`）の直後に 1 行追加:
```swift
                setLoading(false)
                loadExistingCountsForCurrentDateAndChild()
                loadRecordedDaysForDisplayedMonth()   // ← 追加
```

`selectChild(_:)` 末尾、既存 `loadExistingCountsForCurrentDateAndChild()`（`selectChild` 内最終行）の直後に 1 行追加:
```swift
        clearErrorMessage()
        loadExistingCountsForCurrentDateAndChild()
        loadRecordedDaysForDisplayedMonth()   // ← 追加
```

注: `recordHelp` / `recordBulkHelp` には**追加しない**。記録保存後の反映は `notifyHelpRecordUpdated()` → observer → `loadData()` → `loadRecordedDaysForDisplayedMonth()` の既存 data-lifecycle 経路で行う（CLAUDE.md「reload trigger は data-lifecycle の入り口に集約」）。

- [ ] **Step 4: Run test to verify it PASSES**

Run（Step 2 と同じコマンド）。Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#84): recordedDays reload を loadData/selectChild 末尾に接続

reload trigger を data-lifecycle 入口に集約 (#73 学び)。記録保存後は
notifyHelpRecordUpdated→observer→loadData 経路で反映するため write 操作内では呼ばない。
behavioral red を実行して reload 未接続の fail を確認済み。

Refs #84"
```

---

## Task 4: `RecordCalendarView` コンポーネント

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`

設計メモ: `Image(systemName:)` を使わない（矢印は Text `‹` `›`）ため `AccessibilityImageLabel` blocker が発生せず、`accessibilityIdentifier` ベースのテストが安定する。グリッドは週単位の `VStack`+`HStack`（最大 6×7=42 セル、perf 影響なし、ViewInspector traversal が確実）。既存 `monthCalendarHeatmap` の `LazyVGrid` から意図的に逸脱（理由＝テスト容易性）。

- [ ] **Step 1: Write failing component tests**（新規ファイル）

`app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`:
```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class RecordCalendarViewTests: XCTestCase {

    private let cal = Calendar.current

    /// 2026-06 を表示月、今日=2026-06-15 とした標準セットアップ。
    private func makeView(
        recordedDays: Set<Int> = [],
        selectedDay: Int? = nil,
        onSelectDay: @escaping (Int) -> Void = { _ in },
        onPrevMonth: @escaping () -> Void = {},
        onNextMonth: @escaping () -> Void = {},
        canGoNextMonth: Bool = false
    ) -> RecordCalendarView {
        let displayedMonth = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let selectedDate = selectedDay.flatMap {
            cal.date(from: DateComponents(year: 2026, month: 6, day: $0, hour: 12))
        } ?? cal.date(from: DateComponents(year: 2030, month: 1, day: 1))!  // 既定は表示月外
        return RecordCalendarView(
            displayedMonth: displayedMonth,
            selectedDate: selectedDate,
            recordedDays: recordedDays,
            today: today,
            canGoNextMonth: canGoNextMonth,
            onSelectDay: onSelectDay,
            onPrevMonth: onPrevMonth,
            onNextMonth: onNextMonth
        )
    }

    func test_recordDot_shownForRecordedDay_hiddenForOthers() throws {
        let view = makeView(recordedDays: [5, 20])
        let inspected = try view.inspect()
        // 記録のある日 5,20 にはドット (identifier "record_dot_<day>")
        XCTAssertNoThrow(try inspected.find(viewWithAccessibilityIdentifier: "record_dot_5"),
                         "5日のドットが見つからない")
        XCTAssertNoThrow(try inspected.find(viewWithAccessibilityIdentifier: "record_dot_20"),
                         "20日のドットが見つからない")
        // 記録の無い日 3 にはドットが無い
        XCTAssertThrowsError(try inspected.find(viewWithAccessibilityIdentifier: "record_dot_3"),
                             "3日に余計なドットがある")
    }

    func test_tapDay_callsOnSelectDayWithDay() throws {
        var tapped: Int?
        let view = makeView(onSelectDay: { tapped = $0 })
        try view.inspect().find(viewWithAccessibilityIdentifier: "calendar_day_10").button().tap()
        XCTAssertEqual(tapped, 10, "タップした 10日 が onSelectDay に渡らなかった")
    }

    func test_futureDay_buttonDisabled() throws {
        // today=6/15。16日は未来なので disabled。
        let view = makeView()
        let dayButton = try view.inspect().find(viewWithAccessibilityIdentifier: "calendar_day_16").button()
        XCTAssertTrue(try dayButton.isDisabled(), "未来日(16)が disabled になっていない")
        // 過去日 10 は enabled
        let past = try view.inspect().find(viewWithAccessibilityIdentifier: "calendar_day_10").button()
        XCTAssertFalse(try past.isDisabled(), "過去日(10)が誤って disabled")
    }

    func test_nextMonthButton_disabledWhenCannotGoNext() throws {
        let view = makeView(canGoNextMonth: false)
        let next = try view.inspect().find(viewWithAccessibilityIdentifier: "calendar_next_month").button()
        XCTAssertTrue(try next.isDisabled(), "canGoNextMonth=false で次月ボタンが disabled でない")
    }

    func test_tapPrevMonth_callsOnPrevMonth() throws {
        var called = false
        let view = makeView(onPrevMonth: { called = true })
        try view.inspect().find(viewWithAccessibilityIdentifier: "calendar_prev_month").button().tap()
        XCTAssertTrue(called, "前月ボタンのタップで onPrevMonth が呼ばれない")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail（型未定義のコンパイルエラー確定のため skip 可）**

`RecordCalendarView` 未定義で `BUILD FAILED`。red skip、理由を commit に明記。

- [ ] **Step 3: Implement**（新規ファイル）

`app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift`:
```swift
import SwiftUI

/// 記録画面の「記録日」用インライン月カレンダー。
/// 選択中の子どもの記録がある日に緑ドットを表示し、記録漏れ・二重登録に事前に気づけるようにする (#84)。
/// 純プレゼンテーショナル: 状態は引数、操作はクロージャで親 (RecordView/RecordViewModel) に委譲。
/// `Image(systemName:)` を使わず AccessibilityImageLabel blocker を避ける設計。
struct RecordCalendarView: View {
    let displayedMonth: Date      // 表示中の月 (月初アンカー)
    let selectedDate: Date        // 選択中の記録日
    let recordedDays: Set<Int>    // displayedMonth 内で記録がある日
    let today: Date               // 未来日判定の基準
    let canGoNextMonth: Bool
    let onSelectDay: (Int) -> Void
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void

    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            weekdayHeader
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 38)
                        }
                    }
                }
            }
            selectedCaption
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onPrevMonth) {
                Text("‹").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("calendar_prev_month")
            .accessibilityLabel(Text(String(localized: "前の月")))

            Spacer()
            Text(monthTitle).appFont(.sectionHeader)
            Spacer()

            Button(action: onNextMonth) {
                Text("›").font(.title2).frame(width: 44, height: 32)
                    .opacity(canGoNextMonth ? 1 : 0.3)
            }
            .disabled(!canGoNextMonth)
            .accessibilityIdentifier("calendar_next_month")
            .accessibilityLabel(Text(String(localized: "次の月")))
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption2)
                    .foregroundColor(AccessibilityColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day cell

    private func dayCell(_ day: Int) -> some View {
        let isRecorded = recordedDays.contains(day)
        let isSelected = selectedDayInDisplayedMonth == day
        let isFuture = isFutureDay(day)
        return Button {
            onSelectDay(day)
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 15))
                    .foregroundColor(dayForeground(isFuture: isFuture, isSelected: isSelected))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(AccessibilityColors.primaryBlue)
                        }
                    }
                Circle()
                    .fill(isRecorded ? AccessibilityColors.successGreen : Color.clear)
                    .frame(width: 6, height: 6)
                    .accessibilityIdentifier(isRecorded ? "record_dot_\(day)" : "")
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isFuture)
        .accessibilityIdentifier("calendar_day_\(day)")
        .accessibilityLabel(Text(dayAccessibilityLabel(day, isRecorded: isRecorded, isSelected: isSelected, isFuture: isFuture)))
    }

    private func dayForeground(isFuture: Bool, isSelected: Bool) -> Color {
        if isFuture { return AccessibilityColors.textDisabled }
        if isSelected { return .white }
        return AccessibilityColors.textPrimary
    }

    private var selectedCaption: some View {
        HStack(spacing: 6) {
            Text(String(localized: "記録日")).appFont(.secondaryInfo)
                .foregroundColor(AccessibilityColors.textSecondary)
            Text(selectedDate, format: .dateTime.year().month().day())
                .appFont(.secondaryInfo)
        }
        .padding(.top, 2)
    }

    // MARK: - Derived data

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f.string(from: displayedMonth)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols          // index 0 = Sunday
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 週ごとに分割した日番号 (前方の空白は nil)。
    private var weeks: [[Int?]] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: displayedMonth) // 1=Sun..7=Sat
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: range.map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< $0 + 7]) }
    }

    /// selectedDate が displayedMonth と同じ年月なら、その日。違えば nil (ハイライトしない)。
    private var selectedDayInDisplayedMonth: Int? {
        let d = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let m = cal.dateComponents([.year, .month], from: displayedMonth)
        return (d.year == m.year && d.month == m.month) ? d.day : nil
    }

    private func isFutureDay(_ day: Int) -> Bool {
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return false }
        return cal.startOfDay(for: date) > cal.startOfDay(for: today)
    }

    private func dayAccessibilityLabel(_ day: Int, isRecorded: Bool, isSelected: Bool, isFuture: Bool) -> String {
        let month = cal.component(.month, from: displayedMonth)
        var parts = ["\(month)\(String(localized: "月"))\(day)\(String(localized: "日"))"]
        parts.append(isRecorded ? String(localized: "記録あり") : String(localized: "記録なし"))
        if isSelected { parts.append(String(localized: "選択中")) }
        if isFuture { parts.append(String(localized: "選択できません")) }
        return parts.joined(separator: "、")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests \
  2>&1 | tee /tmp/issue84-test.log | tail -50
```
Expected: 全 5 テスト PASS。
（万一 `find(viewWithAccessibilityIdentifier:)` が VStack/HStack 階層で到達不可なら、CLAUDE.md「SwiftUI View テスト戦略」に従い `findAll(ViewType.Button.self)` でボタンを列挙し day-number Text でフィルタする方式へ切替え、assertion message に観測ボタン数を dump して原因を可視化する。）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift
git commit -m "feat(#84): RecordCalendarView コンポーネントを追加

選択中の子どもの記録がある日を緑ドット表示するインライン月カレンダー。
日タップで onSelectDay、未来日と次月(canGoNextMonth=false)は disabled、各セルに
a11y ラベル。Image(systemName:) を使わず blocker 回避、グリッドは週単位 VStack/HStack
(既存 heatmap の LazyVGrid からテスト容易性のため意図的逸脱)。red は型未定義で skip。

Refs #84"
```

---

## Task 5: `RecordView` への統合

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift:132-154`（`dateSection`）と `:149-151`（旧 onChange）

- [ ] **Step 1: 旧 `dateSection` を置換**

`RecordView.swift` の `dateSection`（現在 `HStack` + `Image(systemName: "calendar")` + `DatePicker`、132〜154 行）を以下に置換:
```swift
    private var dateSection: some View {
        RecordCalendarView(
            displayedMonth: viewModel.displayedMonth,
            selectedDate: viewModel.recordedDate,
            recordedDays: viewModel.recordedDays,
            today: Date(),
            canGoNextMonth: viewModel.canGoToNextMonth(),
            onSelectDay: { viewModel.selectDay($0) },
            onPrevMonth: { viewModel.goToPreviousMonth() },
            onNextMonth: { viewModel.goToNextMonth() }
        )
        .padding(.horizontal)
    }
```
注: 旧 `DatePicker` 内の `.onChange(of: viewModel.recordedDate) { viewModel.loadExistingCountsForCurrentDateAndChild() }` は `selectDay` 内に移したため、この置換で自然に消える（二重 reload を避ける）。`dateSection` 以外に `recordedDate` の `.onChange` が残っていないことを `grep -n "onChange(of: viewModel.recordedDate)" app/OtetsudaiCoin/Presentation/Views/RecordView.swift` で確認（0 件であること）。

- [ ] **Step 2: ビルド & 全テスト実行**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests \
  -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests \
  2>&1 | tee /tmp/issue84-test.log | tail -50
```
Expected: PASS（`** TEST FAILED` 無し）

- [ ] **Step 3: Simulator 視覚確認**（REQUIRED SUB-SKILL: `ios-simulator-app-verification`）

`--uitesting` で太郎/花子 が seed される。Record タブを開きカレンダーが表示されること、記録のある日にドット、未来日が淡色、`‹` で前月へ移動できることをスクショで確認。`selectedTab` は `@State`（永続化なし）で simctl から Record タブへ切替不可のため、確認は (a) XCUITest で `app.tabBars.buttons.element(boundBy: 1)` をタップしてスクショ、または (b) 手動確認。plan 実行者は (a) を優先し、不可なら PR description に「Record タブは手動確認推奨」と明記。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "feat(#84): RecordView の DatePicker を RecordCalendarView に置換

記録日エリアをインライン月カレンダーに。recordedDate onChange は selectDay 内へ移設し
二重 reload を回避。

Refs #84"
```

---

## Task 6: 全体テスト & PR

- [ ] **Step 1: フルテストスイート実行**（regression 確認）

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tee /tmp/issue84-full.log | tail -60
```
Expected: 全 PASS。UI/load 系が flaky に落ちたら該当を `-only-testing:` で isolated 再実行し parallel flake を切り分け（CLAUDE.md「iOS テスト flake 切り分け」）。`grep -F "** TEST FAILED" /tmp/issue84-full.log` が空であること。

- [ ] **Step 2: requesting-code-review**（REQUIRED SUB-SKILL: `superpowers:requesting-code-review`）

- [ ] **Step 3: PR 作成前チェック**（CLAUDE.md Git/PR ルール）

```bash
git status --short --branch                          # HEAD ブランチ再確認
gh pr list --head feat/issue-84-recorded-days-calendar   # 既存 PR の二重作成防止
git fetch origin && git log --oneline feat/issue-84-recorded-days-calendar..origin/main | head  # main 進行確認
```

- [ ] **Step 4: PR 作成**

```bash
gh pr create --base main --head feat/issue-84-recorded-days-calendar \
  --title "feat(#84): 記録日カレンダーで記録のある日を可視化" \
  --body "$(cat <<'EOF'
## 概要
記録画面の記録日を、選択中の子どもの記録がある日を緑ドットで示すインライン月カレンダーに置換 (#84)。記録漏れ・二重登録に登録前に気づけるようにする。

## 設計 / Plan
- spec: docs/superpowers/specs/2026-06-05-issue-84-recorded-days-calendar-design.md
- plan: docs/superpowers/plans/2026-06-05-issue-84-recorded-days-calendar.md

## 主な変更
- RecordViewModel: displayedMonth / recordedDays / loadRecordedDaysForDisplayedMonth / 月移動 / selectDay を追加。reload は data-lifecycle 入口に集約 (#73 学び)
- RecordCalendarView (Components/) を新規追加。Image(systemName:) を使わず blocker を回避
- RecordView の DatePicker を置換

## テスト
- ViewModel unit test 7 件 (記録日集合・月境界・月移動・選択・reload)
- RecordCalendarView component test 5 件 (ドット表示・タップ・未来日/次月 disabled・前月タップ)
- フルスイート PASS

## Plan からの逸脱
- (実行時に逸脱があればここに記載)

Closes #84

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review（プラン作成者によるチェック — 完了済み）

- **Spec coverage:** 受け入れ条件 8 項目すべてに対応タスクあり（カレンダー表示=T4/T5、ドット=T1/T4、未来日 disabled=T2/T4、月移動=T2/T4、タップ選択=T2/T4、記録後ドット反映=T3、a11y ラベル=T4、テスト green=T1-T6）。
- **Placeholder scan:** TODO/TBD 無し。全コードステップに実コードを記載。
- **Type consistency:** `displayedMonth`/`recordedDays`/`loadRecordedDaysForDisplayedMonth`/`canGoToNextMonth(today:)`/`goToPreviousMonth`/`goToNextMonth(today:)`/`selectDay(_:today:)`/`startOfMonth` の名称・シグネチャが ViewModel・View・テスト全タスクで一致。`RecordCalendarView` の引数（displayedMonth/selectedDate/recordedDays/today/canGoNextMonth/onSelectDay/onPrevMonth/onNextMonth）が T4 定義と T5 呼び出しで一致。accessibilityIdentifier（`calendar_day_<d>`/`record_dot_<d>`/`calendar_prev_month`/`calendar_next_month`）がコンポーネントとテストで一致。
