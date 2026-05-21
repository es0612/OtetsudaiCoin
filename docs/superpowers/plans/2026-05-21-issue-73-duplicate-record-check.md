# Issue #73 同日同タスクの重複記録チェック Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一括モード / 単一モード両方の `RecordView` の `TaskCardView` に「すでに N 件記録済み」の neutral gray ラベルを表示し、同日同タスクの重複登録を block ではなく情報提示で気付かせる。

**Architecture:** `HelpRecordRepository` は無変更。`RecordViewModel` に `existingRecordCounts: [UUID: Int]` state を追加し、既存 `findByDateRange` を活用して `(recordedDate, selectedChild)` 軸の per-task count map を構築。`TaskCardView` を `Presentation/Components/` に切り出して `existingCount` prop を受け取り、`coinInfo` と `selectionIndicator` の間に `if existingCount >= 1` の conditional row を描画。reload trigger は `loadData` 末尾 / `selectChild` 末尾 / `recordedDate` DatePicker `onChange` / `notifyHelpRecordUpdates` observer 経路に集約。

**Tech Stack:** SwiftUI / Swift Concurrency (`Task`) / ViewInspector / XCTest / xcstrings (`variations.plural`) / Xcode 16+ (`PBXFileSystemSynchronizedRootGroup`)

**Branch:** `feat/issue-73-duplicate-record-check` (既に切ってあり spec が commit 済み)

**Scope NOT in this plan:**

- block 化オプション (設定で同日同タスクを block するモードを選べる拡張) — 別 issue
- `HelpRecordRepository` への `countByDate` 専用 query 追加 — record 数増大時の最適化候補、今は YAGNI
- 複数日跨ぎの警告 (例: 過去 7 日で N 件) — 今回の `recordedDate` 当日のみ対象
- `RecordView` 本体への structural test 追加 — BannerAdView / NavigationStack blocker のため component test に委ねる

---

## File Structure

| File | 役割 |
| --- | --- |
| `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift` (new) | `RecordView.swift` から切り出した `TaskCardView`。新規 `existingCount: Int = 0` prop と `existingCountRow` を持つ |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | `TaskCardView` struct を削除、呼び出し側に `existingCount:` 引数を追加、`dateSection` に `onChange(of: viewModel.recordedDate)` modifier 追加 |
| `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` | `existingRecordCounts` state、`existingRecordCount(for:)` accessor、`loadExistingCountsForCurrentDateAndChild()` method、reload trigger 4 か所追加 |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 新規 key `"すでに %lld 件記録済み"` (ja は key 自体、en は `variations.plural` の one/other) |
| `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` | 新規テスト 6 件追加 |
| `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift` (new) | 新規 component test 3 件 |
| `app/OtetsudaiCoinTests/Localization/LocalizedMessageTests.swift` | one バリアント regression catch 用テスト 1 件追加 |

新規 `.swift` は `PBXFileSystemSynchronizedRootGroup` により所定ディレクトリに置くだけで自動認識される。`project.pbxproj` の編集は不要。

---

## Task 1: TaskCardView を Components 配下に切り出す (behavior-preserving refactor)

**Files:**

- Create: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` (TaskCardView struct を削除)

- [ ] **Step 1: baseline 取り — 既存テスト全 run で PASS を確認**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: TEST SUCCEEDED (refactor 前の状態を担保)。`iPhone 16` 不在の環境では `iPhone 17` を使用する (#74 で確立した destination)。

- [ ] **Step 2: 新規ファイル `TaskCardView.swift` を作成**

`app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift`:

```swift
import SwiftUI

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                selectionIndicator
            }
            .padding()
            .frame(height: 140)
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var taskIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .blue : .gray.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: "hands.sparkles")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
        }
    }

    private var taskTitle: some View {
        Text(task.name)
            .appFont(.cardTitle)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(AccessibilityColors.textPrimary)
            .lineLimit(2)
    }

    private var coinInfo: some View {
        Text("\(task.coinRate)コイン")
            .appFont(.captionText)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .blue : .secondary)
    }

    private var selectionIndicator: some View {
        Group {
            if isBulkMode {
                bulkSelectionIndicator
            } else if isSelected {
                selectedIndicator
            } else {
                unselectedIndicator
            }
        }
    }

    private var bulkSelectionIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
            Text(isSelected ? "選択中" : "選択")
                .appFont(.captionText)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.7))
        }
    }

    private var selectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            Text("選択中")
                .appFont(.captionText)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }

    private var unselectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.5))
            Text("タップして選択")
                .appFont(.captionText)
                .foregroundColor(.gray.opacity(0.7))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}
```

- [ ] **Step 3: `RecordView.swift` から `TaskCardView` struct (243-349 行目相当) を削除**

`RecordView.swift` の末尾にある `struct TaskCardView: View { ... }` ブロックを丸ごと削除。

- [ ] **Step 4: build & 全テスト run**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: TEST SUCCEEDED。`RecordView` から `TaskCardView` を import 経由で利用する形になっているはずだが、両方が同じ module 内なので明示 import は不要。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift \
        app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "$(cat <<'EOF'
refactor(#73): TaskCardView を Presentation/Components/ に切り出す

#73 で TaskCardView に existingCount prop を追加し、component 単独で
ViewInspector test を可能にするための事前 refactor。#74 で確立した
component 分離 path に倣う。

挙動の差分なし (behavior-preserving)。
EOF
)"
```

---

## Task 2: xcstrings に "すでに %lld 件記録済み" を追加

**Files:**

- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`

- [ ] **Step 1: 挿入位置を確認**

`Localizable.xcstrings` 内で `"%lld 件記録しました！"` を検索し、その entry の直後 (一般に `"%lld 件失敗、もう一度タップしてください"` の前) を挿入位置とする。`grep -n '"%lld 件記録しました！"' app/OtetsudaiCoin/Resources/Localizable.xcstrings` で行番号を取得。

- [ ] **Step 2: Edit tool で entry を挿入**

`Edit` tool で以下を挿入 (新規 key)。**Python `json.dump` を使った書き換えは禁則** — `" : "` 整形が崩れて diff が爆発する既知罠。

```jsonc
    "すでに %lld 件記録済み" : {
      "localizations" : {
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Already recorded %lld time"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Already recorded %lld times"
                }
              }
            }
          }
        }
      }
    },
```

挿入 anchor は `"%lld 件記録しました！" : { ... },` の閉じ `},` 直後。

- [ ] **Step 3: build で xcstrings 整合性を確認**

```bash
xcodebuild build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: BUILD SUCCEEDED。catalog parsing でエラーが出ないこと。`LocalizationStringCatalogTests` 系の test がある場合は `xcodebuild test -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests` で確認 (#43 で導入された missing English translation チェック)。

- [ ] **Step 4: commit**

```bash
git add app/OtetsudaiCoin/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
i18n(#73): "すでに %lld 件記録済み" を xcstrings に追加

TaskCardView の existingCountRow で使う plural 対応文言を catalog に追加。
ja は key 自体が値 (既存 pattern と同一)、en は variations.plural の
one/other を用意。

呼び出し側は String(localized: "すでに \(count) 件記録済み") の文字列補間
で plural variations を解決する (CLAUDE.md i18n 罠ルール準拠)。
EOF
)"
```

---

## Task 3: RecordViewModel — existingRecordCounts state と accessor 追加 (TDD)

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`

- [ ] **Step 1: Failing tests を追加 (initially empty + unknown task → 0)**

`RecordViewModelTests.swift` の末尾 (最後の `}` の手前) に以下を追加:

```swift
    // MARK: - #73 existingRecordCounts

    @MainActor
    func test_existingRecordCounts_initiallyEmpty() {
        XCTAssertEqual(viewModel.existingRecordCounts, [:])
    }

    @MainActor
    func test_existingRecordCount_returnsZeroForUnknownTask() {
        let unknownId = UUID()
        XCTAssertEqual(viewModel.existingRecordCount(for: unknownId), 0)
    }
```

- [ ] **Step 2: Run → FAIL**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_existingRecordCounts_initiallyEmpty \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_existingRecordCount_returnsZeroForUnknownTask
```

Expected: BUILD FAILED (`existingRecordCounts` / `existingRecordCount(for:)` 未定義)。

- [ ] **Step 3: 最小実装**

`RecordViewModel.swift` の class 内、既存 `var warningMessage: String? = nil` の直後に以下を追加:

```swift
    var existingRecordCounts: [UUID: Int] = [:]

    func existingRecordCount(for taskId: UUID) -> Int {
        return existingRecordCounts[taskId] ?? 0
    }
```

- [ ] **Step 4: Run → PASS**

同じ `xcodebuild test -only-testing:` を再実行。Expected: 2 件 PASS。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#73): RecordViewModel に existingRecordCounts state を追加"
```

---

## Task 4: loadExistingCountsForCurrentDateAndChild() を実装 (TDD)

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`

- [ ] **Step 1: Failing tests を追加 (no selectedChild → 空 / filter by child & date)**

```swift
    @MainActor
    func test_loadExistingCounts_noSelectedChild_clearsMap() {
        // Given: 何らかの count が事前に残っている、selectedChild = nil
        viewModel.existingRecordCounts = [UUID(): 5]

        // When (selectedChild == nil の場合は同期的に [:] にする実装のため、await 不要)
        viewModel.loadExistingCountsForCurrentDateAndChild()

        // Then
        XCTAssertEqual(viewModel.existingRecordCounts, [:])
    }

    @MainActor
    func test_loadExistingCounts_filtersBySelectedChildAndDate() async {
        // Given: 2 子供 × 同日同タスク × 異日同タスク を含む record 群
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task1 = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        let task2 = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 5)

        let today = Calendar.current.startOfDay(for: Date())
        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: noon)!

        mockChildRepository.children = [childA, childB]
        mockHelpTaskRepository.tasks = [task1, task2]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: noon),       // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: noon),       // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task2.id, recordedAt: noon),       // 対象 (別 task)
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task1.id, recordedAt: noon),       // 除外 (別 child)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: yesterday),  // 除外 (別日)
        ]

        viewModel.selectedChild = childA
        viewModel.recordedDate = noon

        // When
        viewModel.loadExistingCountsForCurrentDateAndChild()
        // Task が cancel 制御込みで async に走るので、結果反映を条件待ち
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task1.id) == 2 }

        // Then
        XCTAssertEqual(viewModel.existingRecordCount(for: task1.id), 2)
        XCTAssertEqual(viewModel.existingRecordCount(for: task2.id), 1)
    }
```

- [ ] **Step 2: Run → FAIL (compile error: method 未定義)**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_loadExistingCounts_noSelectedChild_clearsMap \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_loadExistingCounts_filtersBySelectedChildAndDate
```

Expected: BUILD FAILED (`loadExistingCountsForCurrentDateAndChild()` 未定義)。

- [ ] **Step 3: 実装**

`RecordViewModel.swift` の class 内、既存 `private var loadChildrenTask: Task<Void, Never>?` の直後に以下を追加:

```swift
    private var loadCountsTask: Task<Void, Never>?
```

そして `recordHelp` メソッドの直後 (もしくは末尾の `private static func normalizeToNoon` の手前) に以下を追加:

```swift
    @MainActor
    func loadExistingCountsForCurrentDateAndChild() {
        loadCountsTask?.cancel()

        guard let child = selectedChild else {
            existingRecordCounts = [:]
            return
        }

        let targetDate = recordedDate
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: targetDate)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else {
            return
        }

        loadCountsTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let records = try await self.helpRecordRepository.findByDateRange(from: startOfDay, to: endOfDay)
                guard !Task.isCancelled else { return }
                let filtered = records.filter { $0.childId == child.id }
                let map = Dictionary(grouping: filtered, by: { $0.helpTaskId }).mapValues { $0.count }
                await MainActor.run {
                    self.existingRecordCounts = map
                }
            } catch {
                // count 取得失敗時は無視 (UX 影響低、既存 errorMessage を上書きしない)
            }
        }
    }
```

- [ ] **Step 4: Run → PASS**

同じ `xcodebuild test -only-testing:` を再実行。Expected: 2 件 PASS。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(#73): loadExistingCountsForCurrentDateAndChild を実装

selectedChild + recordedDate から、当日 record を findByDateRange で取得し
selectedChild に絞って [taskId: count] map を構築する。
loadCountsTask による cancel 制御で、連続 child/date 切替時に古い結果が
上書きされない。

count 取得失敗時は無視 (existing errorMessage を上書きしない)。
EOF
)"
```

---

## Task 5: selectChild() に reload trigger を追加 (TDD)

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`

- [ ] **Step 1: Failing test を追加 (selectChild → count map updated)**

```swift
    @MainActor
    func test_selectChild_triggersCountReload() async {
        // Given: child A と child B、それぞれ別の record
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)

        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: Date()))!
        mockChildRepository.children = [childA, childB]
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon),
        ]

        viewModel.selectedChild = childA
        viewModel.recordedDate = noon
        viewModel.loadExistingCountsForCurrentDateAndChild()
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task.id) == 1 }

        // When: child B に切り替え
        viewModel.selectChild(childB)

        // Then: count map が child B のものに更新
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task.id) == 2 }
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 2)
    }
```

- [ ] **Step 2: Run → FAIL (期待値 2 だが 1 のまま)**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_selectChild_triggersCountReload
```

Expected: FAIL with "XCTAssertEqual failed: ("1") is not equal to ("2")"。

- [ ] **Step 3: 実装 — selectChild() の末尾に reload を追加**

`RecordViewModel.swift` の `selectChild(_:)` メソッド (現状 150-159 行目) を以下に変更:

```swift
    func selectChild(_ child: Child) {
        let isChangingChild = selectedChild != nil && selectedChild?.id != child.id
        selectedChild = child
        if isChangingChild {
            selectedTaskIds = []
            selectedTask = nil
        }
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
        loadExistingCountsForCurrentDateAndChild()
    }
```

- [ ] **Step 4: Run → PASS**

同じ `xcodebuild test -only-testing:` を再実行。Expected: PASS。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#73): selectChild() に existingRecordCounts reload trigger を追加"
```

---

## Task 6: loadData() 末尾の reload trigger + recordHelp 成功時の observer 経路 (TDD)

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`

- [ ] **Step 1: Failing test を追加 (recordHelp success → count map に +1 が反映)**

```swift
    @MainActor
    func test_recordHelpSuccess_updatesCountViaObserver() async {
        // Given: 初期 record なし、child と task を選択済み
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]

        viewModel.loadData()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }
        viewModel.selectTask(task)
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 0)

        // When: 1 件 recordHelp
        viewModel.recordHelp()

        // observer chain (recordHelp → notify → loadData → loadCounts) は
        // 多段の Task switch を経由するため、固定 sleep ではなく条件待ち
        await waitUntil(timeout: 3.0) { self.viewModel.existingRecordCount(for: task.id) == 1 }

        // Then: count map が +1 されている
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 1)
    }
```

- [ ] **Step 2: Run → FAIL (loadData 末尾 reload 未実装のため、observer 経路で count が反映されない)**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordHelpSuccess_updatesCountViaObserver
```

Expected: FAIL ("0" is not equal to "1")。

- [ ] **Step 3: 実装 — loadData() の setLoading(false) 直後に reload chain を追加**

`RecordViewModel.swift` の `loadData()` メソッド内、`setLoading(false)` (現状 103 行目相当) の直後に以下を 1 行追加:

```swift
                setLoading(false)
                loadExistingCountsForCurrentDateAndChild()  // ← NEW
```

`recordHelp` / `recordBulkHelp` 内では直接 reload を呼ばない方針 (spec の Data Flow セクション参照)。observer 経路 (`notifyHelpRecordUpdated` → `observeHelpRecordUpdates` → `loadData` → 末尾 reload) に統一する。

- [ ] **Step 4: Run → PASS**

同じ `xcodebuild test -only-testing:` を再実行。Expected: PASS (observer chain で count が反映される)。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(#73): loadData() 末尾で existingRecordCounts を reload

recordHelp / recordBulkHelp の成功時に notifyHelpRecordUpdated → observer
経由で loadData が再実行され、その末尾の loadExistingCountsForCurrentDate...
で count map が +1 される。recordHelp / recordBulkHelp 内で直接 reload を
呼ばない方針 (二重発火回避) は spec の Data Flow 通り。

外部 (HelpHistoryView / HelpRecordEditView) からの編集/削除も同じ
observer 経路で反映される。
EOF
)"
```

---

## Task 7: TaskCardView に existingCount prop と existingCountRow を追加 (TDD, Component)

**Files:**

- Create: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift`

- [ ] **Step 1: 新規 component test を作成 (3 件)**

`app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "皿洗い", coinRate: Int = 10) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: coinRate)
    }

    // MARK: - #73 existingCountRow

    func test_existingCountRow_hidden_whenCountIsZero() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 0,
            onTap: {}
        )
        // 0 件のときは label が描画されない
        XCTAssertThrowsError(try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label"))
    }

    func test_existingCountRow_visible_whenCountIsOne() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 1,
            onTap: {}
        )
        let label = try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label")
        let text = try label.find(ViewType.Text.self).string()
        XCTAssertTrue(text.contains("1"))
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 3,
            onTap: {}
        )
        let label = try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label")
        let text = try label.find(ViewType.Text.self).string()
        XCTAssertTrue(text.contains("3"))
    }
}
```

- [ ] **Step 2: Run → FAIL (compile error: existingCount 引数なし)**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests
```

Expected: BUILD FAILED。

- [ ] **Step 3: 実装 — `existingCount` prop と `existingCountRow` を追加**

`TaskCardView.swift` の struct プロパティを以下に変更 (`existingCount` を追加):

```swift
struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    var existingCount: Int = 0          // ← NEW
    let onTap: () -> Void
```

`body` 内 VStack の `coinInfo` と `selectionIndicator` の間に `existingCountRow` を挿入し、`frame(height: 140)` を `150` に変更:

```swift
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                existingCountRow      // ← NEW
                selectionIndicator
            }
            .padding()
            .frame(height: 150)       // ← 140 → 150
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
```

`coinInfo` の後ろ、`selectionIndicator` の前のどこかに以下のメソッドを追加:

```swift
    @ViewBuilder
    private var existingCountRow: some View {
        if existingCount >= 1 {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                Text(existingCountText)
                    .appFont(.captionText)
                    .foregroundColor(.gray.opacity(0.7))
                    .accessibilityIdentifier("existing_count_label")
            }
        } else {
            EmptyView()
        }
    }

    private var existingCountText: String {
        // 文字列補間で xcstrings の plural variations を利用する。
        // String(format:) は variations を bypass する既知罠 (CLAUDE.md i18n 節)。
        let count = existingCount
        return String(localized: "すでに \(count) 件記録済み")
    }
```

- [ ] **Step 4: Run → PASS**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests
```

Expected: 3 件 PASS。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift
git commit -m "$(cat <<'EOF'
feat(#73): TaskCardView に existingCount prop と existingCountRow を追加

coinInfo と selectionIndicator の間に「すでに N 件記録済み」を neutral gray
で表示。existingCount=0 の時は EmptyView() で hidden。

card 高さは 140 → 150 に統一して、count あり/なしで隣カードと高さズレ
しないようにする (LazyVGrid 内の見た目崩れ防止)。

i18n は文字列補間 String(localized: "すでに \(count) 件記録済み") で
xcstrings plural variations を解決 (CLAUDE.md i18n 罠ルール準拠)。
EOF
)"
```

---

## Task 8: RecordView 統合 — TaskCardView 呼び出しに existingCount を渡す + dateSection onChange

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`

- [ ] **Step 1: TaskCardView 呼び出しに `existingCount:` 引数を追加**

`RecordView.swift` の `taskListView` 内、`ForEach` で `TaskCardView(...)` を呼び出している箇所 (現状 215-232 行目相当) を以下に変更:

```swift
                    ForEach(viewModel.availableTasks, id: \.id) { task in
                        TaskCardView(
                            task: task,
                            isSelected: viewModel.isBulkMode
                                ? viewModel.selectedTaskIds.contains(task.id)
                                : viewModel.selectedTask?.id == task.id,
                            isBulkMode: viewModel.isBulkMode,
                            existingCount: viewModel.existingRecordCount(for: task.id),  // ← NEW
                            onTap: {
                                if viewModel.isBulkMode {
                                    if viewModel.selectedTaskIds.contains(task.id) {
                                        viewModel.selectedTaskIds.remove(task.id)
                                    } else {
                                        viewModel.selectedTaskIds.insert(task.id)
                                    }
                                } else {
                                    viewModel.selectTask(task)
                                }
                            }
                        )
                        .accessibilityIdentifier("task_button")
                    }
```

- [ ] **Step 2: `dateSection` (DatePicker) に onChange modifier を追加**

`RecordView.swift` の `dateSection` (現状 132-151 行目相当) の `DatePicker` 部分の末尾に modifier を追加:

```swift
    private var dateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
                .font(.title3)
            Text(String(localized: "記録日"))
                .appFont(.sectionHeader)
            Spacer()
            DatePicker(
                "",
                selection: $viewModel.recordedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .accessibilityIdentifier("record_date_picker")
            .onChange(of: viewModel.recordedDate) { _, _ in        // ← NEW
                viewModel.loadExistingCountsForCurrentDateAndChild()
            }
        }
        .padding(.horizontal)
    }
```

- [ ] **Step 3: build & 既存テスト全 run**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: TEST SUCCEEDED。既存テストも regression なし、Task 7 の TaskCardViewTests も含めて全 PASS。

- [ ] **Step 4: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "$(cat <<'EOF'
feat(#73): RecordView を existingRecordCounts に統合

- TaskCardView 呼び出しに existingCount: viewModel.existingRecordCount(for:)
  を引き渡す
- dateSection の DatePicker に onChange(of:) modifier を追加して、日付
  変更時に count を再 load
EOF
)"
```

---

## Task 9: i18n regression catch test を追加

**Files:**

- Modify: `app/OtetsudaiCoinTests/Localization/LocalizedMessageTests.swift`

- [ ] **Step 1: テストを追加 (xcstrings Task 2 で追加済みなので green スタート)**

`LocalizedMessageTests.swift` の末尾、最後の `}` の手前に新規 MARK セクションとともに以下を追加:

```swift
    // MARK: - #73 existingRecordCount label

    /// CLAUDE.md の「one バリアントが効くことを unit test で 1 件担保しておくと
    /// runtime bypass の regression を catch できる」ルールに準拠。
    /// String(localized: "すでに \(1) 件記録済み") が plural variations を
    /// 経由して 1 を含む文字列を返すことを担保する。
    func test_existingCountLabel_singularContainsOne() {
        let message = String(localized: "すでに \(1) 件記録済み")
        XCTAssertTrue(message.contains("1"))
        XCTAssertTrue(
            message.contains("件記録済み") || message.contains("recorded"),
            "expected ja or en localized text, got \(message)"
        )
    }
```

- [ ] **Step 2: Run → PASS**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/LocalizedMessageTests/test_existingCountLabel_singularContainsOne
```

Expected: PASS (Task 2 で catalog に key を追加済みのため green スタート)。

- [ ] **Step 3: commit**

```bash
git add app/OtetsudaiCoinTests/Localization/LocalizedMessageTests.swift
git commit -m "$(cat <<'EOF'
test(#73): existingCountLabel の one バリアント regression catch を追加

CLAUDE.md i18n ルールの「count=1 のときに one バリアントが効くことを unit
test で 1 件担保」に準拠。String(format:) で書き直された場合の runtime
bypass を catch する。
EOF
)"
```

---

## Task 10: 全テストスイート + Simulator 起動による smoke 確認

**Files:** (検証のみ、変更なし)

- [ ] **Step 1: 全テストスイートを通す**

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: TEST SUCCEEDED。flaky test に当たったら CLAUDE.md ルールに従い `-only-testing:` で isolated 再実行して PASS なら parallel flake として切り分け。

- [ ] **Step 2: Simulator で起動確認**

[[ios-simulator-app-verification]] skill を参考に、build → install → launch → HomeView スクショ取得まで:

```bash
xcrun simctl boot 'iPhone 17' 2>/dev/null || true
xcodebuild -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/OtetsudaiCoin-derived build
xcrun simctl install booted \
  /tmp/OtetsudaiCoin-derived/Build/Products/Debug-iphonesimulator/OtetsudaiCoin.app
xcrun simctl launch booted com.asapapalab.OtetsudaiCoin
sleep 3
xcrun simctl io booted screenshot /tmp/otetsudaicoin-issue73-home.png
```

⚠️ **TabView の制約** — `selectedTab` が `@State` で永続化されないため (CLAUDE.md 既知)、simctl 経由で Record タブへの切替はできない。Record タブの TaskCardView 上で「すでに N 件記録済み」が表示される実物の視覚確認は reviewer 手動確認に委ねる。

- [ ] **Step 3: 結果記録** (PR description で使う)

- 全テストスイートの SUCCEEDED 行を記録
- HomeView のスクショ 1 枚
- Record タブの視覚確認は「reviewer 手動確認推奨」と PR description に明記

---

## Task 11: PR 準備 (push & PR description ドラフト)

**Files:** (git 操作のみ)

- [ ] **Step 1: branch / commit 状態を確認**

```bash
git status
git branch --show-current   # Expected: feat/issue-73-duplicate-record-check
git log --oneline -15
```

- [ ] **Step 2: 同一ブランチで先行 PR がないか確認 (並列セッション対策)**

```bash
gh pr list --head feat/issue-73-duplicate-record-check --json number,title
```

Expected: 空配列。

- [ ] **Step 3: push**

```bash
git push -u origin feat/issue-73-duplicate-record-check
```

- [ ] **Step 4: PR description を `<<'EOF'` HEREDOC で作成**

```bash
gh pr create --title "feat(#73): 同日同タスクの重複記録に警告ラベルを表示" \
  --body "$(cat <<'EOF'
## Summary

issue #73: 一括記録モード (PR #72) で「うっかり同タスクを 2 回登録」が起こりうるため、`TaskCardView` に「すでに N 件記録済み」の neutral gray ラベルを表示。block ではなく情報提示のみ (「同日にゴミ出し 2 回」など正当な重複は通せる UX を保つ)。

- 一括モード / 単一モード両方で表示
- `(recordedDate, selectedChild, task)` の組み合わせで count
- 過去日に DatePicker を切り替えても、その日付の count に追従
- block ではなく情報提示のみ。`onTap` / `recordButtonDisabled` は無変更

## Spec / Plan

- Spec: [docs/superpowers/specs/2026-05-21-issue-73-duplicate-record-check-design.md](docs/superpowers/specs/2026-05-21-issue-73-duplicate-record-check-design.md)
- Plan: [docs/superpowers/plans/2026-05-21-issue-73-duplicate-record-check.md](docs/superpowers/plans/2026-05-21-issue-73-duplicate-record-check.md)

## 実装ポイント

- `HelpRecordRepository` API 追加なし、既存 `findByDateRange` を活用
- `RecordViewModel` に `existingRecordCounts: [UUID: Int]` + `loadExistingCountsForCurrentDateAndChild()` を追加
- reload trigger は `loadData` 末尾 / `selectChild` 末尾 / `DatePicker onChange` / `notifyHelpRecordUpdates` observer 経路に集約 (`recordHelp` / `recordBulkHelp` 内で直接 reload は呼ばない)
- `TaskCardView` を `Presentation/Components/` に切り出し (#74 の component 分離 path)、component 単独で ViewInspector test を可能にした
- xcstrings に `"すでに %lld 件記録済み"` を追加 (en は variations.plural)

## Test plan

- [x] RecordViewModelTests: 6 件追加 (initial empty / unknown task → 0 / no child → 空 / filter by child & date / selectChild trigger / recordHelp observer chain) すべて PASS
- [x] TaskCardViewTests: 新規 3 件 (hidden when 0 / visible when 1 / plural form when 3) すべて PASS
- [x] LocalizedMessageTests: 1 件追加 (one バリアント regression catch) PASS
- [x] 全テストスイート \`xcodebuild test\` TEST SUCCEEDED
- [x] Simulator 起動 / HomeView 描画確認
- [ ] **Reviewer 手動確認推奨**: Record タブを開き、(a) 既存 record がある task に「すでに N 件記録済み」が表示される、(b) DatePicker で過去日に切替えると count が追従する、(c) block されず record button は普通に押せる、ことを目視確認 (TabView の selectedTab が @State で永続化されないため simctl 経由での切替が不可、CLAUDE.md 既知問題)

Closes #73

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: 完了報告**

PR URL を user に返し、reviewer 視点の手動確認ポイントを共有。

---

## Reviewer 視点チェックリスト (CLAUDE.md ルールへの準拠)

reviewer (および implementer) が手元で確認できる observable な準拠ポイント:

| ルール (CLAUDE.md) | 準拠箇所 |
| --- | --- |
| 別目的の PR に無関係なファイルを同梱しない | spec / plan / 実装すべて同 issue 範囲のみ、CLAUDE.md 修正は別 PR #78 |
| feature branch 切る前に `git fetch origin` | brainstorming → spec commit 時点で main 同期確認済み |
| 並列セッション PR 二重作成防止 | Task 11 Step 2 で `gh pr list --head` チェック |
| pbxproj 編集不要 (Xcode 16 SyncRoot) | Task 1 / Task 7 の新規 `.swift` 配置のみ |
| ViewInspector blocker 回避 | `TaskCardView` を component 分離 (Task 1) してから test (Task 7) |
| xcstrings 編集は Edit tool で手動 | Task 2 で明示、Python json.dump 禁則を再掲 |
| xcstrings plural は文字列補間で呼ぶ | Task 7 の `existingCountText` で `\(count)` 補間、Task 9 で regression test |
| NotificationManager 干渉 (errorMessage クリア) | Task 6 で `recordHelp` / `recordBulkHelp` 既存挙動 (`successIds.isEmpty` 判定) を保持、新規 reload は observer 経路集約 |
| TabView の simctl 切替不可 | Task 10 / Task 11 PR description で reviewer 手動確認推奨を明記 |
| Plan からの deviation | 発生したら commit メッセージに記載 + PR description に `## Plan からの逸脱` 節を追加 |

---

## 並列実行可否

`subagent-driven-development` skill 利用時の依存関係:

```
Task 1 (TaskCardView 分離) ──┐
                            ├──> Task 7 (Component に existingCount 追加)
Task 2 (xcstrings)  ────────┘                            │
                                                         │
Task 3 (state/accessor) ──> Task 4 (load impl) ──> Task 5 (selectChild trigger) ──> Task 6 (loadData trigger)
                                                                                     │
                                                                                     ↓
                                                            Task 8 (RecordView 統合, Task 6/7 両方に依存)
                                                                                     │
                                                                                     ↓
                                                                            Task 9 (i18n test, Task 2 後ならいつでも)
                                                                                     │
                                                                                     ↓
                                                                            Task 10 (full suite + simulator)
                                                                                     │
                                                                                     ↓
                                                                            Task 11 (PR)
```

並列化候補:

- **Task 1 と Task 2 は完全独立** — 別 subagent で並列可
- **Task 3 → Task 4 → Task 5 → Task 6** は同一ファイル (`RecordViewModel.swift`) を順次変更するため直列が安全
- **Task 7** は Task 1 (分離) 完了後に着手可、Task 3-6 とは独立
- **Task 8 / Task 9** は Task 6 / Task 7 / Task 2 全て完了後
- **Task 10 / Task 11** は最後に直列

最短 path で約 4 つの並列束に分解可能だが、`RecordViewModel.swift` を触る Task 3-6 が直列なので、現実的な総時間短縮は 1.5× 程度。inline 実行でも十分。
