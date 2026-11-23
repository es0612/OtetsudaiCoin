# #311 ホームの「今月のコイン」と「連続記録」 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ホームの「今月のコイン」を常に今月の稼ぎにし、「連続記録」を今日未記録でも昨日までの連続を出して月・年をまたいで数えるようにする。

**Architecture:** 連続日数の数え方は `AllowanceCalculator.calculateConsecutiveDays` に閉じ、`today` を引数で受ける。`HomeViewModel.refreshData` は、今月のコインには今までどおり今月の記録を、連続日数には `findByChildId` で取った子どもの全記録を渡す。支払いの行は表示に使わない。

**Tech Stack:** Swift / XCTest

**Spec:** `docs/superpowers/specs/2026-11-23-issue-311-home-coins-streak-design.md`（オーナー承認 2026-11-23）

## Global Constraints

- 今月のコイン = 今月稼いだコイン（`calculatedAllowance`）。支払いの行の額・合計は表示に使わない
- 連続記録: 記録のある日の最新が今日なら今日から、昨日なら昨日からさかのぼって途切れるまで数える。それ以外は 0。月・年をまたぐ
- 連続日数に渡す記録は `helpRecordRepository.findByChildId(child.id)` の全記録（案 ①）。今月のコインの計算は `findByChildIdInCurrentMonth` のまま
- `isCurrentMonthPaid` と今月の支払いの取得、`payMonthlyAllowance` / `recordAllowancePayment` は残す（削除は別 issue）
- アンチゴール: 月のまとめの数字が変わる／ja・en の文言が変わる。カードの見た目は変えない
- テストの日付は `Calendar.current` + `DateComponents`（正午 12 時）で固定日を作る。`Date()` 相対の fixture を新しく足さない（project skill `running-xcodebuild-tests-and-date-fixtures`）
- `UNIT_CMD` = `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination "id=3550EFAB-40E6-4DD9-9DFD-CDCA46200861" -parallel-testing-enabled NO -only-testing:OtetsudaiCoinTests`（絞るときは `-only-testing:OtetsudaiCoinTests/<Class>`）。main の時点で 632 件。合否は `** TEST SUCCEEDED **` の行で判定

## Review Focus

1. **毎月 1 日の朝（今月の記録 0 件）**: 先月末まで続いていれば、その連続日数が出る。`refreshData` の「記録もタスクも空」の早期分岐でも全記録が連続日数の計算に渡る → Task 2 のテスト
2. **今月の支払いが複数行**（追加払い・おまけ付き）: 今月のコインは稼ぎのまま。行の額・合計のどれも出ない → Task 2 のテスト（fixture は 300 / 200・50）
3. **同じ日に複数回記録**: 1 日として数える（2 回記録で 2 日にならない） → Task 1 のテスト
4. **記録の並び順がばらばら**（リポジトリが日付順で返さない）: 連続日数は同じ → Task 1 のテスト
5. **年またぎ**（12/30〜1/1）: 3 → Task 1 のテスト

---

### Task 1: 連続日数の数え方（今日未記録でも続く・`today` を受ける）

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/AllowanceCalculator.swift:16-44`
- Modify: `app/OtetsudaiCoinTests/Domain/AllowanceCalculatorTests.swift`（`testCalculateConsecutiveDaysWithoutToday` `:107-118` を含む）
- Modify: `app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift` の `MockAllowanceCalculator`（`:388-404`。override の形を合わせるだけ）

**Interfaces:**
- Produces: `func calculateConsecutiveDays(records: [HelpRecord], today: Date = Date()) -> Int`。既存の呼び出し `calculateConsecutiveDays(records:)` はそのまま動く
- `MockAllowanceCalculator` は `override func calculateConsecutiveDays(records: [HelpRecord], today: Date) -> Int` で `consecutiveDays` を返し、受け取った records を `var receivedConsecutiveDaysRecords: [HelpRecord]?` に残す（Task 2 が使う）

- [ ] **Step 1: 失敗するテストを書く**

日付は `day(_ y: Int, _ m: Int, _ d: Int) -> Date`（正午）のヘルパーで作る。

```swift
func testConsecutiveDays_crossesMonth_countsFromToday()       // 10/30,10/31,11/1,11/2 / today 11/2 → 4
func testConsecutiveDays_todayNotRecorded_countsFromYesterday() // 同じ記録 / today 11/3 → 4
func testConsecutiveDays_lastRecordTwoDaysAgo_isZero()        // 同じ記録 / today 11/4 → 0
func testConsecutiveDays_crossesYear()                        // 12/30,12/31,1/1 / today 1/1 → 3
func testConsecutiveDays_sameDayTwice_countsOnce()            // 11/1 に 2 件・11/2 に 1 件 / today 11/2 → 2
func testConsecutiveDays_unsortedRecords()                    // 11/2,10/31,11/1 の順 / today 11/2 → 3
```

既存 `testCalculateConsecutiveDaysWithoutToday`（昨日だけ → 0）は `testCalculateConsecutiveDaysYesterdayOnly` に改名し、期待値を 1 にして「#311: 今日未記録でも昨日までの連続を出す」とコメントする。

- [ ] **Step 2: RED を確かめる**

Run: `UNIT_CMD` を `-only-testing:OtetsudaiCoinTests/AllowanceCalculatorTests` に絞る
Expected: `today:` 引数が無いので BUILD FAILED。これだけでは挙動の RED にならないので、先に引数だけ足して（判定は「最新が今日でなければ 0」のまま）一度流す。Expected: `** TEST FAILED **` で、落ちるのは `testConsecutiveDays_todayNotRecorded_countsFromYesterday`（0 になる）と `testCalculateConsecutiveDaysYesterdayOnly`（0 になる）の 2 本。ほかの 5 本は今の判定でも通る（月・年またぎ・同じ日・順不同は記録を全部渡せば今の実装でも数えられ、2 日前が最後なら今も 0 のため）。その後に判定を直す

- [ ] **Step 3: `calculateConsecutiveDays(records:today:)` を実装する**

最新の記録日が `today` と同じ日、または `today` の前日なら、その日から 1 日ずつさかのぼって数える。日の比較は `Calendar.current` の `startOfDay` / `isDate(_:inSameDayAs:)`。`MockAllowanceCalculator` の override も新しい形にする。

- [ ] **Step 4: GREEN を確かめる**

Run: Step 2 と同じ → `** TEST SUCCEEDED **`。続けて `UNIT_CMD` 全件 → `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Services/AllowanceCalculator.swift app/OtetsudaiCoinTests/Domain/AllowanceCalculatorTests.swift app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift
git commit -m "fix(#311): 連続記録を今日未記録でも昨日までの日数で数え、月・年をまたぐ"
```

本文に Step 2 の RED の内容を書く。

---

### Task 2: ホームの表示値（今月のコインは稼ぎ・連続は全記録から）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/HomeViewModel.swift:118-192`（`refreshData` と `updateDisplayValues`）
- Modify: `app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1 の `calculateConsecutiveDays(records:today:)` と `MockAllowanceCalculator.receivedConsecutiveDaysRecords`
- Produces: `updateDisplayValues(records:tasks:payment:allRecords:)`（private。`allRecords` が連続日数用）。公開プロパティの名前・型は変えない

- [ ] **Step 1: 失敗するテストを書く**（`HomeViewModelTests`。子どもを選んで `await viewModel.refreshDataTask?.value` の後に見る）

```swift
func testMonthlyAllowance_ignoresPayments()
// mockAllowanceCalculator.monthlyAllowance = 300、今月の支払い 2 行（amount 200 と 50、childId 同じ、今月）
// → monthlyAllowance == 300、currentMonthEarnings == 300
// その後 monthlyAllowance = 350 にして refreshData() → monthlyAllowance == 350

func testConsecutiveDays_receivesPreviousMonthRecords()
// 今月の記録 1 件 + 先月の記録 1 件（今月 1 日の前日の正午）
// → receivedConsecutiveDaysRecords に先月の記録の id が含まれる

func testConsecutiveDays_receivesAllRecords_whenThisMonthAndTasksEmpty()
// 今月の記録 0 件・タスク 0 件・先月の記録 1 件
// → receivedConsecutiveDaysRecords に先月の記録の id が含まれる（早期分岐）
```

- [ ] **Step 2: RED を確かめる**

Run: `UNIT_CMD` を `-only-testing:OtetsudaiCoinTests/HomeViewModelTests` に絞る
Expected: `** TEST FAILED **`。1 本目は monthlyAllowance が 200 か 50、2・3 本目は先月の記録が含まれない

- [ ] **Step 3: 実装する**

`refreshData` で `findByChildId(processChild.id)` を取り、両方の分岐で `updateDisplayValues(..., allRecords:)` に渡す。`monthlyAllowance = calculatedAllowance`。`isCurrentMonthPaid = payment != nil` と支払いの取得は残す。

- [ ] **Step 4: GREEN を確かめる**

Run: Step 2 と同じ → `** TEST SUCCEEDED **`。続けて `UNIT_CMD` 全件 → `** TEST SUCCEEDED **`（`MonthlySummaryViewModelTests` を含む。アンチゴールの確認）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/HomeViewModel.swift app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift
git commit -m "fix(#311): ホームの今月のコインを稼ぎにし、連続記録に先月までの記録を渡す"
```

---

### 最後に

- [ ] `UNIT_CMD` 全件 → `** TEST SUCCEEDED **`、件数が 632 + 本 PR で足した数
- [ ] 最終 whole-branch レビュー
- [ ] PR 本文は `Refs #311`。画面での再現・確認はしていない（ユニットテストのみ）と書く。merge 後に、使われていない支払い関数の削除を別 issue に起票する
