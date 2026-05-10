# 月の振り返り画面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** イシュー #19「その月の頑張りを子供と見返したい」を実装する。HomeView から開ける縦スクロールの祝祭画面（合計・ハイライトバッジ・タスク内訳・カレンダー・支払い CTA）を追加し、過去 12 ヶ月までスワイプ遷移できるようにする。

**Architecture:** ハイライト算出を純関数 `RetrospectiveHighlightService` に分離し、`MonthlyRetrospectiveViewModel` で月選択・データロード・スナップショット保持を担う。`MonthlyRetrospectiveView` が縦スクロール UI を組む。HomeView に起動ボタンを追加して `.sheet` 表示。月の表現は `Date`（その月の 1 日 0:00）として保持し `Calendar.date(byAdding: .month)` で前後遷移。

**Tech Stack:** Swift, SwiftUI, XCTest, Calendar/DateComponents

**Spec:** `docs/superpowers/specs/2026-05-10-monthly-retrospective-design.md`

**事前状態:**

- ブランチ `feat/monthly-retrospective` 作成済み
- 設計書コミット済み (`6167061`)
- main は origin/main と同期済み

---

## File Structure

### 新規ファイル

| パス | 責務 |
|---|---|
| `app/OtetsudaiCoin/Domain/Services/RetrospectiveHighlightService.swift` | 純関数: `compute(records, tasks) -> Highlights`。`Highlights` 構造体も同居 |
| `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` | 月選択 / データロード / `MonthSnapshot` 保持。`MonthSnapshot` も同居 |
| `app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift` | 縦スクロール UI 主体（ヒーロー / バッジ / 内訳 / カレンダー / CTA） |
| `app/OtetsudaiCoinTests/Domain/Services/RetrospectiveHighlightServiceTests.swift` | バッジ算出の単体テスト 7 件 |
| `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift` | ViewModel テスト 6 件 |

### 修正ファイル

| パス | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Presentation/Views/HomeView.swift` | 「📅 今月の振り返り」ボタン（既存の小アイコン群の隣）+ `@State` + `.sheet` 起動 + `prepareRetrospectiveViewModel` メソッド |

### 注意点

- プロジェクトは `PBXFileSystemSynchronizedRootGroup` を採用しているため、Xcode 手動操作は不要
- テスト destination は `iPhone 16 Pro, OS=18.5`（IPHONEOS_DEPLOYMENT_TARGET と一致）
- 既存 `AllowanceCalculator` と `UnpaidAllowanceDetectorService` を活用（新規実装しない）
- `MonthlyHistoryView` / `MonthlyHistoryViewModel` は触らない（責務を分離）

---

## Task 1: RetrospectiveHighlightService（純関数 + 7 テスト）

**目的:** 月内の `[HelpRecord]` から「最大連続日数 / 最頻日 / 最頻タスク」を算出する純関数 Service を TDD で実装。後続タスクの土台。

**Files:**

- Create: `app/OtetsudaiCoinTests/Domain/Services/RetrospectiveHighlightServiceTests.swift`
- Create: `app/OtetsudaiCoin/Domain/Services/RetrospectiveHighlightService.swift`

- [ ] **Step 1: テストファイルを新規作成（7 テスト）**

`app/OtetsudaiCoinTests/Domain/Services/RetrospectiveHighlightServiceTests.swift`:

```swift
import XCTest
@testable import OtetsudaiCoin

final class RetrospectiveHighlightServiceTests: XCTestCase {

    private var service: RetrospectiveHighlightService!

    override func setUp() {
        super.setUp()
        service = RetrospectiveHighlightService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // 共通ヘルパー: 指定の年月日の HelpRecord を作る
    private func record(year: Int, month: Int, day: Int, taskId: UUID) -> HelpRecord {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        let date = Calendar.current.date(from: comps)!
        return HelpRecord(id: UUID(), childId: UUID(), helpTaskId: taskId, recordedAt: date)
    }

    func testEmptyRecordsReturnsAllZero() {
        let result = service.compute(records: [], tasks: [])
        XCTAssertEqual(result.consecutiveDayStreak, 0)
        XCTAssertNil(result.topDay)
        XCTAssertNil(result.topTaskName)
    }

    func testSingleRecord() {
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let r = record(year: 2026, month: 5, day: 15, taskId: taskId)

        let result = service.compute(records: [r], tasks: [task])

        XCTAssertEqual(result.consecutiveDayStreak, 1)
        XCTAssertNotNil(result.topDay)
        XCTAssertEqual(result.topDay?.count, 1)
        XCTAssertEqual(result.topTaskName, "皿洗い")
    }

    func testConsecutiveStreak() {
        // 5 月 1, 2, 3, 5, 6, 7, 8 日 → 最大連続 4 日 (5-8)
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let days = [1, 2, 3, 5, 6, 7, 8]
        let records = days.map { record(year: 2026, month: 5, day: $0, taskId: taskId) }

        let result = service.compute(records: records, tasks: [task])

        XCTAssertEqual(result.consecutiveDayStreak, 4, "最大連続が 4 日でない")
    }

    func testTopDayWithTie() {
        // 5/10 と 5/20 にそれぞれ 2 件ずつ → 同件数なら最新（5/20）を返す
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 10, taskId: taskId),
            record(year: 2026, month: 5, day: 10, taskId: taskId),
            record(year: 2026, month: 5, day: 20, taskId: taskId),
            record(year: 2026, month: 5, day: 20, taskId: taskId)
        ]

        let result = service.compute(records: records, tasks: [task])

        let day = Calendar.current.component(.day, from: result.topDay!.date)
        XCTAssertEqual(day, 20, "同件数なら最新の日を返すべき")
        XCTAssertEqual(result.topDay?.count, 2)
    }

    func testTopTaskName() {
        // 皿洗い 3 件、洗濯 1 件 → 皿洗い
        let dishesId = UUID()
        let laundryId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true)
        let laundry = HelpTask(id: laundryId, name: "洗濯", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 1, taskId: dishesId),
            record(year: 2026, month: 5, day: 2, taskId: dishesId),
            record(year: 2026, month: 5, day: 3, taskId: dishesId),
            record(year: 2026, month: 5, day: 4, taskId: laundryId)
        ]

        let result = service.compute(records: records, tasks: [dishes, laundry])

        XCTAssertEqual(result.topTaskName, "皿洗い")
    }

    func testTopTaskNameWithTie() {
        // 皿洗いと洗濯が 2 件ずつ、洗濯のほうが最新の記録 → 洗濯
        let dishesId = UUID()
        let laundryId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true)
        let laundry = HelpTask(id: laundryId, name: "洗濯", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 1, taskId: dishesId),
            record(year: 2026, month: 5, day: 2, taskId: dishesId),
            record(year: 2026, month: 5, day: 10, taskId: laundryId),
            record(year: 2026, month: 5, day: 20, taskId: laundryId) // 最新
        ]

        let result = service.compute(records: records, tasks: [dishes, laundry])

        XCTAssertEqual(result.topTaskName, "洗濯", "同件数なら最新の記録のタスクを返す")
    }

    func testIgnoresAcrossMonthBoundary() {
        // 4/30 と 5/1 が連続でも、各月の最大連続は 1 日
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let records = [
            record(year: 2026, month: 4, day: 30, taskId: taskId),
            record(year: 2026, month: 5, day: 1, taskId: taskId)
        ]

        let result = service.compute(records: records, tasks: [task])

        // 月内最大連続を返す。今回は 2 月にまたがるが、各月では 1 日のみ → 1
        XCTAssertEqual(result.consecutiveDayStreak, 1, "月またぎは連続にカウントしない")
    }
}
```

- [ ] **Step 2: テスト実行で RED 確認**

```bash
xcodebuild build-for-testing -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep -E "error:|FAIL" | head -3
```

期待: `error: cannot find 'RetrospectiveHighlightService' in scope`

- [ ] **Step 3: Service を新規実装**

`app/OtetsudaiCoin/Domain/Services/RetrospectiveHighlightService.swift`:

```swift
import Foundation

struct Highlights: Equatable {
    let consecutiveDayStreak: Int
    let topDay: TopDay?
    let topTaskName: String?

    struct TopDay: Equatable {
        let date: Date
        let count: Int
    }
}

class RetrospectiveHighlightService {

    func compute(records: [HelpRecord], tasks: [HelpTask]) -> Highlights {
        guard !records.isEmpty else {
            return Highlights(consecutiveDayStreak: 0, topDay: nil, topTaskName: nil)
        }

        let cal = Calendar.current

        // 日単位にグルーピング
        let recordsByDay: [Date: [HelpRecord]] = Dictionary(grouping: records) { record in
            cal.startOfDay(for: record.recordedAt)
        }

        // 月内の最大連続日数（同月内に閉じる）
        let streak = computeMaxConsecutiveStreak(days: Array(recordsByDay.keys), calendar: cal)

        // 件数最多日（同数なら最新）
        let topDay = recordsByDay
            .map { (date: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.date > rhs.date  // 同数なら最新
            }
            .first
            .map { Highlights.TopDay(date: $0.date, count: $0.count) }

        // 件数最多タスク（同数なら最新の記録に紐づくタスク）
        let topTaskName = computeTopTaskName(records: records, tasks: tasks)

        return Highlights(
            consecutiveDayStreak: streak,
            topDay: topDay,
            topTaskName: topTaskName
        )
    }

    private func computeMaxConsecutiveStreak(days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }

        // 月単位にグルーピングしてから、各月で最大連続を計算
        let daysByMonth: [DateComponents: [Date]] = Dictionary(grouping: days) { day in
            calendar.dateComponents([.year, .month], from: day)
        }

        var globalMax = 0
        for (_, monthDays) in daysByMonth {
            let sorted = monthDays.sorted()
            var current = 1
            var localMax = 1
            for i in 1..<sorted.count {
                let prev = sorted[i - 1]
                let next = sorted[i]
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(nextDay, inSameDayAs: next) {
                    current += 1
                    localMax = max(localMax, current)
                } else {
                    current = 1
                }
            }
            globalMax = max(globalMax, localMax)
        }
        return globalMax
    }

    private func computeTopTaskName(records: [HelpRecord], tasks: [HelpTask]) -> String? {
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        let recordsByTask: [UUID: [HelpRecord]] = Dictionary(grouping: records) { $0.helpTaskId }
        let sorted = recordsByTask
            .compactMap { (taskId, recs) -> (id: UUID, count: Int, latest: Date)? in
                guard let latest = recs.map({ $0.recordedAt }).max() else { return nil }
                return (taskId, recs.count, latest)
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.latest > rhs.latest  // 同数なら最新の記録のあるタスク
            }

        guard let top = sorted.first else { return nil }
        return taskMap[top.id]?.name
    }
}
```

- [ ] **Step 4: テスト再実行で GREEN 確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RetrospectiveHighlightServiceTests 2>&1 | grep -E "TEST SUCC|TEST FAIL|failed " | head -3
```

期待: `** TEST SUCCEEDED **`、7 テスト全て PASS

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Domain/Services/RetrospectiveHighlightService.swift \
  app/OtetsudaiCoinTests/Domain/Services/RetrospectiveHighlightServiceTests.swift
git commit -m "feat: RetrospectiveHighlightService を実装 (#19)"
```

---

## Task 2: MonthlyRetrospectiveViewModel の月選択ロジック（境界含む 4 テスト）

**目的:** 月の前後遷移ロジックを TDD。データロードはまだ実装せず、selectedMonth の状態管理だけ確立。

**Files:**

- Create: `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift`
- Create: `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift`

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift`:

```swift
import XCTest
@testable import OtetsudaiCoin

final class MonthlyRetrospectiveViewModelTests: XCTestCase {

    private var viewModel: MonthlyRetrospectiveViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    private var child: Child!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()

        child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")

        viewModel = MonthlyRetrospectiveViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository
        )
    }

    override func tearDown() {
        viewModel = nil
        mockAllowancePaymentRepository = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        mockChildRepository = nil
        child = nil
        super.tearDown()
    }

    @MainActor
    func testInitialMonthIsCurrentMonth() {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.year, .month], from: Date())
        let modelComps = cal.dateComponents([.year, .month], from: viewModel.selectedMonth)

        XCTAssertEqual(modelComps.year, nowComps.year)
        XCTAssertEqual(modelComps.month, nowComps.month)
    }

    @MainActor
    func testGoToPreviousMonthDecrements() {
        let initial = viewModel.selectedMonth

        viewModel.goToPreviousMonth()

        let cal = Calendar.current
        let expected = cal.date(byAdding: .month, value: -1, to: initial)!
        let actualComps = cal.dateComponents([.year, .month], from: viewModel.selectedMonth)
        let expectedComps = cal.dateComponents([.year, .month], from: expected)

        XCTAssertEqual(actualComps.year, expectedComps.year)
        XCTAssertEqual(actualComps.month, expectedComps.month)
    }

    @MainActor
    func testCannotGoBeyondTwelveMonthsAgo() {
        // 12 回戻ってさらに 1 回戻ろうとしても変わらない
        for _ in 0..<12 {
            viewModel.goToPreviousMonth()
        }
        let twelveMonthsAgo = viewModel.selectedMonth

        viewModel.goToPreviousMonth() // 13 回目は無視されるべき

        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: viewModel.selectedMonth),
            Calendar.current.dateComponents([.year, .month], from: twelveMonthsAgo),
            "12 ヶ月前を超えて遷移してはいけない"
        )
    }

    @MainActor
    func testCannotGoToFutureMonth() {
        let initial = viewModel.selectedMonth

        viewModel.goToNextMonth() // 今月から未来へは行けない

        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: viewModel.selectedMonth),
            Calendar.current.dateComponents([.year, .month], from: initial)
        )
    }
}
```

- [ ] **Step 2: テスト実行で RED 確認**

```bash
xcodebuild build-for-testing -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep "error:" | head -3
```

期待: `error: cannot find 'MonthlyRetrospectiveViewModel' in scope`

- [ ] **Step 3: ViewModel を実装（月選択のみ、データロード後タスク）**

`app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift`:

```swift
import Foundation

@MainActor
@Observable
class MonthlyRetrospectiveViewModel {

    // MARK: - State

    /// 選択中の月（その月の 1 日 0:00 として保持）
    private(set) var selectedMonth: Date

    /// データロード後の月別スナップショット（次タスクで populate）
    private(set) var snapshot: MonthSnapshot?

    var isLoading: Bool = false

    let child: Child

    // MARK: - Dependencies

    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowancePaymentRepository: AllowancePaymentRepository

    // MARK: - Constants

    /// 過去何ヶ月まで遷移可能か（含む今月で 13 ヶ月分）
    static let maxMonthsAgo = 12

    // MARK: - Init

    init(
        child: Child,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        allowancePaymentRepository: AllowancePaymentRepository
    ) {
        self.child = child
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowancePaymentRepository = allowancePaymentRepository

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        self.selectedMonth = cal.date(from: comps) ?? Date()
    }

    // MARK: - Navigation

    func goToPreviousMonth() {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .month, value: -1, to: selectedMonth) else { return }

        guard let earliest = cal.date(byAdding: .month, value: -Self.maxMonthsAgo, to: currentMonthStart()) else { return }

        if candidate < earliest { return }

        selectedMonth = candidate
    }

    func goToNextMonth() {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .month, value: 1, to: selectedMonth) else { return }

        if candidate > currentMonthStart() { return }

        selectedMonth = candidate
    }

    // MARK: - Helpers

    private func currentMonthStart() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }
}

// MARK: - MonthSnapshot

struct MonthSnapshot: Equatable {
    let monthLabel: String
    let totalCount: Int
    let totalCoins: Int
    let taskBreakdown: [TaskBreakdownItem]
    let highlights: Highlights
    let calendar: [DailyActivity]
    let paymentStatus: PaymentStatus

    struct TaskBreakdownItem: Equatable {
        let name: String
        let count: Int
        let coinTotal: Int
    }

    struct DailyActivity: Equatable {
        let day: Int
        let count: Int
    }

    enum PaymentStatus: Equatable {
        case paid
        case unpaid
        case partiallyPaid
    }
}
```

- [ ] **Step 4: テスト再実行で GREEN 確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/MonthlyRetrospectiveViewModelTests 2>&1 | grep -E "TEST SUCC|TEST FAIL" | head -3
```

期待: `** TEST SUCCEEDED **`、4 テスト PASS

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift
git commit -m "feat: MonthlyRetrospectiveViewModel の月選択ロジック (#19)"
```

---

## Task 3: ViewModel の loadMonth でスナップショット組み立て

**目的:** 既存の `AllowanceCalculator` と新規 `RetrospectiveHighlightService` を使い、選択月のデータからスナップショットを構築する。支払い済み判定も含む。

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift`
- Modify: `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift`

- [ ] **Step 1: テストを追加**

`MonthlyRetrospectiveViewModelTests.swift` の末尾に追加：

```swift
    @MainActor
    func testLoadMonthPopulatesSnapshot() async {
        // Given: 5 月に 3 件、4 月に 1 件、各 task のセットアップ
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.dateComponents([.year, .month], from: now)
        let thisMonthStart = cal.date(from: thisMonth)!

        let dishesId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [dishes]

        // 今月の 3 日と 5 日に 1 件ずつ
        var c1 = thisMonth
        c1.day = 3
        c1.hour = 12
        var c2 = thisMonth
        c2.day = 5
        c2.hour = 12

        let r1 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!)
        let r2 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        mockHelpRecordRepository.records = [r1, r2]

        // 今月は未払い
        mockAllowancePaymentRepository.payments = []

        // When
        await viewModel.loadMonth()

        // Then
        XCTAssertNotNil(viewModel.snapshot)
        let snap = viewModel.snapshot!
        XCTAssertEqual(snap.totalCount, 2)
        XCTAssertEqual(snap.totalCoins, 200)  // 100 * 2
        XCTAssertEqual(snap.taskBreakdown.count, 1)
        XCTAssertEqual(snap.taskBreakdown.first?.name, "皿洗い")
        XCTAssertEqual(snap.taskBreakdown.first?.count, 2)
        XCTAssertEqual(snap.highlights.consecutiveDayStreak, 1) // 3 日と 5 日は非連続
        XCTAssertEqual(snap.paymentStatus, .unpaid)
        // 月ラベル
        XCTAssertTrue(snap.monthLabel.contains("\(thisMonth.year!)"))
        XCTAssertTrue(snap.monthLabel.contains("\(thisMonth.month!)"))

        _ = thisMonthStart // unused warning suppression
    }

    @MainActor
    func testPaymentStatusReflectsAllowancePayment() async {
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.dateComponents([.year, .month], from: now)

        let dishesId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [dishes]

        var c1 = thisMonth
        c1.day = 3
        c1.hour = 12
        let r1 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!)
        mockHelpRecordRepository.records = [r1]

        // 100 コイン分すでに支払い済み
        let payment = AllowancePayment(
            id: UUID(),
            childId: child.id,
            amount: 100,
            month: thisMonth.month!,
            year: thisMonth.year!,
            paidAt: Date()
        )
        mockAllowancePaymentRepository.payments = [payment]

        await viewModel.loadMonth()

        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid)
    }
```

- [ ] **Step 2: テスト実行で RED 確認**

```bash
xcodebuild build-for-testing -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep "error:" | head -3
```

期待: `error: value of type 'MonthlyRetrospectiveViewModel' has no member 'loadMonth'`

- [ ] **Step 3: loadMonth を実装**

`MonthlyRetrospectiveViewModel.swift` を更新。`init` の後 / `// MARK: - Helpers` の前に追加：

```swift
    // MARK: - Loading

    func loadMonth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allRecords = try await helpRecordRepository.findByChildId(child.id)
            let allTasks = try await helpTaskRepository.findAll()
            let allPayments = try await allowancePaymentRepository.findByChildId(child.id)

            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: selectedMonth)
            let year = comps.year ?? 0
            let month = comps.month ?? 0

            // 選択月の records だけに絞る
            let monthRecords = allRecords.filter { record in
                let rc = cal.dateComponents([.year, .month], from: record.recordedAt)
                return rc.year == year && rc.month == month
            }

            // タスク辞書（HelpHistoryViewModel パターン）
            let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })

            let totalCount = monthRecords.count
            let calculator = AllowanceCalculator()
            let totalCoins = calculator.calculateMonthlyAllowance(records: monthRecords, tasks: allTasks)

            // タスク内訳
            let breakdown = computeTaskBreakdown(records: monthRecords, taskMap: taskMap)

            // ハイライト
            let service = RetrospectiveHighlightService()
            let highlights = service.compute(records: monthRecords, tasks: allTasks)

            // カレンダー（その月の各日）
            let calendarDays = computeCalendarDays(records: monthRecords, year: year, month: month)

            // 支払い状態
            let paymentStatus = computePaymentStatus(
                payments: allPayments,
                year: year,
                month: month,
                expected: totalCoins
            )

            // 月ラベル
            let monthLabel = "\(year)年\(month)月"

            self.snapshot = MonthSnapshot(
                monthLabel: monthLabel,
                totalCount: totalCount,
                totalCoins: totalCoins,
                taskBreakdown: breakdown,
                highlights: highlights,
                calendar: calendarDays,
                paymentStatus: paymentStatus
            )
        } catch {
            self.snapshot = nil
        }
    }

    private func computeTaskBreakdown(records: [HelpRecord], taskMap: [UUID: HelpTask]) -> [MonthSnapshot.TaskBreakdownItem] {
        let groups = Dictionary(grouping: records) { $0.helpTaskId }
        return groups.compactMap { taskId, recs in
            guard let task = taskMap[taskId] else { return nil }
            return MonthSnapshot.TaskBreakdownItem(
                name: task.name,
                count: recs.count,
                coinTotal: recs.count * task.coinRate
            )
        }
        .sorted { $0.count > $1.count }
    }

    private func computeCalendarDays(records: [HelpRecord], year: Int, month: Int) -> [MonthSnapshot.DailyActivity] {
        let cal = Calendar.current
        var monthStartComps = DateComponents()
        monthStartComps.year = year
        monthStartComps.month = month
        monthStartComps.day = 1
        guard let monthStart = cal.date(from: monthStartComps),
              let range = cal.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let countsByDay: [Int: Int] = Dictionary(grouping: records) { record in
            cal.component(.day, from: record.recordedAt)
        }.mapValues { $0.count }

        return range.map { day in
            MonthSnapshot.DailyActivity(day: day, count: countsByDay[day] ?? 0)
        }
    }

    private func computePaymentStatus(
        payments: [AllowancePayment],
        year: Int,
        month: Int,
        expected: Int
    ) -> MonthSnapshot.PaymentStatus {
        let monthPayments = payments.filter { $0.year == year && $0.month == month }
        let totalPaid = monthPayments.reduce(0) { $0 + $1.amount }

        if totalPaid == 0 { return .unpaid }
        if totalPaid >= expected { return .paid }
        return .partiallyPaid
    }
```

注: `snapshot` プロパティを `private(set)` から **読み書き可能** に変更が必要。既存の `private(set) var snapshot: MonthSnapshot?` を `var snapshot: MonthSnapshot?` に修正（`@Observable` の関係上 private(set) でも内部で書けるが、明示性のため）。

- [ ] **Step 4: テスト再実行で GREEN 確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/MonthlyRetrospectiveViewModelTests 2>&1 | grep -E "TEST SUCC|TEST FAIL|failed " | head -5
```

期待: `** TEST SUCCEEDED **`、6 テスト PASS

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift
git commit -m "feat: MonthlyRetrospectiveViewModel の loadMonth でスナップショット組み立て (#19)"
```

---

## Task 4: MonthlyRetrospectiveView の UI 実装

**目的:** 縦スクロール UI を組み立て。ヒーロー / バッジ / 内訳 / カレンダー / CTA。スワイプジェスチャで前後月遷移。

**Files:**

- Create: `app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift`

- [ ] **Step 1: View ファイルを新規作成**

`app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift`:

```swift
import SwiftUI

struct MonthlyRetrospectiveView: View {
    @Bindable var viewModel: MonthlyRetrospectiveViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    if let snap = viewModel.snapshot {
                        heroSection(snap: snap)
                        highlightBadges(snap: snap)
                        taskBreakdownChart(snap: snap)
                        monthCalendarHeatmap(snap: snap)
                        if snap.paymentStatus != .paid {
                            paymentCTA(snap: snap)
                        }
                    } else if viewModel.isLoading {
                        ProgressView("読み込み中...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        Text("データがありません")
                            .appFont(.secondaryInfo)
                            .foregroundColor(AccessibilityColors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.snapshot?.monthLabel ?? "振り返り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            viewModel.goToPreviousMonth()
                            Task { await viewModel.loadMonth() }
                        } else if value.translation.width > 50 {
                            viewModel.goToNextMonth()
                            Task { await viewModel.loadMonth() }
                        }
                    }
            )
            .animation(.easeInOut, value: viewModel.selectedMonth)
        }
        .task {
            await viewModel.loadMonth()
        }
    }

    // MARK: - Sections

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(AccessibilityColors.primaryBlue)
            }
            .accessibilityIdentifier("retrospective_prev_month")

            Spacer()

            Text("\(viewModel.child.name)ちゃんの記録")
                .appFont(.sectionHeader)
                .foregroundColor(AccessibilityColors.textPrimary)

            Spacer()

            Button {
                viewModel.goToNextMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(AccessibilityColors.primaryBlue)
            }
            .accessibilityIdentifier("retrospective_next_month")
        }
    }

    private func heroSection(snap: MonthSnapshot) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack {
                    Text("\(snap.totalCount)")
                        .appFont(.appTitle)
                        .foregroundColor(AccessibilityColors.primaryBlue)
                    Text("回")
                        .appFont(.captionText)
                        .foregroundColor(AccessibilityColors.textSecondary)
                }
                VStack {
                    Text("¥\(snap.totalCoins)")
                        .appFont(.appTitle)
                        .foregroundColor(AccessibilityColors.successGreen)
                    Text("獲得")
                        .appFont(.captionText)
                        .foregroundColor(AccessibilityColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [
                        (Color(hex: viewModel.child.themeColor) ?? .blue).opacity(0.15),
                        (Color(hex: viewModel.child.themeColor) ?? .blue).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
    }

    private func highlightBadges(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ハイライト")
                .appFont(.sectionHeader)
            HStack(spacing: 12) {
                badge(icon: "flame.fill", label: "連続", value: "\(snap.highlights.consecutiveDayStreak)日", color: .orange)
                if let topDay = snap.highlights.topDay {
                    let day = Calendar.current.component(.day, from: topDay.date)
                    badge(icon: "star.fill", label: "頑張った日", value: "\(day)日 (\(topDay.count)回)", color: .yellow)
                } else {
                    badge(icon: "star.fill", label: "頑張った日", value: "—", color: .yellow)
                }
                badge(icon: "trophy.fill", label: "ベスト", value: snap.highlights.topTaskName ?? "—", color: .pink)
            }
        }
    }

    private func badge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .appFont(.captionText)
                .foregroundColor(AccessibilityColors.textSecondary)
            Text(value)
                .appFont(.captionText)
                .fontWeight(.semibold)
                .foregroundColor(AccessibilityColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func taskBreakdownChart(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お手伝い内訳")
                .appFont(.sectionHeader)
            if snap.taskBreakdown.isEmpty {
                Text("まだ記録がありません")
                    .appFont(.captionText)
                    .foregroundColor(AccessibilityColors.textSecondary)
            } else {
                ForEach(snap.taskBreakdown.indices, id: \.self) { idx in
                    let item = snap.taskBreakdown[idx]
                    let maxCount = max(snap.taskBreakdown.first?.count ?? 1, 1)
                    HStack {
                        Text(item.name)
                            .appFont(.captionText)
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AccessibilityColors.primaryBlue.opacity(0.15))
                                Rectangle()
                                    .fill(AccessibilityColors.primaryBlue)
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                            }
                            .cornerRadius(4)
                        }
                        .frame(height: 16)
                        Text("\(item.count)回")
                            .appFont(.captionText)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func monthCalendarHeatmap(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(snap.monthLabel)のカレンダー")
                .appFont(.sectionHeader)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(snap.calendar, id: \.day) { day in
                    let intensity = min(Double(day.count) / 5.0, 1.0)
                    Rectangle()
                        .fill(
                            day.count == 0
                                ? AccessibilityColors.textSecondary.opacity(0.1)
                                : AccessibilityColors.primaryBlue.opacity(0.3 + 0.7 * intensity)
                        )
                        .frame(height: 24)
                        .cornerRadius(4)
                        .overlay(
                            Text("\(day.day)")
                                .font(.system(size: 9))
                                .foregroundColor(day.count == 0 ? AccessibilityColors.textSecondary : .white)
                        )
                }
            }
        }
    }

    private func paymentCTA(snap: MonthSnapshot) -> some View {
        Button {
            // 既存の支払いフローへ繋ぐ。今回スコープでは何もしない（将来の HomeView との統合で対応）
        } label: {
            HStack {
                Image(systemName: "yensign.circle.fill")
                Text("お小遣いを渡す")
            }
        }
        .primaryGradientButton()
        .accessibilityIdentifier("retrospective_payment_cta")
    }
}
```

注: ボタン押下時の支払い実行は既存の HomeView 側に集約されているため、本イシューのスコープでは「ボタンを表示するだけ」に留める。実際の支払い実行は別 issue で議論する（YAGNI）。コメントで明記済み。

- [ ] **Step 2: ビルド確認**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep -E "BUILD|error:" | tail -5
```

期待: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift
git commit -m "feat: MonthlyRetrospectiveView の UI を実装 (#19)"
```

---

## Task 5: HomeView 統合（起動ボタン + sheet）

**目的:** HomeView の子供アバター付近に「振り返り」アイコンボタンを追加し、タップで `MonthlyRetrospectiveView` をモーダル表示する。

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/HomeView.swift`

- [ ] **Step 1: HomeView に @State と sheet を追加**

`HomeView.swift` の `@State private var monthlyHistoryViewModel: MonthlyHistoryViewModel?` の直後に追加：

```swift
    @State private var showingRetrospective = false
    @State private var retrospectiveViewModel: MonthlyRetrospectiveViewModel?
```

- [ ] **Step 2: 既存の sheet の隣に新しい sheet を追加**

`HomeView.swift` の `.sheet(isPresented: $showingMonthlyHistory) { ... }` の直後に追加：

```swift
        .sheet(isPresented: $showingRetrospective) {
            if let retroViewModel = retrospectiveViewModel {
                MonthlyRetrospectiveView(viewModel: retroViewModel)
            }
        }
```

- [ ] **Step 3: 振り返りアイコンボタンを追加**

`HomeView.swift` で `MonthlyHistory` を起動するアイコンボタン（`Image(systemName: "calendar.badge.clock")` のあるブロック）の直後に追加：

```swift
                    Button(action: {
                        DispatchQueue.main.async {
                            prepareRetrospectiveViewModel(for: child)
                            showingRetrospective = true
                        }
                    }) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    }
                    .accessibilityIdentifier("home_retrospective_button")
```

- [ ] **Step 4: prepareRetrospectiveViewModel メソッドを追加**

`HomeView.swift` の `prepareMonthlyHistoryViewModel(for:)` メソッドの直下に追加（同階層・同パターン）：

```swift
    private func prepareRetrospectiveViewModel(for child: Child) {
        let context = PersistenceController.shared.container.viewContext
        retrospectiveViewModel = MonthlyRetrospectiveViewModel(
            child: child,
            helpRecordRepository: CoreDataHelpRecordRepository(context: context),
            helpTaskRepository: CoreDataHelpTaskRepository(context: context),
            allowancePaymentRepository: InMemoryAllowancePaymentRepository.shared
        )
    }
```

注: この命名・初期化パターンは既存の `prepareMonthlyHistoryViewModel(for:)` と同じパターン。Repository の具体実装も既存箇所と同じものを使用。

- [ ] **Step 5: ビルド + 全テスト確認**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep -E "BUILD|error:" | tail -3
```

期待: `** BUILD SUCCEEDED **`

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests 2>&1 | grep "failed " | head -10
```

期待: 既知の失敗 2 件（`HomeViewTests.testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild`、`LocalizationStringCatalogTests.testAllKeysHaveEnglishTranslation`）以外、新規失敗なし

- [ ] **Step 6: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HomeView.swift
git commit -m "feat: HomeView に振り返り画面の起動ボタンを追加 (#19)"
```

---

## Task 6: 手動確認（停止ポイント）

**目的:** 自動テストでは検証できない UI 操作・体験を実機相当でチェック。

**Files:** なし

- [ ] **Step 1: シミュレータでアプリを実行**

Xcode で `iPhone 16 Pro (OS 18.5)` シミュレータで Run。

- [ ] **Step 2: 確認チェックリスト**

1. [ ] HomeView の子供セクションに ✨ アイコン（sparkles）が増えている
2. [ ] アイコンタップで振り返り画面がモーダル表示される
3. [ ] ヒーロー（合計回数 / コイン額）が表示される
4. [ ] ハイライトバッジ 3 種が表示される（記録あれば）
5. [ ] お手伝い内訳の横棒グラフが表示される
6. [ ] 月内カレンダーのヒートマップが表示される
7. [ ] 未払い月で「お小遣いを渡す」CTA が表示される
8. [ ] 支払い済み月で CTA が非表示になる
9. [ ] 左スワイプで先月へ、右スワイプで次月へ遷移する
10. [ ] 12 ヶ月以上前へは遷移できない
11. [ ] 未来月へは遷移できない
12. [ ] 「閉じる」でモーダルが閉じる

- [ ] **Step 3: 問題があれば修正コミット、なければ次タスクへ**

---

## Task 7: PR 作成

**Files:** なし

- [ ] **Step 1: ブランチを push**

```bash
git push -u origin feat/monthly-retrospective
```

- [ ] **Step 2: PR body をファイル化**

`pr-body.md` を新規作成（gitignore 済み）：

```markdown
## Summary

- HomeView に「✨ 今月の振り返り」アイコンボタンを追加
- 縦スクロールの振り返り画面（月ヒーロー / ハイライトバッジ / タスク内訳 / 月カレンダー / 支払い CTA）を新規実装
- 過去 12 ヶ月までスワイプで遷移可能、未来月は不可
- 既存 `MonthlyHistoryView` は温存（用途分離）

## 設計書・実装プラン

- 設計書: `docs/superpowers/specs/2026-05-10-monthly-retrospective-design.md`
- 実装プラン: `docs/superpowers/plans/2026-05-10-monthly-retrospective.md`

## 実装の構造

新規:
- `Domain/Services/RetrospectiveHighlightService.swift` — 純関数: 連続日数 / 最頻日 / 最頻タスク を算出
- `Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` — 月選択 + データロード + `MonthSnapshot`
- `Presentation/Views/MonthlyRetrospectiveView.swift` — 縦スクロール UI
- `Tests` 13 件（Service 7 + ViewModel 6）

修正:
- `Presentation/Views/HomeView.swift` — 起動ボタン + sheet + ViewModel 準備メソッド

不変:
- `MonthlyHistoryView` / `MonthlyHistoryViewModel` — 温存
- `AllowanceCalculator` / `UnpaidAllowanceDetectorService` — 既存ロジックを活用

## Test plan

- [x] 新規テスト 13 件 全 PASS
- [ ] シミュレータ実行: HomeView の振り返りボタン → 画面表示
- [ ] スワイプで前後月遷移、境界停止
- [ ] 未払い月で CTA 表示、支払い済み月で非表示
- [ ] ヒートマップが日別件数を反映

## 既知のテスト状況（このPRに無関係）

PR #15 / #23 / #24 でも確認済みの既存失敗：
- `HomeViewTests.testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild`
- `LocalizationStringCatalogTests.testAllKeysHaveEnglishTranslation`

Closes #19

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- [ ] **Step 3: PR 作成**

```bash
gh pr create --title "feat: 月の振り返り画面 (#19)" --body-file pr-body.md
```

- [ ] **Step 4: pr-body.md を削除**

```bash
rm pr-body.md
```

---

## Self-Review チェックリスト

### 設計書の各セクションがプランで実装されているか

- 1. 背景 → 文脈は Task 全体で対応
- 2.1 起点と画面遷移 → Task 5
- 2.2 含める要素 → Task 4
- 2.3 含めない要素 → Task 4 のコメントで明記
- 2.4 エッジケース → Task 1, 2, 3 のテスト + Task 6 の手動確認
- 3. アーキテクチャ → Task 1-5 全体
- 4. データフロー → Task 3
- 4.2 RetrospectiveHighlightService API → Task 1
- 4.3 連続日数の定義 → Task 1 (`testIgnoresAcrossMonthBoundary`)
- 5. UI 詳細 → Task 4
- 6. テスト戦略 → Task 1 (Service 7), Task 2-3 (ViewModel 6), Task 6 (手動)

### プレースホルダなし

- ✅ コード例にすべて実装入り
- ✅ 「TBD」「あとで」「TODO」表現なし
- ✅ 各 step に具体的なファイル名・コマンド・期待結果

### 型名・メソッド名の一貫性

- `RetrospectiveHighlightService` / `Highlights` / `Highlights.TopDay`: Task 1, 3
- `MonthSnapshot` / `MonthSnapshot.TaskBreakdownItem` / `MonthSnapshot.DailyActivity` / `MonthSnapshot.PaymentStatus`: Task 2, 3, 4
- `MonthlyRetrospectiveViewModel.selectedMonth` / `goToPreviousMonth()` / `goToNextMonth()` / `loadMonth()` / `snapshot`: Task 2, 3, 4
- `prepareRetrospectiveViewModel(for:)`: Task 5
- `accessibilityIdentifier` 命名: `home_retrospective_button` / `retrospective_prev_month` / `retrospective_next_month` / `retrospective_payment_cta`

---

## メモ・実装上の注意点

1. **Repository 実装の選択**: `prepareRetrospectiveViewModel` で `CoreDataHelpRecordRepository` / `CoreDataHelpTaskRepository` / `InMemoryAllowancePaymentRepository.shared` を使う。これは既存の `prepareMonthlyHistoryViewModel(for:)` と同じパターン。
2. **支払い CTA は表示のみ**: タップしても何も起こらない（YAGNI）。実際の支払い処理は HomeView 側に集約されているため、振り返り画面からの呼び出しは別 issue で議論。コード内コメントでも明記。
3. **flaky テスト警告**: 実装中に並列実行で稀に失敗する `HelpHistoryViewModelTests.testDeleteRecord` 等が出るが、単独実行で PASS することを確認すれば OK（プロジェクト既知）。
4. **markdownlint 準拠**: 設計書・プラン・PR body は MD031/032/040/060/029 を守る（前回学習済み）。
