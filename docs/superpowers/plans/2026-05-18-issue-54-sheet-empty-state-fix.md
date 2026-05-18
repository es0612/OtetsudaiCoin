# Issue #54: Sheet 初回表示の空表示バグ修正 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sheet で開く `MonthlyHistoryView` と `MonthlyRetrospectiveView` で「初回押下時に empty state（『まだ履歴がありません』『データがありません』）が一瞬または数秒見える」バグを根本対策する。

**Architecture:** ViewModel の `selectChild` / `init` が **load の起動責務を担う** ように戻し、View 側 `.task` での遅延ロードによる empty state gap を排除する。pull-to-refresh / 月切替などの **明示的な再ロードトリガ** はそのまま温存。HelpHistoryView（NavigationLink、既に working）は変更しない。

**Tech Stack:** Swift 5.10+, SwiftUI, XCTest, `@MainActor` / `@Observable` ViewModel パターン。

---

## 背景: なぜこの plan か（pre-flight）

`systematic-debugging` skill の Phase 1-3 で確定済みの事実:

| ViewModel | `selectChild(_)` または `init` の挙動 | 初回表示 |
| --- | --- | --- |
| `HelpHistoryViewModel.selectChild` | `selectedChild = child; loadHelpHistory()` ← load 即起動 | ✅ working |
| `MonthlyHistoryViewModel.selectChild` | `selectedChild = child` のみ（#33 で意図的に load を抜いた） | ❌ empty state gap |
| `MonthlyRetrospectiveViewModel.init` | snapshot=nil, isLoading=false のまま | ❌ 「データがありません」即表示 |

詳細な root cause は #54 のコメント参照: <https://github.com/es0612/OtetsudaiCoin/issues/54>

### Plan に組み込み済みの advisor 検証結果

- **検証 1（`DispatchQueue.main.async`）**: `git log -S 'DispatchQueue.main.async' -- app/.../HomeView.swift` で fix-something 系コミット (`e10bd2e`: 「ViewModel メモリリーク」 / `18c5efe`: 「SwiftUI 状態変更問題」) が確認された → **削除しない**
- **検証 2（`.task { refreshData() }` 削除の安全性）**: `MonthlyHistoryView` を開く entry point は HomeView L148 と L436 の 2 箇所のみ、両方とも `prepareMonthlyHistoryViewModel(for:)` を毎回呼ぶ（cached VM の再利用なし）→ **`.task` 削除安全**。`.refreshable` は pull-to-refresh 用なので残す
- **検証 3（load の start owner）**: `MonthlyRetrospectiveViewModel.init` は defensive `isLoading = true` のみ、actual load の kick は `HomeView.prepareRetrospectiveViewModel` 側に集中（二重起動回避）

---

## File Structure

このリリースで触るファイル一覧（責務単位で記述）:

### Modify

- `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyHistoryViewModel.swift` — `selectChild` で `loadMonthlyHistory()` を呼ぶように戻す
- `app/OtetsudaiCoin/Presentation/Views/MonthlyHistoryView.swift` — `.task { viewModel.refreshData() }` を削除（`.refreshable` は残す）
- `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` — `init` 終端で `isLoading = true` を defensive set
- `app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift` — `.task { await viewModel.loadMonth() }` を削除（月切替の手動 trigger は温存）
- `app/OtetsudaiCoin/Presentation/Views/HomeView.swift` — `prepareRetrospectiveViewModel` 直後に `Task { await viewModel.loadMonth() }` を kick
- `app/OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift` — 既存 `testSelectChildDoesNotAutoLoad` を新規 `testSelectChildKicksLoadImmediately` に置換
- `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift` — `testInitDoesNotStartLoading` を新規追加（init が defensive に `isLoading = true` を立てる確認）

### 触らない

- `HelpHistoryView*.swift` / `HelpHistoryViewModel*.swift` — working なので変更不要
- `HomeView.swift` の `DispatchQueue.main.async`(L147-150 / L158-161) — fix-something 系コミット由来、温存
- `MonthlyHistoryView.swift` の `.refreshable { viewModel.refreshData() }` — pull-to-refresh の責務、温存

---

## Task 1: MonthlyHistoryViewModelTests を新挙動に書き換える（failing test 化）

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift:62-85`

- [ ] **Step 1: 既存テストを「新挙動を期待する failing test」に書き換える**

`testSelectChildDoesNotAutoLoad` (L62-85) を以下に置き換える:

```swift
    // #54: selectChild は load を即起動する。HelpHistoryViewModel と同じ挙動。
    // sheet 初回表示時の empty state gap を排除するため、#33 の「load しない」設計を逆転。
    @MainActor
    func testSelectChildKicksLoadImmediately() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let helpRecord = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: UUID(),
            recordedAt: lastMonth
        )
        mockHelpRecordRepository.records = [helpRecord]
        mockAllowanceCalculator.monthlyAllowance = 100

        viewModel.selectChild(child)

        // selectChild 直後の同期チェック: isLoading == true（load Task が走り始めている）
        XCTAssertTrue(viewModel.isLoading, "selectChild は loadMonthlyHistory を即起動して isLoading=true にすべき")

        // 非同期ロード完了を待機
        try? await Task.sleep(nanoseconds: 300_000_000)

        // ロード完了: monthlyRecords が埋まる
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.monthlyRecords.isEmpty, "load 完了後 monthlyRecords が埋まる")
    }
```

- [ ] **Step 2: テストを実行して fail することを確認**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyHistoryViewModelTests/testSelectChildKicksLoadImmediately
```

Expected: FAIL — `selectChild は loadMonthlyHistory を即起動して isLoading=true にすべき` の assertion で失敗。理由: 現状の `selectChild` は load を呼ばないので `isLoading` は `false` のまま。

- [ ] **Step 3: コミット (failing test)**

```bash
git add app/OtetsudaiCoinTests/Presentation/ViewModels/MonthlyHistoryViewModelTests.swift
git commit -m "test: MonthlyHistoryViewModel.selectChild が load を即起動することを期待する failing test を追加 (#54)"
```

---

## Task 2: MonthlyHistoryViewModel.selectChild に load 即起動を戻す

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyHistoryViewModel.swift:85-88`

- [ ] **Step 1: selectChild を修正**

L85-88 を以下に置換:

```swift
    func selectChild(_ child: Child) {
        // #54: sheet 初回表示の empty state gap を回避するため、selectChild で load を即起動する。
        // 既に loadMonthlyHistory 内で loadHistoryTask?.cancel() を呼んでいるので、
        // View 側で重ねて refreshData() が走っても二重 fetch にはならない（# 33 の懸念は cancel で吸収済み）。
        selectedChild = child
        loadMonthlyHistory()
    }
```

- [ ] **Step 2: テストを実行して PASS を確認**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyHistoryViewModelTests/testSelectChildKicksLoadImmediately
```

Expected: PASS — `isLoading == true` も `monthlyRecords` が埋まることも両方確認できる。

- [ ] **Step 3: ViewModel 全テスト regression チェック**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyHistoryViewModelTests
```

Expected: 全テスト PASS（既存の `testInitialState` / `testSelectChild` / `testLoadMonthlyHistoryWithUnpaidRecords` 等も影響なし）。

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/MonthlyHistoryViewModel.swift
git commit -m "fix: MonthlyHistoryViewModel.selectChild で loadMonthlyHistory を即起動 (#54)"
```

---

## Task 3: MonthlyHistoryView の `.task` を削除（`.refreshable` は残す）

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/MonthlyHistoryView.swift:62-65`

- [ ] **Step 1: `.task` ブロックを削除**

L62-65 のブロックを **削除**:

削除対象:

```swift
        .task {
            // #33: ロードトリガを `.task` に統一して、ViewModel 側 selectChild の auto-Task と二重起動するのを防ぐ
            viewModel.refreshData()
        }
```

削除後、L60 (`.refreshable {}`) の直後にコメントが残るだけになるので、削除箇所の前後は以下のような形になる:

```swift
            .refreshable {
                viewModel.refreshData()
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
```

注意: `.alert(...)` は元々 L66 にあったもの。`.task` の削除によって `.refreshable` を内側に持つ `NavigationStack` の closing brace `}` の直後に `.alert` が来る。

- [ ] **Step 2: ビルドが通ることを確認**

```bash
cd app && xcodebuild build \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: MonthlyHistoryView 関連テストの regression チェック**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyHistoryViewModelTests
```

Expected: 全テスト PASS（Task 1-2 の test も含む）。

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/MonthlyHistoryView.swift
git commit -m "fix: MonthlyHistoryView の .task 重複ロードを削除 (#54)

selectChild が load を即起動するようになったため、.task での
refreshData は冗長になった。pull-to-refresh 用の .refreshable は温存。"
```

---

## Task 4: MonthlyRetrospectiveViewModelTests に init defensive isLoading のテストを追加（failing test 化）

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift:31-39`

- [ ] **Step 1: failing test を追加**

`testInitialMonthIsCurrentMonth` (L41) の直前に以下のテストを挿入:

```swift
    // #54: init 終端で isLoading=true を defensive に立てる。
    // sheet 表示直後の empty state（「データがありません」）gap を避けるため。
    // actual load の kick 責務は HomeView.prepareRetrospectiveViewModel 側に集中（二重起動回避）。
    @MainActor
    func testInitSetsIsLoadingDefensively() {
        let freshViewModel = MonthlyRetrospectiveViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository
        )

        // 旧設計は init 直後 isLoading=false（empty state が見える）
        // 新設計: init 直後から isLoading=true（ProgressView が見える）
        XCTAssertTrue(freshViewModel.isLoading, "init 直後は defensive に isLoading=true でなければならない")
        XCTAssertNil(freshViewModel.snapshot, "snapshot は init 直後は nil")
    }
```

- [ ] **Step 2: テストを実行して fail することを確認**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyRetrospectiveViewModelTests/testInitSetsIsLoadingDefensively
```

Expected: FAIL — `init 直後は defensive に isLoading=true でなければならない` の assertion で失敗。理由: 現状の `init` は `isLoading` を default 値 `false` のままにしている。

- [ ] **Step 3: コミット (failing test)**

```bash
git add app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift
git commit -m "test: MonthlyRetrospectiveViewModel.init が defensive isLoading=true を立てることを期待する failing test を追加 (#54)"
```

---

## Task 5: MonthlyRetrospectiveViewModel.init で isLoading = true を defensive set

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift:29-43`

- [ ] **Step 1: init の終端に isLoading = true を追加**

L29-43 の `init(...)` を以下に置換:

```swift
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

        // #54: sheet 表示直後の empty state（「データがありません」）gap を避けるため、
        // init で defensive に isLoading=true を立てる。
        // actual load の kick は HomeView.prepareRetrospectiveViewModel 側で行う設計（責務分離）。
        self.isLoading = true
    }
```

- [ ] **Step 2: テストを実行して PASS を確認**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyRetrospectiveViewModelTests/testInitSetsIsLoadingDefensively
```

Expected: PASS.

- [ ] **Step 3: ViewModel 全テスト regression チェック**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/MonthlyRetrospectiveViewModelTests
```

Expected: 全テスト PASS（既存の `testInitialMonthIsCurrentMonth` / `testGoToPreviousMonthDecrements` / `testCannotGoBeyondTwelveMonthsAgo` / `testCannotGoToFutureMonth` / `testLoadMonthPopulatesSnapshot` も影響なし）。`testLoadMonthPopulatesSnapshot` が `isLoading == false` を期待しているなら、`loadMonth()` の defer で `isLoading = false` に戻るので影響なし（ロード完了後の assert なら問題なし）。

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift
git commit -m "fix: MonthlyRetrospectiveViewModel.init で defensive に isLoading=true を立てる (#54)"
```

---

## Task 6: HomeView.prepareRetrospectiveViewModel 直後に load を kick

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/HomeView.swift:323-332`

- [ ] **Step 1: prepareRetrospectiveViewModel を修正**

L323-332 を以下に置換:

```swift
    private func prepareRetrospectiveViewModel(for child: Child) {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let newViewModel = MonthlyRetrospectiveViewModel(
            child: child,
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository()
        )
        retrospectiveViewModel = newViewModel
        // #54: load の kick はここに集中（init は defensive isLoading=true のみ）。
        // sheet 表示時点で load が in-flight になり、empty state gap を回避する。
        Task { await newViewModel.loadMonth() }
    }
```

- [ ] **Step 2: ビルドが通ることを確認**

```bash
cd app && xcodebuild build \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: HomeView 関連テストの regression チェック**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/HomeViewModelTests
```

Expected: 全テスト PASS。

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HomeView.swift
git commit -m "fix: HomeView.prepareRetrospectiveViewModel で load を即 kick (#54)"
```

---

## Task 7: MonthlyRetrospectiveView の `.task` を削除（月切替トリガは温存）

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift:53-55`

- [ ] **Step 1: `.task` を削除**

L53-55 のブロックを **削除**:

削除対象:

```swift
        .task {
            await viewModel.loadMonth()
        }
```

削除後、`}` （NavigationStack の closing brace、L52）の **直後** に何も modifier がなくなる。`gesture` modifier (L39-50) や `animation` modifier (L51) はそのまま温存する。

- [ ] **Step 2: ビルドが通ることを確認**

```bash
cd app && xcodebuild build \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift
git commit -m "fix: MonthlyRetrospectiveView の .task 重複ロードを削除 (#54)

load の kick 責務を HomeView.prepareRetrospectiveViewModel 側に集中。
月切替の手動 trigger (goToPreviousMonth / goToNextMonth / swipe gesture) は温存。"
```

---

## Task 8: フルテストスイートで regression がないことを確認

**Files:**

- Test: 全 `app/OtetsudaiCoinTests`

- [ ] **Step 1: 全テスト実行**

```bash
cd app && xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tail -40
```

Expected: 全テスト PASS（既知の `HomeViewTests/testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild` の locale 漏れによる失敗は #56 で別途扱う、本 PR の責任範囲外）。

- [ ] **Step 2: 失敗テストが事前確認の既知ものだけかを目視確認**

`testAllKeysHaveEnglishTranslation` (#53 で別途扱う) と `testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild` (#56 で別途扱う) 以外に失敗があれば、本 PR の修正で regression を起こしている可能性がある。`git stash` して main baseline と比較確認する。

- [ ] **Step 3: 想定外の失敗があれば**

該当する Task に戻って実装を見直す。fix 3 失敗ルールに達したら `superpowers:systematic-debugging` Phase 4.5 (architecture 再考) に戻る。

---

## Task 9: iOS シミュレータで実際に sheet を開いて empty state が見えないことを目視確認

**Files:**

- なし（手動操作 + screenshot）

- [ ] **Step 1: ios-simulator-app-verification skill の手順で boot → build → install → launch**

REQUIRED SUB-SKILL: `ios-simulator-app-verification` の手順に従う。要点:

```bash
xcrun simctl boot 'iPhone 17' 2>/dev/null || true
cd app && xcodebuild build \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build \
  -quiet

# install
APP_PATH="$(find app/build/Build/Products/Debug-iphonesimulator -name '*.app' | head -1)"
xcrun simctl install booted "$APP_PATH"

# UserDefaults でチュートリアル / 子供登録 1 件を予め用意（チュートリアル bypass）
# ※ 詳細は ios-simulator-app-verification skill を参照
xcrun simctl launch booted com.asapapalab.OtetsudaiCoin
```

- [ ] **Step 2: ホーム画面 → calendar.badge.clock ボタンタップで MonthlyHistoryView を開く**

screenshot で「まだ履歴がありません」が初回 frame に **見えていない** ことを確認。期待: ProgressView または直接データ表示。

```bash
xcrun simctl io booted screenshot /tmp/issue54-monthly-history-initial.png
```

- [ ] **Step 3: ホーム画面に戻り、sparkles ボタンで MonthlyRetrospectiveView を開く**

screenshot で「データがありません」が初回 frame に **見えていない** ことを確認。期待: ProgressView または直接 snapshot 表示。

```bash
xcrun simctl io booted screenshot /tmp/issue54-retrospective-initial.png
```

- [ ] **Step 4: terminate → cold launch を 3 回繰り返し regression なし確認**

```bash
for i in 1 2 3; do
  xcrun simctl terminate booted com.asapapalab.OtetsudaiCoin
  sleep 1
  xcrun simctl launch booted com.asapapalab.OtetsudaiCoin
  sleep 2
  # 各回でホームを目視 + sheet を開いて空表示なしを確認
done
```

Expected: 3 回とも sheet 初回押下で空表示が見えない。

- [ ] **Step 5: screenshot を PR 本文に添付準備**

`/tmp/issue54-*.png` を本セッション中の作業フォルダに移動、PR description で参照する。

---

## Task 10: feature branch + PR 作成

**Files:**

- なし（git 操作）

- [ ] **Step 1: feature branch を切ってからの累積コミットを整理確認**

```bash
git checkout -b fix/issue-54-sheet-empty-state
# Task 1-7 のコミットを cherry-pick もしくは branch に既に積んでいる場合は確認
git log --oneline main..HEAD
```

Expected: 7 件のコミット（Task 1 / 2 / 3 / 4 / 5 / 6 / 7 各 1 件）が並んでいる。

- [ ] **Step 2: push**

```bash
git push -u origin fix/issue-54-sheet-empty-state
```

- [ ] **Step 3: gh pr create**

```bash
gh pr create --title "fix: sheet 初回表示の empty state gap を修正 (#54)" --body "$(cat <<'EOF'
## Summary

#54「ボタン初回押した時にコンテンツが空表示されるバグが残っている」の根本対策。

`MonthlyHistoryView` / `MonthlyRetrospectiveView` を sheet で開くとき、ViewModel 作成直後に load() が走らないため、`.task` 発火までの数十〜数百 ms の間「まだ履歴がありません」「データがありません」が描画される問題を、ViewModel 側に load 起動責務を戻すことで根本対策した。

NavigationLink で開く `HelpHistoryView` (working) と同じパターンに揃えた。

## 根本原因

| ViewModel | `selectChild`/`init` の挙動 | 初回表示 |
| --- | --- | --- |
| `HelpHistoryViewModel.selectChild` | load 即起動 | ✅ working |
| `MonthlyHistoryViewModel.selectChild` (修正前) | load しない（#33 で意図的） | ❌ empty gap |
| `MonthlyRetrospectiveViewModel.init` (修正前) | snapshot=nil, isLoading=false | ❌ 「データがありません」即表示 |

詳細は #54 のコメント参照。

## Changes

1. `MonthlyHistoryViewModel.selectChild` で `loadMonthlyHistory()` を即起動
2. `MonthlyHistoryView.swift` の `.task { refreshData() }` を削除（`.refreshable` は温存）
3. `MonthlyRetrospectiveViewModel.init` 終端で defensive に `isLoading = true`
4. `HomeView.prepareRetrospectiveViewModel` 直後に `Task { await loadMonth() }` を kick
5. `MonthlyRetrospectiveView.swift` の `.task { loadMonth() }` を削除（月切替の手動 trigger は温存）

`HomeView.swift` の `DispatchQueue.main.async` (L147-150 / L158-161) は `e10bd2e` / `18c5efe` で fix-something として導入された経緯があるため温存。

## TDD

- 〔test〕 `MonthlyHistoryViewModel.selectChild` 直後 `isLoading == true` であること（新規 `testSelectChildKicksLoadImmediately`、既存 `testSelectChildDoesNotAutoLoad` を置換）
- 〔test〕 `MonthlyRetrospectiveViewModel` init 直後 `isLoading == true` であること（新規 `testInitSetsIsLoadingDefensively`）
- 〔manual〕 iOS シミュレータで両 sheet を初回押下したフレームに empty state が見えないことを目視確認 + screenshot

## Test plan

- [x] `MonthlyHistoryViewModelTests` 全 PASS
- [x] `MonthlyRetrospectiveViewModelTests` 全 PASS
- [x] `HomeViewModelTests` 全 PASS
- [x] フルテストスイート: 既知の `testAllKeysHaveEnglishTranslation` (#53) と `testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild` (#56) 以外で regression なし
- [x] iPhone 17 シミュレータで cold launch → sheet 初回押下を 3 回繰り返し、empty state が見えないことを確認 (screenshot 添付)

## 関連

- Fixes #54
- Refs #56 (HomeViewTests locale 漏れ、別 PR)
- Refs #53 (P2 i18n 漏れ、別 PR)
- Refs PR #46 (HomeView 初回表示の `.task` 化、本 PR の前段階)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR の URL が出力される。

- [ ] **Step 4: TaskUpdate で本 plan のタスクを完了に**

`superpowers:executing-plans` や `superpowers:subagent-driven-development` 側でタスクを完了マーク。

---

## Self-Review チェック

実装後、以下を最低限確認:

1. **Spec coverage**: #54 root cause コメントに書いた修正案 5 つすべてが Task に紐づいているか
   - 修正 1（selectChild に load）→ Task 1-2
   - 修正 2（.task 削除）→ Task 3
   - 修正 3（init で isLoading=true）→ Task 4-5
   - 修正 4（prepare で load kick）→ Task 6
   - 修正 5（DispatchQueue.main.async）→ **削除しない方針確定**（plan preamble に明記）
2. **Placeholder scan**: TODO / TBD / 「適切な」「ハンドリング」のような語が plan 本文に残っていないか
3. **Type consistency**: `selectChild(_:)` / `loadMonthlyHistory()` / `loadMonth()` のメソッド名がコード本体とすべて一致しているか
4. **既存テストとの整合性**: `testSelectChildDoesNotAutoLoad` の **置換** が宣言されており、新挙動テストに名前変更されているか（Task 1 で対応）

---

## Out of scope

- `HelpHistoryView*.swift` / `HelpHistoryViewModel*.swift` は working なので変更しない
- `#57` (ホーム画面のビュー整理) は別 issue、本 PR では扱わない
- `#56` (`HomeViewTests` locale 漏れ) は別 PR
- `#53` (P2 i18n) は別 PR
- `MonthlyHistoryViewModel.refreshData()` を `async` 化する大きなリファクタは本 PR の責務外（既存 API シグネチャを保つ）
