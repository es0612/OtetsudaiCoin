# ホームビュー構成の整理 実装計画 (#57)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 似た履歴/インサイト系3ビューを2ビューに統合し、月別履歴+月の振り返りを単月+月ナビの『月のまとめ』へまとめ、ホーム統計をスリム化、支払いを集約する。

**Architecture:** 既存 `MonthlyRetrospectiveViewModel/View`（既に単月+月ナビ+snapshot+paymentStatus を保持、ただし支払いCTAはスタブ）を `MonthlySummaryViewModel/View` へ発展させ、(a) スタブの支払いCTAを実働化（旧 `MonthlyHistoryViewModel.payAllowance` ロジックを移植）、(b) ヒートマップを既存 `RecordCalendarView` に置換、(c) push 表示化。`MonthlyHistoryView/ViewModel` は削除。`HomeView` は統計4枚→2項目・入口アイコン3→ラベル2・支払いCTA撤去・未払いバナーの遷移先を差し替え。

**Tech Stack:** SwiftUI / @Observable ViewModel / Core Data リポジトリ / XCTest + ViewInspector。Xcode 16 `PBXFileSystemSynchronizedRootGroup`（新規 .swift は配置のみで認識、pbxproj 編集不要）。

設計 doc: `docs/superpowers/specs/2026-06-07-home-view-consolidation-design.md`

---

## File Structure

- Modify: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift` — `showHeader` パラメータ追加（headerless 埋め込みを可能に）
- Rename+Modify: `Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` → `MonthlySummaryViewModel.swift` — class 改名 + `payCurrentMonth()` + `initialMonth` 追加（`MonthSnapshot` は同ファイルに保持）
- Rename+Modify: `Presentation/Views/MonthlyRetrospectiveView.swift` → `MonthlySummaryView.swift` — 改名 + 支払いCTA実働化 + カレンダー置換 + push表示化
- Modify: `Presentation/Views/HomeView.swift` — 統計スリム化 / 入口2ラベル / 支払い撤去 / 未払いバナー遷移差し替え / MonthlyHistory 配線除去
- Delete: `Presentation/Views/MonthlyHistoryView.swift`, `Presentation/ViewModels/MonthlyHistoryViewModel.swift`
- Modify: `app/OtetsudaiCoin/Utils/RepositoryFactory.swift:89-95` — `createMonthlyHistoryViewModel()` 削除
- Rename+Modify: `OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift` → `MonthlySummaryViewModelTests.swift` — 改名 + `payCurrentMonth` test + 年境界ナビ test
- Delete: `OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`（または既存 .xcstrings）— 新規ラベル追加

**Green-build invariant:** 各タスク末で app/Tests 両ターゲットがコンパイルできるよう、改名タスクでは全参照を同時更新する。

---

## Task 1: RecordCalendarView に `showHeader` を追加

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift:7-36`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`RecordCalendarViewTests.swift` に追記（ローカル実行で確認したい挙動を assertion message に dump）:

```swift
@MainActor
func testShowHeaderFalseHidesMonthNavChevrons() throws {
    let cal = Calendar.current
    let month = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    let view = RecordCalendarView(
        displayedMonth: month,
        selectedDate: Date.distantPast,
        recordedDays: [],
        today: Date(),
        canGoNextMonth: false,
        showHeader: false,
        onSelectDay: { _ in },
        onPrevMonth: {},
        onNextMonth: {}
    )
    let texts = try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }
    XCTAssertFalse(texts.contains("‹"), "showHeader:false ではヘッダーの ‹ を描画しない / rendered: \(texts)")
    XCTAssertFalse(texts.contains("›"), "showHeader:false ではヘッダーの › を描画しない / rendered: \(texts)")
    XCTAssertFalse(texts.contains("記録日"), "showHeader:false では selectedCaption(記録日 + 日付) を描画しない / rendered: \(texts)")
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -scheme OtetsudaiCoin -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests/testShowHeaderFalseHidesMonthNavChevrons -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: コンパイルエラー（`showHeader:` 引数が未定義）で BUILD FAILED。

> RED 確認の skip 条件に該当（型/引数未定義の確定コンパイルエラー）。コンパイル成功後は実行して PASS を確認する。

- [ ] **Step 3: 最小実装**

`RecordCalendarView.swift` のプロパティに追加（`onNextMonth` の前、`canGoNextMonth` の後あたり）:

```swift
    let canGoNextMonth: Bool
    var showHeader: Bool = true
    let onSelectDay: (Int) -> Void
```

`body` の `header` **と** `selectedCaption` を条件化（どちらも date-picker 専用 chrome。表示専用サマリでは不要。`selectedDate` に sentinel を渡すため caption を出すと garbage 日付が見える）。`RecordCalendarView.swift:19-36` の body を差し替え:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                header
            }
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
            if showHeader {
                selectedCaption
            }
        }
    }
```

- [ ] **Step 4: テストが通ることを確認**

Run: 上記 only-testing コマンド。Expected: PASS。`-only-testing:OtetsudaiCoinTests/RecordCalendarViewTests` で既存テストも緑を確認。

- [ ] **Step 5: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift
git commit -m "feat(#57): RecordCalendarView に showHeader パラメータを追加"
```

---

## Task 2: ViewModel を MonthlySummaryViewModel へ改名 + payCurrentMonth + initialMonth

**Files:**
- Rename: `Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` → `Presentation/ViewModels/MonthlySummaryViewModel.swift`
- Modify (参照更新・緑維持): `Presentation/Views/MonthlyRetrospectiveView.swift:4`, `Presentation/Views/HomeView.swift:12,326`, `OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift`(型参照のみ)

- [ ] **Step 1: ファイルを git mv して class を改名**

```bash
git mv app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift \
       app/OtetsudaiCoin/Presentation/ViewModels/MonthlySummaryViewModel.swift
```

`MonthlySummaryViewModel.swift` の class 宣言を改名（5行目）:

```swift
class MonthlySummaryViewModel {
```

- [ ] **Step 2: init に initialMonth を追加**

`init(...)` の引数末尾に `initialMonth: Date? = nil` を追加し、`selectedMonth` の初期化を差し替え（`MonthlySummaryViewModel.swift:29-48` 相当）:

```swift
    init(
        child: Child,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        initialMonth: Date? = nil
    ) {
        self.child = child
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowancePaymentRepository = allowancePaymentRepository

        let cal = Calendar.current
        let anchor = initialMonth ?? Date()
        let comps = cal.dateComponents([.year, .month], from: anchor)
        self.selectedMonth = cal.date(from: comps) ?? anchor

        // #54: sheet/遷移直後の empty state gap を避けるため init で isLoading=true。
        self.isLoading = true
    }
```

- [ ] **Step 3a: MonthSnapshot に paidAmount を追加し loadMonth で算出**

`.partiallyPaid` で全額を二重払いしないため、既払い額をスナップショットに持たせ「残額のみ」払えるようにする（旧 `MonthlyHistoryViewModel.payUnpaidAmount` の追加分支払いに相当）。

`MonthSnapshot`（`:186-194` 相当）に `paidAmount` を追加:

```swift
struct MonthSnapshot: Equatable {
    let monthLabel: String
    let totalCount: Int
    let totalCoins: Int
    let paidAmount: Int          // 当月に既に支払い済みの合計
    let taskBreakdown: [TaskBreakdownItem]
    let highlights: Highlights
    let calendar: [DailyActivity]
    let paymentStatus: PaymentStatus
```

`loadMonth()` 内、`paymentStatus` 算出の近く（`:106-123` 相当）で既払い額を計算し snapshot に渡す:

```swift
            let monthPayments = allPayments.filter { $0.year == year && $0.month == month }
            let paidAmount = monthPayments.reduce(0) { $0 + $1.amount }

            let paymentStatus = computePaymentStatus(
                payments: allPayments,
                year: year,
                month: month,
                expected: totalCoins
            )

            let monthLabel = "\(year)年\(month)月"

            self.snapshot = MonthSnapshot(
                monthLabel: monthLabel,
                totalCount: totalCount,
                totalCoins: totalCoins,
                paidAmount: paidAmount,
                taskBreakdown: breakdown,
                highlights: highlights,
                calendar: calendarDays,
                paymentStatus: paymentStatus
            )
```

- [ ] **Step 3b: payCurrentMonth()（残額のみ支払い）を追加**

`// MARK: - Loading` の直前に追加:

```swift
    // MARK: - Payment

    /// 表示中の月の「未払い残額」を支払う。完済済みなら no-op。
    /// 既払いがある月（.partiallyPaid）は残額のみを新規 payment として保存する（全額二重払いを防ぐ）。
    /// 保存後 loadMonth で paidAmount / paymentStatus を再評価する。
    func payCurrentMonth() async {
        guard let snap = snapshot, snap.paymentStatus != .paid else { return }
        let remainder = snap.totalCoins - snap.paidAmount
        guard remainder > 0 else { return }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month else { return }
        do {
            let payment = AllowancePayment(
                id: UUID(),
                childId: child.id,
                amount: remainder,
                month: month,
                year: year,
                paidAt: Date(),
                note: "\(year)年\(month)月のお小遣い支払い"
            )
            try await allowancePaymentRepository.save(payment)
            await loadMonth()   // paidAmount/paymentStatus を再評価（loadMonth が isLoading を管理）
        } catch {
            // 保存失敗時は snapshot を維持（paymentStatus は変わらない）
        }
    }
```

> `computePaymentStatus` は複数 payment の合計で判定するため、残額を別 payment として save しても合計 == totalCoins → `.paid` に遷移する（旧 update-existing ロジックは不要）。

- [ ] **Step 4: 全参照を新名へ更新（緑維持）**

`MonthlyRetrospectiveView.swift:4` の `@Bindable var viewModel: MonthlyRetrospectiveViewModel` → `MonthlySummaryViewModel`（View 改名は Task 3。ここでは型参照のみ更新）。
`HomeView.swift:12` `@State private var retrospectiveViewModel: MonthlyRetrospectiveViewModel?` → `MonthlySummaryViewModel?`、`HomeView.swift:326` `let newViewModel = MonthlyRetrospectiveViewModel(` → `MonthlySummaryViewModel(`。
テストの型参照のみ更新（Task 4 でファイル改名するが、ここで緑にするため型名を置換）:

```bash
sed -i '' 's/MonthlyRetrospectiveViewModel/MonthlySummaryViewModel/g' \
  app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift
```

- [ ] **Step 5: ビルド確認（app + Tests がコンパイルできる）**

Run: `xcodebuild build-for-testing -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 6: コミット**

```bash
git add -A
git commit -m "refactor(#57): MonthlyRetrospectiveViewModel を MonthlySummaryViewModel へ改名し payCurrentMonth を追加"
```

---

## Task 3: View を MonthlySummaryView へ改名 + 支払いCTA実働化 + カレンダー置換 + push 表示化

**Files:**
- Rename: `Presentation/Views/MonthlyRetrospectiveView.swift` → `Presentation/Views/MonthlySummaryView.swift`
- Modify: `Presentation/Views/HomeView.swift:97`（参照名のみ。完全な配線は Task 5）

- [ ] **Step 1: ファイルを git mv して struct を改名**

```bash
git mv app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift \
       app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift
```

`MonthlySummaryView.swift:3` `struct MonthlyRetrospectiveView: View {` → `struct MonthlySummaryView: View {`。

- [ ] **Step 2: push 表示化（NavigationStack と「閉じる」を除去）**

`body`（`:7-53`）を差し替え。HomeView の NavigationStack 配下に push されるため内側 NavigationStack を外し、`navigationTitle` を月ラベルにする。スワイプの月ナビは維持:

```swift
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let snap = viewModel.snapshot {
                    heroSection(snap: snap)
                    highlightBadges(snap: snap)
                    taskBreakdownChart(snap: snap)
                    recordCalendarSection(snap: snap)
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
        .navigationTitle(viewModel.snapshot?.monthLabel ?? "月のまとめ")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { monthNavBar }
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
```

> 旧 `monthHeader`（`:57-87`、child 名表示）は `monthNavBar` に改名し safeAreaInset に置く。child 名は navigationTitle が月ラベルを持つため、ナビバーは ‹ 月 › のみにする。

- [ ] **Step 3: monthHeader → monthNavBar に置換**

`private var monthHeader: some View { ... }`（`:57-87`）を差し替え:

```swift
    private var monthNavBar: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Text("‹").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("summary_prev_month")
            .accessibilityLabel(Text(String(localized: "前の月")))

            Spacer()
            Text(viewModel.snapshot?.monthLabel ?? "").appFont(.sectionHeader)
            Spacer()

            Button {
                viewModel.goToNextMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Text("›").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("summary_next_month")
            .accessibilityLabel(Text(String(localized: "次の月")))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
```

> `Image(systemName:)` を Text("‹"/"›") に置換し AccessibilityImageLabel blocker を排除（#84 設計に揃える）。

- [ ] **Step 4: monthCalendarHeatmap → RecordCalendarView 再利用に置換**

`private func monthCalendarHeatmap(snap:)`（`:199-223`）を差し替え。`snap.calendar`（`[DailyActivity]`）から記録のある日を `Set<Int>` に変換し、headerless で `RecordCalendarView` を埋め込む:

```swift
    private func recordCalendarSection(snap: MonthSnapshot) -> some View {
        let recordedDays = Set(snap.calendar.filter { $0.count > 0 }.map { $0.day })
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(snap.monthLabel)のカレンダー")
                .appFont(.sectionHeader)
            RecordCalendarView(
                displayedMonth: viewModel.selectedMonth,
                selectedDate: Date.distantPast,   // サマリは「選択中の日」を持たないため非ハイライト
                recordedDays: recordedDays,
                today: Date(),
                canGoNextMonth: false,            // showHeader:false のため未使用
                showHeader: false,
                onSelectDay: { _ in },            // 表示専用（日タップは no-op）
                onPrevMonth: {},
                onNextMonth: {}
            )
        }
    }
```

- [ ] **Step 5: paymentCTA を実働化**

スタブ（`:225-237`）を差し替え。タップで `payCurrentMonth()` を呼ぶ:

```swift
    private func paymentCTA(snap: MonthSnapshot) -> some View {
        let remainder = snap.totalCoins - snap.paidAmount
        return Button {
            Task { await viewModel.payCurrentMonth() }
        } label: {
            HStack {
                Image(systemName: "yensign.circle.fill")
                // 既払いがある月は「追加分」、未払いは通常文言
                Text(snap.paidAmount > 0 ? "追加分のお小遣いを支払う" : "この月のお小遣いを支払う")
                Spacer()
                Text("¥\(remainder)").fontWeight(.bold)
            }
        }
        .primaryGradientButton()
        .accessibilityIdentifier("summary_payment_cta")
    }
```

- [ ] **Step 6: HomeView の View 参照を更新（緑維持）**

`HomeView.swift:97` `MonthlyRetrospectiveView(viewModel: retroViewModel)` → `MonthlySummaryView(viewModel: retroViewModel)`（完全な配線差し替えは Task 5。ここでは sheet 内の型名のみ更新してビルドを通す）。

- [ ] **Step 7: ビルド確認**

Run: `xcodebuild build-for-testing -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 8: コミット**

```bash
git add -A
git commit -m "feat(#57): MonthlySummaryView へ改名し支払いCTA実働化・カレンダー統合・push表示化"
```

---

## Task 4: ViewModel テストを改名し payCurrentMonth + 年境界ナビ test を追加

**Files:**
- Rename: `OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift` → `MonthlySummaryViewModelTests.swift`
- Modify: 同ファイル（class 改名 + テスト追加）

- [ ] **Step 1: ファイルを git mv して class を改名**

```bash
git mv app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift \
       app/OtetsudaiCoinTests/Presentation/MonthlySummaryViewModelTests.swift
```

`final class MonthlyRetrospectiveViewModelTests: XCTestCase {` → `final class MonthlySummaryViewModelTests: XCTestCase {`（型参照は Task 2 Step 4 で置換済み）。

- [ ] **Step 2: 失敗するテストを書く（payCurrentMonth + 年境界ナビ）**

クラス末尾（`}` の直前）に追加:

```swift
    @MainActor
    func testPayCurrentMonthSavesPaymentAndMarksPaid() async {
        let cal = Calendar.current
        let thisMonth = cal.dateComponents([.year, .month], from: Date())

        let dishesId = UUID()
        mockHelpTaskRepository.tasks = [HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)]

        var c1 = thisMonth; c1.day = 3; c1.hour = 12
        var c2 = thisMonth; c2.day = 5; c2.hour = 12
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!),
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        ]
        mockAllowancePaymentRepository.payments = []

        await viewModel.loadMonth()
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .unpaid, "前提: 未払い")

        await viewModel.payCurrentMonth()

        XCTAssertEqual(mockAllowancePaymentRepository.payments.count, 1, "支払いが1件保存される")
        XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.amount, 200, "金額は当月コイン合計")
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid, "再ロード後は支払い済み")
    }

    @MainActor
    func testPayCurrentMonthOnPartiallyPaidPaysOnlyRemainder() async {
        let cal = Calendar.current
        let thisMonth = cal.dateComponents([.year, .month], from: Date())

        let dishesId = UUID()
        mockHelpTaskRepository.tasks = [HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)]
        var c1 = thisMonth; c1.day = 3; c1.hour = 12
        var c2 = thisMonth; c2.day = 5; c2.hour = 12
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!),
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        ]
        // 既に 100 だけ支払い済み（期待 200 → 残額 100）
        mockAllowancePaymentRepository.payments = [
            AllowancePayment(id: UUID(), childId: child.id, amount: 100, month: thisMonth.month!, year: thisMonth.year!, paidAt: Date())
        ]

        await viewModel.loadMonth()
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .partiallyPaid, "前提: 一部支払い済み")

        await viewModel.payCurrentMonth()

        let saved = mockAllowancePaymentRepository.payments
        XCTAssertEqual(saved.count, 2, "残額分の payment が1件だけ追加される（全額二重払いしない）")
        XCTAssertEqual(saved.last?.amount, 100, "追加額は残額(200-100)のみ")
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid, "完済後は支払い済み")
    }

    // CLAUDE.md: date-math 反復弱点(#112/#114/#115)への予防線。年境界(Dec→Jan)を必ず1件。
    // 「前年12月」を起点にすると次月=今年1月で必ず現在月以下 → future-guard を通過し実行日非依存
    // （12月実行時に current month を起点にすると future-guard で blocked になる罠を回避）。
    @MainActor
    func testGoToNextMonthCrossesYearBoundary() {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        var decComps = DateComponents()
        decComps.year = currentYear - 1
        decComps.month = 12
        decComps.day = 1
        let december = cal.date(from: decComps)!

        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            initialMonth: december
        )

        vm.goToNextMonth()

        let comps = cal.dateComponents([.year, .month], from: vm.selectedMonth)
        XCTAssertEqual(comps.month, 1, "12月の次は1月")
        XCTAssertEqual(comps.year, currentYear, "前年12月 → 今年1月で年が繰り上がる (Dec→Jan)")
    }
```

- [ ] **Step 3: テストが失敗することを確認**

Run: `xcodebuild test -scheme OtetsudaiCoin -only-testing:OtetsudaiCoinTests/MonthlySummaryViewModelTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tee /tmp/t4.log; grep -E '^\*\* TEST|Failing tests:' /tmp/t4.log`
Expected: 新規3件（`testPayCurrentMonthSavesPaymentAndMarksPaid` / `testPayCurrentMonthOnPartiallyPaidPaysOnlyRemainder` / `testGoToNextMonthCrossesYearBoundary`）を実行。payCurrentMonth/initialMonth は Task2 で実装済みのため緑になる可能性が高い。緑なら behavioral 確認として扱い、`payCurrentMonth` の `save`→`loadMonth` を一時的にコメントアウトして RED を観測（paymentStatus が遷移しないこと）→ 復帰、で経路を担保する。

> 注: payCurrentMonth は副作用（save→reload で paymentStatus 遷移）を試す behavioral test のため、RED skip は不可（CLAUDE.md「behavioral edge case の red は必ず実行」）。緑で通った場合は実装をコメントアウトして一度 fail を観測し、経路（save が paymentStatus に効く）を確認する。

- [ ] **Step 4: テストが通ることを確認**

Run: 上記コマンド。Expected: `** TEST SUCCEEDED **`。log 末尾を `grep -E '^\*\* TEST|Failing tests:'` で確認（background 実行時の exit 誤読を回避、CLAUDE.md）。

- [ ] **Step 5: コミット**

```bash
git add -A
git commit -m "test(#57): MonthlySummaryViewModelTests へ改名し payCurrentMonth/年境界ナビ test を追加"
```

---

## Task 5: HomeView を整理（統計スリム化 / 入口2ラベル / 支払い撤去 / 未払いバナー遷移差し替え）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/HomeView.swift`

- [ ] **Step 1: MonthlyHistory 関連の state / sheet / helper を除去**

以下を削除:
- `:6` `@State private var showingMonthlyHistory = false`
- `:10` `@State private var monthlyHistoryViewModel: MonthlyHistoryViewModel?`
- `:90-94` `.sheet(isPresented: $showingMonthlyHistory) { ... }`
- `:315-321` `private func prepareMonthlyHistoryViewModel(for:)`

retrospective 用の sheet（`:95-99`）と state（`:11-12`）は **NavigationLink push 化**するため後続 Step で置換。

- [ ] **Step 2: childStatsView のヘッダー（アバター+3アイコン）を「アバター+名前+2ラベル導線」に置換**

`childStatsView(for:)` 内のアバター VStack（`:117-169`、`list.clipboard`/`calendar.badge.clock`/`sparkles` の3 Button を含む HStack）を次に差し替え:

```swift
            // 子供のアバター + 名前
            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: child.themeColor) ?? .blue, (Color(hex: child.themeColor) ?? .blue).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(child.name.prefix(1)))
                            .appFont(.appTitle)
                            .foregroundColor(.white)
                    )
                    .shadow(color: (Color(hex: child.themeColor) ?? .blue).opacity(0.3), radius: 8, x: 0, y: 4)

                Text("\(child.name)ちゃんの記録")
                    .appFont(.sectionHeader)
                    .foregroundColor(AccessibilityColors.textPrimary)
            }

            // 入口2つ（旧: 無地アイコン3つ）
            VStack(spacing: 8) {
                NavigationLink(destination: monthlySummaryView(for: child)) {
                    entryRow(icon: "chart.bar.doc.horizontal", title: "月のまとめ", color: Color(hex: child.themeColor) ?? .blue)
                }
                .accessibilityIdentifier("home_monthly_summary_entry")

                NavigationLink(destination: getHelpHistoryView(for: child)) {
                    entryRow(icon: "list.clipboard", title: "お手伝い履歴", color: Color(hex: child.themeColor) ?? .blue)
                }
                .accessibilityIdentifier("home_help_history_entry")
            }
```

- [ ] **Step 3: 統計カード 4枚 → 1行2項目に圧縮**

`childStatsView` 内の `LazyVGrid`（`:172-214`、4枚の StatisticsCard）を次に差し替え:

```swift
            // 統計（今月のコイン + 連続記録）
            HStack(spacing: DeviceInfo.statisticsCardSpacing) {
                StatisticsCard(
                    icon: "dollarsign.circle.fill",
                    title: "今月のコイン",
                    value: "\(viewModel.monthlyAllowance)",
                    subtitle: "コイン獲得！",
                    color: .green,
                    style: .large
                )
                StatisticsCard(
                    icon: "flame.fill",
                    title: "連続記録",
                    value: "\(viewModel.consecutiveDays)",
                    subtitle: "日連続！",
                    color: .orange,
                    style: .large
                )
            }
```

- [ ] **Step 4: 支払いセクションを撤去**

`childStatsView` 内の「お小遣い支払いセクション」`VStack(spacing: 16) { Divider() ... }`（`:216-292`）を**丸ごと削除**。これに伴い `showingPaymentConfirmation` state（`:7`）と `.alert("支払い確認", ...)`（`:100-111`）も削除（支払いは月のまとめへ集約）。

> 注: この撤去で `HomeViewModel.payMonthlyAllowance()` / `isCurrentMonthPaid` / `currentMonthEarnings` が未参照（dead code）になる。未払いバナーが使う `unpaidPeriods` / `totalUnpaidAmount` / `showUnpaidWarning` は残すこと。dead code の除去は本 PR スコープ外（YAGNI、消すなら別 commit で grep 確認の上）。PR description に「HomeViewModel に未参照メソッドが残る」と一行明記する。

- [ ] **Step 5: retrospective の sheet/state を撤去し、entryRow / monthlySummaryView ヘルパーを追加**

`:11-12` の `showingRetrospective` / `retrospectiveViewModel` state、`:95-99` の retrospective sheet、`:323-336` の `prepareRetrospectiveViewModel` を削除。代わりに `getHelpHistoryView` の隣に追加:

```swift
    private func monthlySummaryView(for child: Child) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository()
        )
        return MonthlySummaryView(viewModel: vm)
            .onAppear { Task { await vm.loadMonth() } }
    }

    private func monthlySummaryView(for child: Child, initialMonth: Date) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository(),
            initialMonth: initialMonth
        )
        return MonthlySummaryView(viewModel: vm)
            .onAppear { Task { await vm.loadMonth() } }
    }

    @ViewBuilder
    private func entryRow(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(title).appFont(.sectionHeader).foregroundColor(AccessibilityColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(AccessibilityColors.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
```

- [ ] **Step 6: 未払いバナーの遷移先を月のまとめへ差し替え**

`unpaidWarningBanner` 内の「支払い履歴を確認」Button（`:432-460`）を NavigationLink へ置換。未払い期間の月を `initialMonth` に渡す:

```swift
                if let targetChild = viewModel.selectedChild
                    ?? viewModel.unpaidPeriods.first.flatMap({ period in
                        viewModel.children.first { $0.id == period.childId }
                    }) {
                    let initialMonth = unpaidInitialMonth() ?? Date()
                    NavigationLink(destination: monthlySummaryView(for: targetChild, initialMonth: initialMonth)) {
                        HStack(spacing: 6) {
                            Text("お小遣いを確認")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right").font(.caption)
                        }
                        .foregroundColor(AccessibilityColors.warningOrange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AccessibilityColors.warningOrange.opacity(0.15))
                        )
                    }
                    .accessibilityIdentifier("home_unpaid_summary_link")
                }
```

`HomeView` に補助関数を追加（`UnpaidPeriod` の month/year から月初 Date を作る。`UnpaidPeriod` のプロパティ名は実装に合わせる。`month`/`year` が無ければ既存 `monthYearString` 等から導出するか current month にフォールバック）:

```swift
    private func unpaidInitialMonth() -> Date? {
        guard let period = viewModel.unpaidPeriods.first else { return nil }
        var comps = DateComponents()
        comps.year = period.year
        comps.month = period.month
        comps.day = 1
        return Calendar.current.date(from: comps)
    }
```

> 実装時に `UnpaidPeriod` の正確なプロパティ（`year`/`month` の有無）を `grep -n "struct UnpaidPeriod" -A15` で確認する。プロパティが異なる場合は current month フォールバック（`?? Date()`）で UX を維持しつつ最小修正にする。

- [ ] **Step 7: ビルド確認**

Run: `xcodebuild build-for-testing -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: BUILD SUCCEEDED（MonthlyHistory はまだ存在するが未参照でも可）。

- [ ] **Step 8: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HomeView.swift
git commit -m "feat(#57): HomeView を統計スリム化・入口2ラベル・支払い集約へ整理"
```

---

## Task 6: MonthlyHistoryView / ViewModel / factory / テストを削除

**Files:**
- Delete: `Presentation/Views/MonthlyHistoryView.swift`, `Presentation/ViewModels/MonthlyHistoryViewModel.swift`, `OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Utils/RepositoryFactory.swift:89-95`

- [ ] **Step 1: ファイル削除と factory メソッド除去**

```bash
git rm app/OtetsudaiCoin/Presentation/Views/MonthlyHistoryView.swift \
       app/OtetsudaiCoin/Presentation/ViewModels/MonthlyHistoryViewModel.swift \
       app/OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift
```

`RepositoryFactory.swift:89-95` の `func createMonthlyHistoryViewModel() -> MonthlyHistoryViewModel { ... }` を削除。

- [ ] **Step 2: 残存参照ゼロを3ターゲットで確認**

Run:
```bash
grep -rn "MonthlyHistoryView\|MonthlyHistoryViewModel\|createMonthlyHistoryViewModel\|showingMonthlyHistory\|prepareMonthlyHistoryViewModel" \
  app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests | grep -v "build/"
```
Expected: 出力なし（0 件）。

- [ ] **Step 3: ビルド + 全テスト確認**

Run: `xcodebuild test -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tee /tmp/t6.log; grep -E '^\*\* TEST|Failing tests:' /tmp/t6.log`
Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 4: コミット**

```bash
git add -A
git commit -m "refactor(#57): MonthlyHistoryView/ViewModel と factory・テストを削除"
```

---

## Task 7: 新規ラベルを String Catalog へ追加

**Files:**
- Modify: 既存 `.xcstrings`（`find app -name '*.xcstrings' -not -path '*build*'` で特定）

- [ ] **Step 1: 追加キーを洗い出す**

本変更で新規追加した user-facing 文字列: `"月のまとめ"`, `"この月のお小遣いを支払う"`, `"お小遣いを確認"`, `"○○のカレンダー"`（既存 `"\(snap.monthLabel)のカレンダー"` は既存キー）, ナビ用 `"前の月"`/`"次の月"`（RecordCalendarView と共有、既存の可能性大）。`"お手伝い履歴"` は既存。

- [ ] **Step 2: xcstrings へ追加（[[xcstrings-bulk-update]] の手順厳守）**

`String Catalog` を直接編集する場合は Xcode の `" : "` 整形を壊さないよう注意。en 翻訳も同時に付与（en locale 絵文字なし）。例: `"月のまとめ"` → en `"Monthly Summary"`, `"この月のお小遣いを支払う"` → en `"Pay this month's allowance"`, `"お小遣いを確認"` → en `"Review allowance"`。

> 既存キーと重複しないか `grep -F '"月のまとめ"' <xcstrings>` で確認してから追加。

- [ ] **Step 3: ローカライズテスト確認**

Run: `xcodebuild test -scheme OtetsudaiCoin -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | grep -E '^\*\* TEST|Failing tests:'`
Expected: `** TEST SUCCEEDED **`（missing English translation なし）。

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/**/*.xcstrings
git commit -m "i18n(#57): 月のまとめ関連の新規ラベルを追加"
```

---

## Task 8: 最終検証（視覚 + 全テスト + grep）

**Files:** なし（検証のみ）

- [ ] **Step 1: 全テスト suite を実行**

Run: `xcodebuild test -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tee /tmp/t8.log; grep -E '^\*\* TEST|Failing tests:' /tmp/t8.log`
Expected: `** TEST SUCCEEDED **`。flake が出たら `-only-testing:` で該当テストを isolated 再実行（CLAUDE.md「iOS テスト flake 切り分け」）。

- [ ] **Step 2: 視覚検証（capture script 流用、ja/en）**

Run: `./scripts/capture-asc-screenshots.sh` を実行し、`docs/screenshots/asc/v1.1.x/{ja,en}/01-home.png` を Read で目視。ホームが「アバター+名前 / 統計2項目 / 入口2ラベル / 未払いバナー」になっていることを確認。
> 出力は ASC artifact なので **目視後に `git checkout -- docs/screenshots/` で discard**（feature PR に混ぜない、CLAUDE.md）。月のまとめは `selectedTab=@State` で simctl からは到達不可のため、簡易には XCUITest か手動確認に委ねる（PR description に明記）。

- [ ] **Step 3: 削除シンボルの最終 grep（3ターゲット）**

Run:
```bash
grep -rn "MonthlyHistory\|MonthlyRetrospective\|showingMonthlyHistory\|showingRetrospective" \
  app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests | grep -v "build/"
```
Expected: 出力なし（旧名の残存ゼロ）。

- [ ] **Step 4: PR 作成**

`gh pr list --head feat/issue-57-home-consolidation` で既存 PR を確認 → 無ければ `gh pr create`。description に: 設計 doc へのリンク、Plan からの逸脱（あれば）、未払いバナー initialMonth の `UnpaidPeriod` プロパティ確認結果、視覚検証の範囲（月のまとめは手動確認）を明記。

---

## Self-Review（記入済み）

- **Spec coverage:** spec §4.1（新ホーム）→ Task5 / §4.2（月のまとめ）→ Task2,3 / §4.3（履歴据え置き）→ 変更なし（Task5 で入口のみ） / §4.4（支払い集約）→ Task2,3,5 / §5（アーキ）→ Task1-3 / §6（テスト・年境界）→ Task1,4 / §7（移行・削除 grep）→ Task6,8 / §8（スコープ外）→ 触れない。全カバー。
- **Placeholder scan:** 各コードステップに実コードを記載済み。`UnpaidPeriod` のプロパティのみ実装時 grep 確認の注記（フォールバック付き）= 既知の不確定点として明示。
- **Type consistency:** `MonthlySummaryViewModel` / `MonthlySummaryView` / `payCurrentMonth()` / `initialMonth` / `showHeader` / `recordCalendarSection` / `monthNavBar` / `entryRow` / `monthlySummaryView(for:)` / `MonthSnapshot.paidAmount` を全タスクで一貫使用。`AllowancePayment` init 引数（id/childId/amount/month/year/paidAt/note）は実ファイル準拠。
- **Advisor 指摘の反映（実行前修正）:** (1) `payCurrentMonth` は `.partiallyPaid` で全額二重払いせず**残額のみ**支払う（`paidAmount` 追加、Task2 Step3a/3b・Task4 部分支払い test）。(2) 年境界 test は「前年12月」固定アンカーで12月実行時の future-guard flake を回避（Task4）。(3) `showHeader:false` は `header` だけでなく `selectedCaption` も gate し distantPast の garbage 日付描画を防ぐ（Task1）。
