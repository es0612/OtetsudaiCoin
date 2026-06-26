# Issue #130 タスク並べ替え hardening 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PR #129（タスク手動並べ替え）のレビューで挙がった非ブロッキング改善 6 項目を 1 PR にまとめて解消し、並べ替え機能の堅牢性・a11y・テスト契約を強化する。

**Architecture:** ViewModel 側は「同期 in-memory 並べ替え（snap-back 防止）＋直列化された永続化（完了順逆転防止）」へ分離する。View 側はボタン群を `TaskListActionButtons` component に切り出し、ViewInspector が traverse できない親 View から独立してテスト可能にする。Mock とサンプルデータは production と契約を揃える。

**Tech Stack:** Swift / SwiftUI（iOS 26 SDK・Xcode 16+）、XCTest、ViewInspector 0.10.2、Core Data（production repo）。

## Global Constraints

- **iOS 26 SDK + ViewInspector 0.10.2**: `find(viewWithAccessibilityIdentifier:)` / `find(ViewType.X.self)` は systematic に解決しない。component テストは `findAll(ViewType.Button.self)` / `findAll(ViewType.Text.self)` を使う。`Label(systemImage:)` は内部 `Image(systemName:)` が `AccessibilityImageLabel` blocker になるが `findAll` は跨げる（CLAUDE.md「SwiftUI View テスト戦略」）。
- **未検証 traversal の観測値 dump**: `findAll` ベースの PASS はライブラリ挙動依存なので、assertion message に観測値（button 数 / disabled 状態）を必ず含める（CLAUDE.md #106）。
- **TDD RED の実行**: 振る舞い依存（直列化・guard 副作用）の RED は **必ず実行**。コンパイルエラー確定 / fatalError trap の RED のみ skip 可、その場合は commit message と PR `## Plan からの逸脱` に理由を明記（CLAUDE.md TDD ルール）。
- **固定テスト日**: 相対日付（`Date() ± N日`）禁止。既存 `fixedNow = Date(timeIntervalSince1970: 1_781_316_000)` を流用。
- **i18n**: 新規文言は追加しない。`Label("新しいタスクを追加", systemImage:)` のタイトルは `LocalizedStringKey` で、既存 `Text("...")` と同じ String Catalog キーを参照するため英訳は維持される。
- **PBXFileSystemSynchronizedRootGroup**: 新規 `.swift` は所定ディレクトリに置くだけで自動認識。`project.pbxproj` 編集不要。
- **コミット**: 各 Task ごとに独立 commit。

---

## File Structure

| ファイル | 役割 | 種別 |
| --- | --- | --- |
| `app/OtetsudaiCoin/Domain/Services/SampleDataService.swift` | サンプルタスクに連番 sortOrder を付与（item ⑥） | Modify |
| `app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift` | `sampleHelpTasks()` の sortOrder 連番を gate | Create |
| `app/OtetsudaiCoinTests/Helpers/TestMocks.swift` | Mock `updateSortOrders` の重複 id 耐性（item ⑤）＋ 並行度トラッカ（item ① テスト用） | Modify |
| `app/OtetsudaiCoinTests/Helpers/MockHelpTaskRepositoryTests.swift` | Mock 契約（重複 id first 採用）を gate | Create |
| `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift` | 同期 reorder / 直列化 persist / `canSortByFrequency` / guard（item ①②③） | Modify |
| `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift` | onMove 同期化 + ボタンを component へ差し替え（item ②④） | Modify |
| `app/OtetsudaiCoin/Presentation/Components/TaskListActionButtons.swift` | 追加 / よく使う順ボタン（Label 化 + disabled）（item ③④） | Create |
| `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift` | reorder 同期 / 直列化 / canSortByFrequency / guard | Modify |
| `app/OtetsudaiCoinTests/Presentation/Components/TaskListActionButtonsTests.swift` | ボタン数 / disabled wiring | Create |

**テスト実行コマンド（共通）** — scheme/destination は環境に合わせる。クラス単位の例:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/<TestClass> 2>&1 | tee /tmp/xc.log
# 判定は末尾を grep（CLAUDE.md「background exit を鵜呑みにしない」）:
grep -E "Test Suite .* (passed|failed)|\*\* TEST (SUCCEEDED|FAILED)" /tmp/xc.log
```

---

## Task 1: サンプルタスクの sortOrder 連番化（item ⑥）

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/SampleDataService.swift:30-37`
- Test: `app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift`（新規）

**Interfaces:**
- Produces: `static func sampleHelpTasks() -> [HelpTask]`（`#if DEBUG`）。6 件を sortOrder 0..5 で返す。`generateSampleData()` がこれを使う。

- [ ] **Step 1: failing test を書く**

`app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift`:

```swift
#if DEBUG
import XCTest
@testable import OtetsudaiCoin

@MainActor
final class SampleDataServiceTests: XCTestCase {
    func testSampleHelpTasksHaveSequentialSortOrders() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertEqual(
            tasks.map(\.sortOrder),
            Array(0..<tasks.count),
            "sortOrder は挿入順の 0 始まり連番であるべき: \(tasks.map { ($0.name, $0.sortOrder) })"
        )
    }

    func testSampleHelpTasksHaveDistinctSortOrders() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertFalse(tasks.isEmpty, "サンプルタスクが空")
        XCTAssertEqual(
            Set(tasks.map(\.sortOrder)).count,
            tasks.count,
            "sortOrder が重複している: \(tasks.map { ($0.name, $0.sortOrder) })"
        )
    }
}
#endif
```

- [ ] **Step 2: RED 確認（コンパイルエラー確定 → 実行 skip 可）**

`SampleDataService.sampleHelpTasks()` 未定義のため `BUILD FAILED`。CLAUDE.md TDD ルール（型/メソッド未定義の compile error）により実行 skip 可。commit message に「RED=compile error のため skip」と記載。

- [ ] **Step 3: 実装する**

`SampleDataService.swift` の `generateSampleData()` 内のローカル配列（30-37 行）を static factory へ抽出する。クラス内（`#if DEBUG` 内）に追加:

```swift
    /// サンプルタスク定義。sortOrder を 0 始まりの連番で付与し、
    /// 並べ替え機能の DEBUG 検証時に決定的な初期順序を保証する (#130-⑥)。
    static func sampleHelpTasks() -> [HelpTask] {
        let specs: [(name: String, coinRate: Int)] = [
            ("洗い物", 10),
            ("洗濯物たたみ", 15),
            ("掃除機かけ", 20),
            ("おもちゃの片付け", 5),
            ("お風呂掃除", 25),
            ("ゴミ出し", 10)
        ]
        return specs.enumerated().map { index, spec in
            HelpTask(id: UUID(), name: spec.name, isActive: true, coinRate: spec.coinRate, sortOrder: index)
        }
    }
```

`generateSampleData()` 内の 30-37 行を置き換え:

```swift
        // サンプルタスクデータ（sortOrder 連番付き）
        let helpTasks = Self.sampleHelpTasks()
```

- [ ] **Step 4: GREEN 確認**

Run: `-only-testing:OtetsudaiCoinTests/SampleDataServiceTests`
Expected: 2 tests PASS（`** TEST SUCCEEDED`）。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Domain/Services/SampleDataService.swift \
        app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift
git commit -m "$(cat <<'EOF'
fix(#130): サンプルタスクの sortOrder を連番化（item ⑥）

generateSampleData の全タスク sortOrder=0 を、static sampleHelpTasks() に
抽出して 0..5 の連番付与に変更。DEBUG 専用経路だが並べ替えの初期順序を
決定的にする。RED=compile error（sampleHelpTasks 未定義）のため RED 実行 skip。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Mock `updateSortOrders` の重複 id 耐性（item ⑤）

**Files:**
- Modify: `app/OtetsudaiCoinTests/Helpers/TestMocks.swift:131`
- Test: `app/OtetsudaiCoinTests/Helpers/MockHelpTaskRepositoryTests.swift`（新規）

**Interfaces:**
- Produces: `MockHelpTaskRepository.updateSortOrders` が重複 id を含む列でも crash せず、production（`CoreDataHelpTaskRepository.swift:217` の `uniquingKeysWith: { first, _ in first }`）と同じ「最初の出現位置採用」契約に揃う。

- [ ] **Step 1: failing test を書く**

`app/OtetsudaiCoinTests/Helpers/MockHelpTaskRepositoryTests.swift`:

```swift
import XCTest
@testable import OtetsudaiCoin

@MainActor
final class MockHelpTaskRepositoryTests: XCTestCase {
    /// production (CoreDataHelpTaskRepository) は `uniquingKeysWith: { first, _ in first }` で
    /// 重複 id に耐えるため、Mock も同契約（最初の位置を採用・crash しない）であるべき (#130-⑤)。
    func testUpdateSortOrdersHandlesDuplicateIdsWithoutCrash() async throws {
        let mock = MockHelpTaskRepository()
        let idA = UUID()
        let idB = UUID()
        mock.tasks = [
            HelpTask(id: idA, name: "A", isActive: true, coinRate: 10, sortOrder: 0),
            HelpTask(id: idB, name: "B", isActive: true, coinRate: 10, sortOrder: 1)
        ]

        // idA が重複した列。uniqueKeysWithValues 実装だと fatalError でクラッシュする
        try await mock.updateSortOrders([idA, idB, idA])

        let a = mock.tasks.first { $0.id == idA }
        let b = mock.tasks.first { $0.id == idB }
        XCTAssertEqual(a?.sortOrder, 0, "重複 id は最初の位置 (0) を採用すべき")
        XCTAssertEqual(b?.sortOrder, 1)
    }
}
```

- [ ] **Step 2: RED 確認（fatalError trap → test bundle abort のため実行 skip）**

現行 `Dictionary(uniqueKeysWithValues:)` は重複キーで `Fatal error: Dictionary literal contains duplicate keys` を trap し、**test プロセス全体を abort** する（catch 不能・clean RED 不可）。決定的なクラッシュであり compile error カテゴリに準じるため RED 実行は skip し、Step 3 と同時に実装する。commit message と PR `## Plan からの逸脱` に「RED=fatalError trap のため test+fix 同時 commit」と明記。

- [ ] **Step 3: 実装する**

`TestMocks.swift:131` を置換:

```swift
        let position = Dictionary(
            orderedIds.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
```

- [ ] **Step 4: GREEN 確認**

Run: `-only-testing:OtetsudaiCoinTests/MockHelpTaskRepositoryTests`
Expected: PASS（重複 id で crash せず sortOrder a=0, b=1）。

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoinTests/Helpers/TestMocks.swift \
        app/OtetsudaiCoinTests/Helpers/MockHelpTaskRepositoryTests.swift
git commit -m "$(cat <<'EOF'
test(#130): Mock updateSortOrders を重複 id 耐性に（item ⑤）

Dictionary(uniqueKeysWithValues:) を uniquingKeysWith: { first, _ in first } に
変更し production の CoreDataHelpTaskRepository と契約を揃える。
RED は fatalError trap（test bundle abort）で clean に取れないため
test+fix を同一 commit にした。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: onMove 同期化（reorder / persist 分離）（item ②）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift:112-130`（`moveTasks` を分割）
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:32-36`（onMove）
- Test: `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift`（追加）

**Interfaces:**
- Produces:
  - `@discardableResult func reorderTasks(from source: IndexSet, to destination: Int) -> [HelpTask]` — 同期で in-memory 並べ替えを適用し、並べ替え後配列を返す。
  - `func persistReorder(_ reordered: [HelpTask]) async` — 並べ替え結果を永続化（失敗時 rollback）。
  - `func moveTasks(from:to:) async` — 上記 2 つを合成（既存 API 維持・テスト/プログラム経路用）。

- [ ] **Step 1: failing test を書く**

`TaskManagementViewModelTests.swift` の `// MARK: - moveTasks (#122)` 節に追加:

```swift
    func testReorderTasksUpdatesInMemoryOrderSynchronouslyWithoutPersisting() async {
        // onMove 経路: 同期 reorder のみ呼ぶと、永続化前に即座に tasks が並べ替わる (#130-②)
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        let reordered = viewModel.reorderTasks(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["C", "A", "B"], "reorderTasks は同期で in-memory 順序を更新すべき")
        XCTAssertEqual(reordered.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0, "reorderTasks 単独では永続化しない")
    }
```

- [ ] **Step 2: RED 確認（コンパイルエラー確定 → 実行 skip 可）**

`reorderTasks` 未定義で `BUILD FAILED`。compile error カテゴリのため実行 skip 可、commit に明記。

- [ ] **Step 3: 実装する（ViewModel）**

`TaskManagementViewModel.swift` の `moveTasks`（112-130 行）を以下 3 メソッドに置換:

```swift
    /// in-memory の並べ替えを同期適用し、並べ替え後配列を返す。
    /// onMove から同期呼び出しすることで、SwiftUI List が同一 runloop で並べ替え後配列を
    /// 反映し、行が一瞬元位置へ戻る snap-back glitch を防ぐ (#130-②)。
    @discardableResult
    func reorderTasks(from source: IndexSet, to destination: Int) -> [HelpTask] {
        // in-flight な loadTasks の stale 結果が楽観的更新を上書きしないようキャンセル
        loadTasksTask?.cancel()
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        tasks = reordered
        return reordered
    }

    /// 並べ替え結果を永続化する。失敗時は DB 状態へ巻き戻す。
    func persistReorder(_ reordered: [HelpTask]) async {
        do {
            try await helpTaskRepository.updateSortOrders(reordered.map(\.id))
            // DB の再採番 (0..n-1) を in-memory にもミラーし、後続の toggle/編集が
            // stale な sortOrder を書き戻すのを防ぐ
            tasks = reordered.enumerated().map { $1.updatingSortOrder($0) }
        } catch {
            let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            await loadTasks() // DB の状態に巻き戻す
            errorMessage = message // loadTasks 冒頭の errorMessage=nil に消されないよう reload 後にセット
        }
    }

    /// 同期 reorder + 永続化をまとめた従来 API（テスト/プログラム経路用）。
    func moveTasks(from source: IndexSet, to destination: Int) async {
        let reordered = reorderTasks(from: source, to: destination)
        await persistReorder(reordered)
    }
```

- [ ] **Step 4: 実装する（View）**

`TaskManagementView.swift:32-36` の onMove を同期 reorder + 非同期 persist に分離:

```swift
                            .onMove { source, destination in
                                // 同期 reorder で snap-back を防ぎ、永続化のみ非同期へ
                                let reordered = viewModel.reorderTasks(from: source, to: destination)
                                Task {
                                    await viewModel.persistReorder(reordered)
                                }
                            }
```

- [ ] **Step 5: GREEN 確認（新規 + 既存 moveTasks テストの回帰なし）**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests`
Expected: 新規 `testReorderTasks...` PASS。既存 `testMoveTasksReordersAndPersists` / `testMoveTasksOnErrorSetsErrorMessageAndReloads` / `testToggleAfterMoveDoesNotResurrectStaleSortOrder` も PASS（`moveTasks` の合成で挙動不変）。

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift \
        app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift \
        app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift
git commit -m "$(cat <<'EOF'
fix(#130): onMove を同期 reorder + 非同期 persist に分離（item ②）

moveTasks を reorderTasks(同期)/persistReorder(非同期)/moveTasks(合成) に分割。
onMove で同期 reorder を呼ぶことで List が同一 runloop で並べ替え後配列を反映し
snap-back glitch を解消。RED=compile error（reorderTasks 未定義）のため実行 skip。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 永続化の直列化（item ①）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift`（`enqueueSortPersist` 追加・`persistReorder` / `sortByFrequency` をラップ）
- Modify: `app/OtetsudaiCoinTests/Helpers/TestMocks.swift`（並行度トラッカ + `Task.yield`）
- Test: `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift`（追加）

**Interfaces:**
- Consumes: `MockHelpTaskRepository.maxConcurrentUpdateSortOrders: Int`（並行に走った最大数）。
- Produces: ViewModel 内 private `enqueueSortPersist(_:)`。`persistReorder` / `sortByFrequency` の永続化部が直列化される。

- [ ] **Step 1: Mock に並行度トラッカ + 中断点を追加**

`TestMocks.swift` の `MockHelpTaskRepository` に property 追加（`updateSortOrdersCallCount` の近く）:

```swift
    var concurrentUpdateSortOrdersCount = 0
    var maxConcurrentUpdateSortOrders = 0
```

`updateSortOrders` を以下に置換（item ⑤ の `uniquingKeysWith` も維持）:

```swift
    func updateSortOrders(_ orderedIds: [UUID]) async throws {
        updateSortOrdersCallCount += 1
        concurrentUpdateSortOrdersCount += 1
        maxConcurrentUpdateSortOrders = max(maxConcurrentUpdateSortOrders, concurrentUpdateSortOrdersCount)
        defer { concurrentUpdateSortOrdersCount -= 1 }
        // 直列化されていなければ 2 つ目の呼び出しがこの中断点で割り込み max が 2 になる
        await Task.yield()
        if shouldThrowError || shouldThrowErrorOnUpdateSortOrders {
            throw errorToThrow
        }
        lastOrderedIds = orderedIds
        let position = Dictionary(
            orderedIds.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        tasks = tasks.map { task in
            guard let index = position[task.id] else { return task }
            return task.updatingSortOrder(index)
        }
    }
```

- [ ] **Step 2: failing test を書く**

`TaskManagementViewModelTests.swift` に追加:

```swift
    func testConcurrentReordersAreSerialized() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        // 2 つの並べ替えをほぼ同時に発火。直列化されていれば updateSortOrders は
        // 同時に 1 つしか走らない (#130-①)。
        async let first: Void = viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)
        async let second: Void = viewModel.moveTasks(from: IndexSet(integer: 0), to: 2)
        _ = await (first, second)

        XCTAssertLessThanOrEqual(
            mockTaskRepository.maxConcurrentUpdateSortOrders, 1,
            "並べ替え永続化は直列化されるべき（observed max concurrent: \(mockTaskRepository.maxConcurrentUpdateSortOrders), calls: \(mockTaskRepository.updateSortOrdersCallCount)）"
        )
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 2, "両方の永続化が実行されるべき")
    }
```

- [ ] **Step 3: RED 確認（振る舞い依存 → 必ず実行）**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests/testConcurrentReordersAreSerialized`
Expected: **FAIL**。直列化前は 2 つ目の `updateSortOrders` が `Task.yield` の中断点で割り込み `maxConcurrentUpdateSortOrders == 2` になる。失敗メッセージに `observed max concurrent: 2` が出ることを確認（観測値が出ない＝traversal でなく単純 race なので 2 が出れば妥当）。

- [ ] **Step 4: 実装する（直列化）**

`TaskManagementViewModel.swift` に private property とヘルパを追加（`loadTasksTask` の近く / メソッド群の末尾）:

```swift
    private var sortPersistChain: Task<Void, Never>?

    /// 並べ替え永続化を直列化する。前の永続化が完了してから次を開始することで、
    /// moveTasks 同士 / moveTasks vs sortByFrequency が別 background context で走った際の
    /// 完了順逆転による DB/in-memory 不整合を防ぐ (#130-①)。
    private func enqueueSortPersist(_ body: @escaping () async -> Void) async {
        let previous = sortPersistChain
        let task = Task { @MainActor in
            await previous?.value
            await body()
        }
        sortPersistChain = task
        await task.value
    }
```

`persistReorder` の本体を `enqueueSortPersist` で包む:

```swift
    func persistReorder(_ reordered: [HelpTask]) async {
        await enqueueSortPersist { [self] in
            do {
                try await helpTaskRepository.updateSortOrders(reordered.map(\.id))
                tasks = reordered.enumerated().map { $1.updatingSortOrder($0) }
            } catch {
                let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                await loadTasks()
                errorMessage = message
            }
        }
    }
```

`sortByFrequency` の永続化部（`do { try await helpTaskRepository.updateSortOrders... } catch {...}` ブロック）を `enqueueSortPersist` で包む。fetch / 集計 / sorted 計算は従来どおり手前で行い、永続化のみ直列化する:

```swift
    func sortByFrequency(now: Date = Date()) async {
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -90, to: now) else {
            return
        }
        loadTasksTask?.cancel()

        let records: [HelpRecord]
        do {
            records = try await helpRecordRepository.findByDateRange(from: windowStart, to: now)
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            return
        }

        let counts = Dictionary(grouping: records, by: { $0.helpTaskId }).mapValues { $0.count }
        let sorted = tasks.sorted { lhs, rhs in
            let lhsCount = counts[lhs.id] ?? 0
            let rhsCount = counts[rhs.id] ?? 0
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return lhs.name < rhs.name
        }

        await enqueueSortPersist { [self] in
            do {
                try await helpTaskRepository.updateSortOrders(sorted.map(\.id))
                tasks = sorted.enumerated().map { $1.updatingSortOrder($0) }
                successMessage = String(localized: "よく使う順に並べ替えました")
            } catch {
                let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                await loadTasks()
                errorMessage = message
            }
        }
    }
```

> 注: `sortByFrequency` 冒頭の `guard tasks.count > 1`（item ③）は Task 5 で追加する。本 Task では既存構造 + 直列化のみ。

- [ ] **Step 5: GREEN 確認**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests`
Expected: `testConcurrentReordersAreSerialized` が `maxConcurrent == 1` で PASS。既存の moveTasks / sortByFrequency テスト群も全 PASS（直列 await で挙動不変）。

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift \
        app/OtetsudaiCoinTests/Helpers/TestMocks.swift \
        app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift
git commit -m "$(cat <<'EOF'
fix(#130): 並べ替え永続化を直列化（item ①）

enqueueSortPersist で persistReorder / sortByFrequency の updateSortOrders を
直列化し、連続並べ替え時の完了順逆転による DB/in-memory 不整合を防ぐ。
Mock に並行度トラッカ + Task.yield 中断点を追加し maxConcurrent<=1 を gate。
RED は直列化前に maxConcurrent==2 を観測して確認済み。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 空 / 1 件で「よく使う順」を no-op 化（item ③ ロジック）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift`（`canSortByFrequency` + guard）
- Test: `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift`（追加）

**Interfaces:**
- Produces: `var canSortByFrequency: Bool { tasks.count > 1 }`（View の `.disabled` バインド用）。`sortByFrequency` は `tasks.count <= 1` で no-op。

- [ ] **Step 1: `canSortByFrequency` property を先に追加（コンパイルを通す）**

`TaskManagementViewModel.swift` の computed property として追加（`tasks` 宣言付近 or メソッド群手前）:

```swift
    /// 「よく使う順に並べ替え」が意味を持つか。0/1 件では並べ替え不要 (#130-③)。
    var canSortByFrequency: Bool {
        tasks.count > 1
    }
```

- [ ] **Step 2: failing test を書く**

`TaskManagementViewModelTests.swift` の `// MARK: - sortByFrequency (#123)` 節に追加:

```swift
    func testCanSortByFrequencyReflectsTaskCount() async {
        XCTAssertFalse(viewModel.canSortByFrequency, "0 件では並べ替え不可")

        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()
        XCTAssertFalse(viewModel.canSortByFrequency, "1 件では並べ替え不可")

        mockTaskRepository.tasks = [
            makeTask(name: "A", sortOrder: 0),
            makeTask(name: "B", sortOrder: 1)
        ]
        await viewModel.loadTasks()
        XCTAssertTrue(viewModel.canSortByFrequency, "2 件以上で並べ替え可")
    }

    func testSortByFrequencyIsNoOpWhenSingleTask() async {
        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0, "1 件では永続化しない")
        XCTAssertNil(viewModel.successMessage, "1 件では成功メッセージを出さない")
    }
```

- [ ] **Step 3: RED 確認（guard の副作用は振る舞い依存 → 必ず実行）**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests/testSortByFrequencyIsNoOpWhenSingleTask`
Expected: **FAIL**。guard 未追加だと 1 件でも `updateSortOrders` が呼ばれ（`updateSortOrdersCallCount == 1`）`successMessage` がセットされる。`testCanSortByFrequencyReflectsTaskCount` は property 追加済みのため PASS。

- [ ] **Step 4: 実装する（guard）**

`sortByFrequency` の冒頭（`guard let windowStart` の前）に追加:

```swift
        guard canSortByFrequency else { return }
```

- [ ] **Step 5: GREEN 確認**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests`
Expected: 新規 2 test PASS。既存 `testSortByFrequency...` 群（タスク 2 件以上）は影響なく PASS。

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift
git commit -m "$(cat <<'EOF'
fix(#130): 0/1 件で「よく使う順」を no-op 化 + canSortByFrequency 公開（item ③）

canSortByFrequency(tasks.count>1) を追加し View の .disabled バインドへ供給。
sortByFrequency 冒頭に guard を入れ 0/1 件では永続化も成功メッセージも出さない。
guard 副作用は RED（callCount==1 / successMessage 非 nil）で確認済み。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: ボタンの Label 化 + disabled wiring（item ④ + item ③ View）

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/Components/TaskListActionButtons.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:38-57`（2 ボタンを component へ差し替え）
- Test: `app/OtetsudaiCoinTests/Presentation/Components/TaskListActionButtonsTests.swift`（新規）

**Interfaces:**
- Consumes: `TaskManagementViewModel.canSortByFrequency`（Task 5）。
- Produces: `struct TaskListActionButtons: View { let canSortByFrequency: Bool; let onAdd: () -> Void; let onSortByFrequency: () -> Void }`。

- [ ] **Step 1: failing test を書く**

`app/OtetsudaiCoinTests/Presentation/Components/TaskListActionButtonsTests.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskListActionButtonsTests: XCTestCase {
    /// Label(systemImage:) は内部 Image(systemName:) が AccessibilityImageLabel blocker に
    /// なるため find(accessibilityIdentifier:) は到達不可。findAll(ViewType.Button.self) は
    /// blocker を跨いで Button を全列挙できる（CLAUDE.md SwiftUI View テスト戦略 / #84）。
    private func buttons(canSort: Bool) throws -> [InspectableView<ViewType.ClassicButton>] {
        let view = TaskListActionButtons(
            canSortByFrequency: canSort,
            onAdd: {},
            onSortByFrequency: {}
        )
        return try view.inspect().findAll(ViewType.Button.self)
    }

    func testRendersAddAndSortButtons() throws {
        let found = try buttons(canSort: true)
        XCTAssertEqual(found.count, 2, "追加 + よく使う順 の 2 ボタンを描画すべき（found: \(found.count)）")
    }

    func testSortButtonDisabledWhenCannotSort() throws {
        let found = try buttons(canSort: false)
        XCTAssertEqual(found.count, 2, "found: \(found.count)")
        // 宣言順 [追加, よく使う順]。よく使う順(index1) が disabled であるべき
        XCTAssertFalse(try found[0].isDisabled(), "追加ボタンは常に有効（index0 disabled=\(String(describing: try? found[0].isDisabled()))）")
        XCTAssertTrue(try found[1].isDisabled(), "0/1 件ではよく使う順は disabled（index1 disabled=\(String(describing: try? found[1].isDisabled()))）")
    }

    func testSortButtonEnabledWhenCanSort() throws {
        let found = try buttons(canSort: true)
        XCTAssertEqual(found.count, 2, "found: \(found.count)")
        XCTAssertFalse(try found[1].isDisabled(), "2 件以上ではよく使う順は有効")
    }
}
```

> 注: `InspectableView<ViewType.ClassicButton>` の型名は ViewInspector のバージョンに依存する。`findAll(ViewType.Button.self)` の戻り値型に合わせる（コンパイルが通らなければ `let found = try view.inspect().findAll(ViewType.Button.self)` を helper をやめて各 test に inline 展開し、型注釈を外す）。

- [ ] **Step 2: RED 確認（コンパイルエラー確定 → 実行 skip 可）**

`TaskListActionButtons` 未定義で `BUILD FAILED`。compile error カテゴリのため RED 実行 skip。ただし **GREEN は findAll traversal の未検証挙動に依存するため必ず実行**（CLAUDE.md #106）。

- [ ] **Step 3: 実装する（component）**

`app/OtetsudaiCoin/Presentation/Components/TaskListActionButtons.swift`:

```swift
import SwiftUI

/// お手伝い管理画面のアクションボタン群（タスク追加 / よく使う順並べ替え）。
///
/// TaskManagementView 本体は NavigationStack + List + BannerAdView(UIViewRepresentable) を
/// 含み ViewInspector で traverse 不可のため、テスト可能性のためにボタンを component 分離する
/// (#130-④、#74 RecordButtonBar と同じ path)。
/// ボタンは Label 化して VoiceOver がアイコン名でなくタイトルを読むようにする (#130-④)。
struct TaskListActionButtons: View {
    let canSortByFrequency: Bool
    let onAdd: () -> Void
    let onSortByFrequency: () -> Void

    var body: some View {
        Group {
            Button(action: onAdd) {
                Label("新しいタスクを追加", systemImage: "plus.circle.fill")
            }
            .primaryGradientButton()

            Button(action: onSortByFrequency) {
                Label("よく使う順に並べ替え", systemImage: "arrow.up.arrow.down")
            }
            .disabled(!canSortByFrequency)
        }
    }
}
```

- [ ] **Step 4: 実装する（View 差し替え）**

`TaskManagementView.swift:38-57` の 2 つの `Button { ... }` ブロックを以下に置換:

```swift
                            TaskListActionButtons(
                                canSortByFrequency: viewModel.canSortByFrequency,
                                onAdd: { showingAddTaskForm = true },
                                onSortByFrequency: {
                                    Task {
                                        await viewModel.sortByFrequency()
                                    }
                                }
                            )
```

- [ ] **Step 5: GREEN 確認（findAll traversal の実証 → 必ず実行）**

Run: `-only-testing:OtetsudaiCoinTests/TaskListActionButtonsTests`
Expected: 3 test PASS。`found.count == 2`、index1 の `isDisabled()` が canSort で切り替わることを確認。失敗時は assertion message の観測値（found 数 / disabled 状態）で「traversal 不達 / 述語ずれ / 要素未描画」を切り分ける。

> findAll が 2 ボタンに到達できない場合のフォールバック: component を `Group` でなく明示的な `VStack` で囲む、または `.primaryGradientButton()`（ButtonStyle）が traversal を阻害していないか `found.count` 観測値で判断。それでも不達なら item ④ の自動テストは断念し（item ③ の disabled は ViewModel `canSortByFrequency` テストで担保済み）、PR `## Plan からの逸脱` に「component の structural test は iOS 26 ViewInspector 制約で断念・視覚確認」と明記する。

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskListActionButtons.swift \
        app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TaskListActionButtonsTests.swift
git commit -m "$(cat <<'EOF'
fix(#130): アクションボタンを Label 化 + component 分離（item ③④）

追加/よく使う順ボタンを TaskListActionButtons に切り出し、HStack+Image+Text を
Label に置換（VoiceOver 改善）。よく使う順は canSortByFrequency で .disabled。
findAll(ViewType.Button.self) で 2 ボタン数 + disabled wiring を gate。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 全体回帰確認

- [ ] **Step 1: 影響ターゲットの全テスト実行**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests 2>&1 | tee /tmp/xc-all.log
grep -E "\*\* TEST (SUCCEEDED|FAILED)|Failing tests:" /tmp/xc-all.log
```

Expected: `** TEST SUCCEEDED`。flaky に落ちた UI/load 系は `-only-testing:` で isolated 再実行し parallel flake かを切り分ける（CLAUDE.md「iOS テスト flake 切り分け」）。

- [ ] **Step 2: PR 作成前チェック**

- `git fetch origin` → `origin/main` を起点に feature branch（例 `fix/issue-130-task-reorder-hardening`）を切っているか確認
- `gh pr list --head <branch>` で並列セッションの既存 PR が無いか確認
- PR description に各 item の対応 + `## Plan からの逸脱`（RED skip 理由・Task 6 フォールバック有無）を記載

---

## Self-Review

**1. Spec coverage（#130 の 6 item）:**

| item | 内容 | Task |
| --- | --- | --- |
| ① | persist 直列化 | Task 4 |
| ② | onMove 同期化（snap-back 解消） | Task 3 |
| ③ | 0/1 件で「よく使う順」disabled | Task 5（ロジック）+ Task 6（View wiring） |
| ④ | ボタンの Label 化（a11y） | Task 6 |
| ⑤ | Mock updateSortOrders 重複 id 耐性 | Task 2 |
| ⑥ | SampleDataService sortOrder 連番化 | Task 1 |

全 6 item に対応 Task あり。✓

**2. Placeholder scan:** TBD / TODO / 「適切に実装」等のプレースホルダなし。各 step に実コードあり。✓

**3. Type consistency:**
- `reorderTasks(from:to:) -> [HelpTask]`（Task 3 定義）→ Task 3 View / Task 4 で `[HelpTask]` を `persistReorder` に渡す。✓
- `persistReorder(_ reordered: [HelpTask])`（Task 3）→ Task 4 で本体を `enqueueSortPersist` ラップ。シグネチャ不変。✓
- `canSortByFrequency: Bool`（Task 5）→ Task 6 で `viewModel.canSortByFrequency` 参照。✓
- `maxConcurrentUpdateSortOrders`（Task 4 Mock）→ 同 Task のテストで参照。✓
- `sampleHelpTasks() -> [HelpTask]`（Task 1）→ 同 Task のテストで参照。✓

**4. 依存順:** Task 3（reorder/persist 分離）→ Task 4（persist 直列化）、Task 5（canSortByFrequency）→ Task 6（View wiring）。Task 1/2 は独立。順序は依存を満たす。✓
