# タスク並び順（#122 手動並べ替え + #123 よく使う順）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** タスク管理画面で drag & drop の手動並べ替え（#122）と「よく使う順に並べ替え」ボタン（#123、直近90日・全子ども合算）を実装し、その順序を全画面のタスク表示順の正にする。

**Architecture:** `CDHelpTask` に `sortOrder` 属性を追加（新 model version + automatic lightweight migration、backfill なし）。Repository が `(sortOrder, name)` ソート済みで返し、並べ替えは `updateSortOrders(_ orderedIds:)` で一括採番保存。頻度集計は `HelpRecord` から導出（スキーマ変更なし）。RecordView は `findActive()` がソート済みを返すだけで自動反映（変更なし）。

**Tech Stack:** SwiftUI (`List.onMove` + `EditButton`)、Core Data lightweight migration、XCTest、String Catalog (xcstrings)

**Spec:** `docs/superpowers/specs/2026-06-10-issue-122-123-task-ordering-design.md`

**テスト実行コマンド（共通）:**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/<TestClass> 2>&1 | tail -20
```

注意（CLAUDE.md ルール）: background 実行時は exit code を鵜呑みにせず `grep -F "** TEST FAILED"` / `Failing tests:` で確認する。

---

### Task 1: HelpTask entity に sortOrder を追加

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift`
- Test: `app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift`

- [ ] **Step 1.1: 失敗するテストを書く**

`HelpTaskTests.swift` の class 末尾に追加:

```swift
    // MARK: - sortOrder (#122/#123)

    func testSortOrderDefaultsToZero() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true)
        XCTAssertEqual(task.sortOrder, 0)
    }

    func testSortOrderIsPreservedByActivateDeactivateAndUpdateCoinRate() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 5)

        XCTAssertEqual(task.deactivate().sortOrder, 5)
        XCTAssertEqual(task.activate().sortOrder, 5)
        XCTAssertEqual(task.updateCoinRate(20).sortOrder, 5)
    }

    func testUpdatingSortOrderReturnsCopyWithNewOrder() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 1)
        let moved = task.updatingSortOrder(3)

        XCTAssertEqual(moved.sortOrder, 3)
        XCTAssertEqual(moved.id, task.id)
        XCTAssertEqual(moved.name, task.name)
        XCTAssertEqual(moved.isActive, task.isActive)
        XCTAssertEqual(moved.coinRate, task.coinRate)
    }

    func testDefaultTasksHaveSequentialSortOrder() {
        let tasks = HelpTask.defaultTasks()
        XCTAssertEqual(tasks.map(\.sortOrder), Array(0..<HelpTask.defaultTaskNames.count))
    }
```

- [ ] **Step 1.2: コンパイルエラー確定なので red 実行は skip 可**

`sortOrder` プロパティと `updatingSortOrder` が未定義のため `BUILD FAILED` 必至（CLAUDE.md の red skip 条件 (a) に該当）。skip した場合は commit message に skip 理由を明記する。

- [ ] **Step 1.3: 実装**

`HelpTask.swift` を以下のように変更:

```swift
struct HelpTask: Equatable {
    let id: UUID
    let name: String
    let isActive: Bool
    let coinRate: Int
    let sortOrder: Int

    init(id: UUID, name: String, isActive: Bool, coinRate: Int = 10, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.coinRate = coinRate
        self.sortOrder = sortOrder
    }
```

`deactivate()` / `activate()` / `updateCoinRate(_:)` に `sortOrder: sortOrder` を追加:

```swift
    func deactivate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: false, coinRate: coinRate, sortOrder: sortOrder)
    }

    func activate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: true, coinRate: coinRate, sortOrder: sortOrder)
    }

    func updateCoinRate(_ newRate: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: newRate, sortOrder: sortOrder)
    }

    func updatingSortOrder(_ newOrder: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: coinRate, sortOrder: newOrder)
    }
```

`defaultTasks()` を index 採番に変更（新規インストールはデフォルト配列順で表示される）:

```swift
    static func defaultTasks() -> [HelpTask] {
        return defaultTaskNames.enumerated().map { index, name in
            HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: index)
        }
    }
```

- [ ] **Step 1.4: テスト実行して PASS 確認**

Run: `-only-testing:OtetsudaiCoinTests/HelpTaskTests`
Expected: PASS（既存テストも含め全件）

- [ ] **Step 1.5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/HelpTask.swift app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift
git commit -m "feat(#122): HelpTask entity に sortOrder を追加"
```

---

### Task 2: Core Data 新 model version（OtetsudaiCoin 2）に sortOrder 属性を追加

**Files:**
- Create: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 2.xcdatamodel/contents`
- Modify: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion`

automatic lightweight migration（`NSPersistentContainer` のデフォルト有効）に乗せるため、既存 version は残して新 version を current にする。`PBXFileSystemSynchronizedRootGroup` 採用のため pbxproj 編集は不要。

- [ ] **Step 2.1: 新 model version の contents を作成**

`app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 2.xcdatamodel/contents` を新規作成（既存 contents のコピー + `CDHelpTask` に `sortOrder` 1行追加）:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="1" systemVersion="11A491" minimumToolsVersion="Automatic" sourceLanguage="Swift" usedWithCloudKit="false" userDefinedModelVersionIdentifier="">
    <entity name="CDChild" representedClassName="CDChild" syncable="YES" codeGenerationType="class">
        <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="name" attributeType="String"/>
        <attribute name="themeColor" attributeType="String"/>
        <relationship name="helpRecords" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="CDHelpRecord" inverseName="child" inverseEntity="CDHelpRecord"/>
    </entity>
    <entity name="CDHelpRecord" representedClassName="CDHelpRecord" syncable="YES" codeGenerationType="class">
        <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="recordedAt" attributeType="Date" usesScalarValueType="NO"/>
        <relationship name="child" maxCount="1" deletionRule="Nullify" destinationEntity="CDChild" inverseName="helpRecords" inverseEntity="CDChild"/>
        <relationship name="helpTask" maxCount="1" deletionRule="Nullify" destinationEntity="CDHelpTask" inverseName="helpRecords" inverseEntity="CDHelpTask"/>
    </entity>
    <entity name="CDHelpTask" representedClassName="CDHelpTask" syncable="YES" codeGenerationType="class">
        <attribute name="coinRate" attributeType="Integer 32" defaultValueString="10" usesScalarValueType="YES"/>
        <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="isActive" attributeType="Boolean" usesScalarValueType="YES"/>
        <attribute name="name" attributeType="String"/>
        <attribute name="sortOrder" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <relationship name="helpRecords" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="CDHelpRecord" inverseName="helpTask" inverseEntity="CDHelpRecord"/>
    </entity>
    <entity name="Item" representedClassName="Item" syncable="YES" codeGenerationType="class">
        <attribute name="timestamp" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    </entity>
    <elements>
        <element name="CDChild" positionX="-200" positionY="100" width="128" height="89"/>
        <element name="CDHelpRecord" positionX="0" positionY="100" width="128" height="89"/>
        <element name="CDHelpTask" positionX="-200" positionY="200" width="128" height="104"/>
        <element name="Item" positionX="-63" positionY="-18" width="128" height="44"/>
    </elements>
</model>
```

- [ ] **Step 2.2: .xccurrentversion を新 version に切替**

`app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion` の `_XCCurrentVersionName` を変更:

```xml
	<key>_XCCurrentVersionName</key>
	<string>OtetsudaiCoin 2.xcdatamodel</string>
```

- [ ] **Step 2.3: ビルドが通ることを確認**

Run: `xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`（codegen が `CDHelpTask.sortOrder` を生成）

- [ ] **Step 2.4: Commit**

```bash
git add "app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld"
git commit -m "feat(#122): Core Data model v2 を追加し CDHelpTask に sortOrder 属性を追加"
```

---

### Task 3: Repository — sortOrder 永続化 + ソート済み返却 + updateSortOrders

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Repositories/HelpTaskRepository.swift`
- Modify: `app/OtetsudaiCoin/Data/Repositories/CoreDataHelpTaskRepository.swift`
- Modify: `app/OtetsudaiCoinTests/Helpers/TestMocks.swift`（protocol 変更で conformance が壊れるため同 Task 内で更新）
- Create: `app/OtetsudaiCoinTests/Data/CoreDataHelpTaskRepositoryTests.swift`

- [ ] **Step 3.1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Data/CoreDataHelpTaskRepositoryTests.swift` を新規作成（`CoreDataChildRepositoryTests` の in-memory store パターンに準拠）:

```swift
import XCTest
import CoreData
@testable import OtetsudaiCoin

@MainActor
final class CoreDataHelpTaskRepositoryTests: XCTestCase {
    private var repository: CoreDataHelpTaskRepository!
    private var persistenceController: PersistenceController!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = CoreDataHelpTaskRepository(
            context: persistenceController.container.viewContext,
            persistenceController: persistenceController
        )
    }

    override func tearDown() {
        repository = nil
        persistenceController = nil
        super.tearDown()
    }

    func testSortOrderRoundTrip() async throws {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 7)

        try await repository.save(task)
        let found = try await repository.findById(task.id)

        XCTAssertEqual(found?.sortOrder, 7)
    }

    func testUpdatePersistsSortOrder() async throws {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 1)
        try await repository.save(task)

        try await repository.update(task.updatingSortOrder(4))
        let found = try await repository.findById(task.id)

        XCTAssertEqual(found?.sortOrder, 4)
    }

    func testFindAllSortsBySortOrderThenName() async throws {
        // sortOrder 同値 (0) は name 昇順、それ以外は sortOrder 昇順
        try await repository.save(HelpTask(id: UUID(), name: "B食器を出す", isActive: true, coinRate: 10, sortOrder: 0))
        try await repository.save(HelpTask(id: UUID(), name: "Aお片付けする", isActive: true, coinRate: 10, sortOrder: 0))
        try await repository.save(HelpTask(id: UUID(), name: "Cゴミ出し", isActive: false, coinRate: 10, sortOrder: 2))

        let all = try await repository.findAll()

        XCTAssertEqual(all.map(\.name), ["Aお片付けする", "B食器を出す", "Cゴミ出し"])
    }

    func testFindActiveSortsBySortOrder() async throws {
        try await repository.save(HelpTask(id: UUID(), name: "後", isActive: true, coinRate: 10, sortOrder: 2))
        try await repository.save(HelpTask(id: UUID(), name: "先", isActive: true, coinRate: 10, sortOrder: 1))
        try await repository.save(HelpTask(id: UUID(), name: "無効", isActive: false, coinRate: 10, sortOrder: 0))

        let active = try await repository.findActive()

        XCTAssertEqual(active.map(\.name), ["先", "後"])
    }

    func testUpdateSortOrdersRenumbersInGivenOrder() async throws {
        let taskA = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10, sortOrder: 0)
        let taskB = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 10, sortOrder: 1)
        let taskC = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 10, sortOrder: 2)
        try await repository.save(taskA)
        try await repository.save(taskB)
        try await repository.save(taskC)

        try await repository.updateSortOrders([taskC.id, taskA.id, taskB.id])
        let all = try await repository.findAll()

        XCTAssertEqual(all.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(all.map(\.sortOrder), [0, 1, 2])
    }
}
```

注意: `PersistenceController(inMemory: true)` を使うのは、repository が `persistenceController.container.newBackgroundContext()` を経由するため。`CoreDataChildRepositoryTests` のような素の `NSPersistentContainer` だと background context が shared store に向いてしまう。

- [ ] **Step 3.2: red 実行**

Run: `-only-testing:OtetsudaiCoinTests/CoreDataHelpTaskRepositoryTests`
Expected: `updateSortOrders` 未定義のコンパイルエラーで FAIL（skip 条件 (a) 該当だが、新規テストファイルなので一度流して確認するのが安全）

- [ ] **Step 3.3: protocol に updateSortOrders を追加**

`HelpTaskRepository.swift`:

```swift
protocol HelpTaskRepository {
    func save(_ helpTask: HelpTask) async throws
    func findById(_ id: UUID) async throws -> HelpTask?
    func findAll() async throws -> [HelpTask]
    func findActive() async throws -> [HelpTask]
    func delete(_ id: UUID) async throws
    func update(_ helpTask: HelpTask) async throws
    /// orderedIds の並び順で sortOrder を 0..n-1 に採番して一括保存する
    func updateSortOrders(_ orderedIds: [UUID]) async throws
}
```

- [ ] **Step 3.4: CoreDataHelpTaskRepository を実装**

(a) `save` に sortOrder 追加（`cdHelpTask.coinRate = ...` の直後）:

```swift
                    cdHelpTask.sortOrder = Int32(helpTask.sortOrder)
```

(b) `update` にも同様（`cdHelpTask.coinRate = ...` の直後）:

```swift
                        cdHelpTask.sortOrder = Int32(helpTask.sortOrder)
```

(c) `findAll` / `findActive` の fetch request に sort descriptor を追加（`request.predicate` 設定の直後 / `findAll` は request 生成直後）:

```swift
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "sortOrder", ascending: true),
                        NSSortDescriptor(key: "name", ascending: true)
                    ]
```

(d) `updateSortOrders` を class 末尾（`update` の後）に追加:

```swift
    func updateSortOrders(_ orderedIds: [UUID]) async throws {
        DebugLogger.logTaskStart(taskName: "updateSortOrders HelpTasks")
        let startTime = Date()

        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()

            backgroundContext.perform {
                do {
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    let results = try backgroundContext.fetch(request)
                    let byId = Dictionary(uniqueKeysWithValues: results.compactMap { cd in cd.id.map { ($0, cd) } })

                    for (index, id) in orderedIds.enumerated() {
                        byId[id]?.sortOrder = Int32(index)
                    }

                    try backgroundContext.save()

                    DebugLogger.logCoreDataOperation("updateSortOrders completed", context: "Count: \(orderedIds.count)", success: true)
                    DebugLogger.logTaskEnd(taskName: "updateSortOrders HelpTasks", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume()
                } catch {
                    DebugLogger.logTaskEnd(taskName: "updateSortOrders HelpTasks", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
```

(e) `toDomain()` に sortOrder を追加:

```swift
        return HelpTask(id: id, name: name, isActive: self.isActive, coinRate: Int(self.coinRate), sortOrder: Int(self.sortOrder))
```

- [ ] **Step 3.5: MockHelpTaskRepository に updateSortOrders を追加**

`app/OtetsudaiCoinTests/Helpers/TestMocks.swift` の `MockHelpTaskRepository` class 末尾に追加（protocol conformance を回復し、ViewModel テストでの検証にも使う）:

```swift
    var updateSortOrdersCallCount = 0
    var lastOrderedIds: [UUID]?

    func updateSortOrders(_ orderedIds: [UUID]) async throws {
        updateSortOrdersCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        lastOrderedIds = orderedIds
        let position = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($1, $0) })
        tasks = tasks.map { task in
            guard let index = position[task.id] else { return task }
            return task.updatingSortOrder(index)
        }.sorted { $0.sortOrder < $1.sortOrder }
    }
```

他に `HelpTaskRepository` 準拠の mock/fake が無いか `grep -rn ": HelpTaskRepository" app/` で確認し、あれば同様に追加する。

- [ ] **Step 3.6: テスト実行して PASS 確認**

Run: `-only-testing:OtetsudaiCoinTests/CoreDataHelpTaskRepositoryTests`
Expected: PASS（5件）

- [ ] **Step 3.7: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Repositories/HelpTaskRepository.swift \
        app/OtetsudaiCoin/Data/Repositories/CoreDataHelpTaskRepository.swift \
        app/OtetsudaiCoinTests/Helpers/TestMocks.swift \
        app/OtetsudaiCoinTests/Data/CoreDataHelpTaskRepositoryTests.swift
git commit -m "feat(#122): HelpTaskRepository に sortOrder 永続化・ソート済み返却・updateSortOrders を追加"
```

---

### Task 4: TaskManagementViewModel — moveTasks / sortByFrequency / sortOrder 保持

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift`
- Modify: `app/OtetsudaiCoin/Utils/RepositoryFactory.swift:83-87`（init 引数追加）
- Modify: `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift:29`（init 引数追加）
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:252-256`（#Preview の init 引数追加）
- Create: `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift`

**設計メモ:**
- `sortByFrequency` に `HelpRecordRepository` が必要なので init に追加 → 全構築箇所の更新が必須。
- `loadTasks()` の `sorted { $0.name < $1.name }` を削除（repository がソート済みを返す）。
- `addTask` は `max(sortOrder) + 1` で末尾追加。
- `toggleTaskStatus` の手動再構築は **sortOrder を失うバグ源** → entity の `activate()/deactivate()` 呼び出しに置換。
- 日付は `now` 引数注入で実行日非依存（CLAUDE.md の相対日付 flake ルール準拠）。

- [ ] **Step 4.1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift` を新規作成:

```swift
import XCTest
@testable import OtetsudaiCoin

@MainActor
final class TaskManagementViewModelTests: XCTestCase {
    private var viewModel: TaskManagementViewModel!
    private var mockTaskRepository: MockHelpTaskRepository!
    private var mockRecordRepository: MockHelpRecordRepository!

    // 固定日 (2026-06-15 12:00 JST 相当の絶対日)。相対日付 (Date() ± N日) は月初 flake を生むため使わない
    private let fixedNow = Date(timeIntervalSince1970: 1_781_316_000) // 2026-06-13T10:00:00Z

    private func makeTask(name: String, sortOrder: Int, id: UUID = UUID()) -> HelpTask {
        HelpTask(id: id, name: name, isActive: true, coinRate: 10, sortOrder: sortOrder)
    }

    private func makeRecord(taskId: UUID, daysAgo: Int) -> HelpRecord {
        HelpRecord(
            id: UUID(),
            childId: UUID(),
            helpTaskId: taskId,
            recordedAt: fixedNow.addingTimeInterval(TimeInterval(-daysAgo * 24 * 60 * 60))
        )
    }

    override func setUp() {
        super.setUp()
        mockTaskRepository = MockHelpTaskRepository()
        mockRecordRepository = MockHelpRecordRepository()
        viewModel = TaskManagementViewModel(
            helpTaskRepository: mockTaskRepository,
            helpRecordRepository: mockRecordRepository
        )
    }

    override func tearDown() {
        viewModel = nil
        mockTaskRepository = nil
        mockRecordRepository = nil
        super.tearDown()
    }

    // MARK: - loadTasks

    func testLoadTasksUsesRepositoryOrderWithoutReSorting() async {
        // repository は (sortOrder, name) ソート済みを返す前提。ViewModel が名前順に再ソートしないこと
        mockTaskRepository.tasks = [
            makeTask(name: "ん片付け", sortOrder: 0),
            makeTask(name: "あ食器", sortOrder: 1)
        ]

        await viewModel.loadTasks()

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん片付け", "あ食器"])
    }

    // MARK: - moveTasks (#122)

    func testMoveTasksReordersAndPersists() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        // C を先頭へ移動
        await viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(mockTaskRepository.lastOrderedIds, [taskC.id, taskA.id, taskB.id])
    }

    func testMoveTasksOnErrorSetsErrorMessageAndReloads() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        mockTaskRepository.tasks = [taskA, taskB]
        await viewModel.loadTasks()
        mockTaskRepository.shouldThrowError = true

        await viewModel.moveTasks(from: IndexSet(integer: 1), to: 0)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - sortByFrequency (#123)

    func testSortByFrequencyOrdersByRecentRecordCountDescending() async {
        let rare = makeTask(name: "あレア", sortOrder: 0)
        let popular = makeTask(name: "ん人気", sortOrder: 1)
        mockTaskRepository.tasks = [rare, popular]
        mockRecordRepository.records = [
            makeRecord(taskId: popular.id, daysAgo: 1),
            makeRecord(taskId: popular.id, daysAgo: 2),
            makeRecord(taskId: rare.id, daysAgo: 3)
        ]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん人気", "あレア"],
                       "rendered: \(viewModel.tasks.map { ($0.name, $0.sortOrder) })")
        XCTAssertEqual(mockTaskRepository.lastOrderedIds, [popular.id, rare.id])
        XCTAssertNotNil(viewModel.successMessage)
    }

    func testSortByFrequencyExcludesRecordsOlderThan90Days() async {
        let old = makeTask(name: "あ昔人気", sortOrder: 0)
        let recent = makeTask(name: "ん最近", sortOrder: 1)
        mockTaskRepository.tasks = [old, recent]
        mockRecordRepository.records = [
            // 91日前 × 3件 → 窓外で 0 件扱い
            makeRecord(taskId: old.id, daysAgo: 91),
            makeRecord(taskId: old.id, daysAgo: 92),
            makeRecord(taskId: old.id, daysAgo: 93),
            // 89日前 × 1件 → 窓内
            makeRecord(taskId: recent.id, daysAgo: 89)
        ]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん最近", "あ昔人気"])
    }

    func testSortByFrequencyBreaksTiesByName() async {
        let nameB = makeTask(name: "B", sortOrder: 0)
        let nameA = makeTask(name: "A", sortOrder: 1)
        mockTaskRepository.tasks = [nameB, nameA]
        // 両方 0 件 → 名前順
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["A", "B"])
    }

    func testSortByFrequencyOnFetchErrorSetsErrorAndDoesNotPersist() async {
        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()
        mockRecordRepository.shouldThrowError = true

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0)
    }

    // MARK: - sortOrder 保持/採番

    func testAddTaskAppendsToEndWithMaxSortOrderPlusOne() async {
        mockTaskRepository.tasks = [
            makeTask(name: "既存1", sortOrder: 0),
            makeTask(name: "既存2", sortOrder: 5)
        ]
        await viewModel.loadTasks()

        await viewModel.addTask(name: "新規", coinRate: 10)

        let saved = mockTaskRepository.tasks.first { $0.name == "新規" }
        XCTAssertEqual(saved?.sortOrder, 6)
    }

    func testToggleTaskStatusPreservesSortOrder() async {
        let task = makeTask(name: "対象", sortOrder: 3)
        mockTaskRepository.tasks = [task]
        await viewModel.loadTasks()

        await viewModel.toggleTaskStatus(task)

        let updated = mockTaskRepository.tasks.first { $0.id == task.id }
        XCTAssertEqual(updated?.isActive, false)
        XCTAssertEqual(updated?.sortOrder, 3)
    }

    func testUpdateTaskPreservesSortOrderWhenCallerPassesIt() async {
        // 編集フォーム経路 (TaskFormView.updateTask 相当) の sortOrder 保持を gate する
        let task = makeTask(name: "編集前", sortOrder: 4)
        mockTaskRepository.tasks = [task]
        await viewModel.loadTasks()

        let edited = HelpTask(id: task.id, name: "編集後", isActive: true, coinRate: 15, sortOrder: task.sortOrder)
        await viewModel.updateTask(edited)

        let updated = mockTaskRepository.tasks.first { $0.id == task.id }
        XCTAssertEqual(updated?.sortOrder, 4)
        XCTAssertEqual(updated?.name, "編集後")
    }
}
```

注意: `MockHelpTaskRepository.update` が `tasks` 配列を置換する実装か確認し、置換でなければ（append 等なら）`testToggleTaskStatusPreservesSortOrder` の検証方法を mock 実装に合わせて調整する。

- [ ] **Step 4.2: red 実行**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests`
Expected: init 引数・`moveTasks`・`sortByFrequency` 未定義のコンパイルエラーで FAIL

- [ ] **Step 4.3: TaskManagementViewModel を実装**

(a) init に `helpRecordRepository` を追加:

```swift
    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private var loadTasksTask: Task<Void, Never>?

    init(helpTaskRepository: HelpTaskRepository, helpRecordRepository: HelpRecordRepository) {
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
    }
```

(b) `loadTasks()` の再ソートを削除:

```swift
                tasks = allTasks
```

(c) `addTask` の `newTask` 生成を max+1 採番に変更:

```swift
        let nextSortOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let newTask = HelpTask(
            id: UUID(),
            name: trimmedName,
            isActive: true,
            coinRate: coinRate,
            sortOrder: nextSortOrder
        )
```

(d) `toggleTaskStatus` を entity helper 呼び出しに置換（sortOrder 保持バグの予防）:

```swift
    func toggleTaskStatus(_ task: HelpTask) async {
        let updatedTask = task.isActive ? task.deactivate() : task.activate()
        await updateTask(updatedTask)
    }
```

(e) `moveTasks` / `sortByFrequency` を追加（`clearMessages()` の前）:

```swift
    func moveTasks(from source: IndexSet, to destination: Int) async {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        tasks = reordered

        do {
            try await helpTaskRepository.updateSortOrders(reordered.map(\.id))
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            await loadTasks() // DB の状態に巻き戻す
        }
    }

    func sortByFrequency(now: Date = Date()) async {
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -90, to: now) else {
            return
        }

        do {
            let records = try await helpRecordRepository.findByDateRange(from: windowStart, to: now)
            // 全子ども合算で件数集計
            let counts = Dictionary(grouping: records, by: { $0.helpTaskId }).mapValues { $0.count }

            let sorted = tasks.sorted { lhs, rhs in
                let lhsCount = counts[lhs.id] ?? 0
                let rhsCount = counts[rhs.id] ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return lhs.name < rhs.name
            }

            tasks = sorted
            try await helpTaskRepository.updateSortOrders(sorted.map(\.id))
            successMessage = String(localized: "よく使う順に並べ替えました")
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }
```

- [ ] **Step 4.4: 構築箇所3つを更新**

`RepositoryFactory.swift:83-87`:

```swift
    func createTaskManagementViewModel() -> TaskManagementViewModel {
        TaskManagementViewModel(
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            helpRecordRepository: repositoryFactory.createHelpRecordRepository()
        )
    }
```

`SettingsView.swift:29`（`helpRecordRepository` は同 init 内 line 37 で既に生成しているため、生成順を入れ替えて再利用する。変数が後方で宣言されている場合は宣言を前に移動）:

```swift
        self._taskManagementViewModel = State(wrappedValue: TaskManagementViewModel(helpTaskRepository: taskRepository, helpRecordRepository: helpRecordRepository))
```

`TaskManagementView.swift` の `#Preview`:

```swift
#Preview {
    let context = PersistenceController.preview.container.viewContext
    let repository = CoreDataHelpTaskRepository(context: context)
    let recordRepository = CoreDataHelpRecordRepository(context: context)
    TaskManagementView(viewModel: TaskManagementViewModel(helpTaskRepository: repository, helpRecordRepository: recordRepository))
}
```

他の構築箇所が無いか `grep -rn "TaskManagementViewModel(" app/ --include="*.swift"` で確認（テストも含む）。

- [ ] **Step 4.5: テスト実行して PASS 確認**

Run: `-only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests`
Expected: PASS（9件）

- [ ] **Step 4.6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift \
        app/OtetsudaiCoin/Utils/RepositoryFactory.swift \
        app/OtetsudaiCoin/Presentation/Views/SettingsView.swift \
        app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift \
        app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift
git commit -m "feat(#122,#123): TaskManagementViewModel に moveTasks / sortByFrequency を追加"
```

---

### Task 5: TaskManagementView UI — onMove + EditButton + よく使う順ボタン + sortOrder 保持

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift`
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`

- [ ] **Step 5.0: TaskFormView.updateTask の sortOrder リセットバグを予防**（Task 1 の code-quality レビュー指摘で追加）

`TaskFormView.updateTask()`（TaskManagementView.swift:231-247 付近）の `HelpTask` 再構築に `sortOrder: editingTask.sortOrder` を追加する。これが無いと Task 3 以降、タスクを編集（改名 / coinRate 変更）するだけで sortOrder が 0 に落ちて並び順が先頭に飛ぶ:

```swift
        let updatedTask = HelpTask(
            id: editingTask.id,
            name: HelpTask.resolvePersistedName(editedText: taskName, original: editingTask),
            isActive: isActive,
            coinRate: coinRate,
            sortOrder: editingTask.sortOrder
        )
```

- [ ] **Step 5.1: ForEach に onMove を追加**

`TaskManagementView.body` の `ForEach(viewModel.tasks, id: \.id) { ... }` の閉じ括弧直後に追加:

```swift
                            .onMove { source, destination in
                                Task {
                                    await viewModel.moveTasks(from: source, to: destination)
                                }
                            }
```

判定ロジックは ViewModel 側（Task 4 でテスト済み）。この closure は plumbing のみで untested 許容（spec 準拠）。

- [ ] **Step 5.2: toolbar に EditButton、Section に「よく使う順に並べ替え」ボタンを追加**

toolbar に leading item を追加:

```swift
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
```

「新しいタスクを追加」Button の直後（同じ Section 内）に追加:

```swift
                            Button(action: {
                                Task {
                                    await viewModel.sortByFrequency()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text("よく使う順に並べ替え")
                                }
                            }
```

注: `EditButton` はシステム標準ローカライズ（編集/Edit）のため xcstrings 追加は不要。

- [ ] **Step 5.3: xcstrings に新キー2件を追加**

`app/OtetsudaiCoin/Resources/Localizable.xcstrings` に以下の2キーを追加（[[xcstrings-bulk-update]] の流儀: Xcode の `" : "` フォーマットを維持して手動 Edit、既存キーを上書きしない）:

- `"よく使う順に並べ替え"` → en: `"Sort by Most Used"`
- `"よく使う順に並べ替えました"` → en: `"Sorted by most used"`

JSON 形式（既存キーのフォーマットに合わせる）:

```json
    "よく使う順に並べ替え" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sort by Most Used"
          }
        }
      }
    },
    "よく使う順に並べ替えました" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sorted by most used"
          }
        }
      }
    },
```

- [ ] **Step 5.4: ビルド + Localization gate テスト実行**

Run: `-only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: PASS（en 翻訳漏れなし）

- [ ] **Step 5.5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift \
        app/OtetsudaiCoin/Resources/Localizable.xcstrings
git commit -m "feat(#122,#123): タスク管理画面に並べ替え UI（onMove + EditButton + よく使う順ボタン）を追加"
```

---

### Task 6: 全体検証 + PR 作成

**Files:** なし（検証のみ）

- [ ] **Step 6.1: 全テストスイート実行**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`。flaky な UI テスト failure が出た場合は `-only-testing:` で isolated 再実行して parallel flake かを切り分ける（CLAUDE.md ルール）。

- [ ] **Step 6.2: lightweight migration の実機相当確認（simulator）**

既存ストア（v1 model で作成）からの起動で crash しないことを確認する。手順:

```bash
# v1 状態のコミット（Task 2 の直前）を一時 checkout してビルド & 起動 → データ作成
# → HEAD に戻して再ビルド & 起動 → タスク一覧が表示されれば migration 成功
```

簡易代替: 現 HEAD でクリーンインストール起動 → タスク追加 → 再起動でデータ保持を確認（in-memory でなく実ストアで sortOrder 付き save が動く確認）。`ios-simulator-app-verification` skill のパターンを使用。

- [ ] **Step 6.3: 削除系 grep 検証**

`TaskManagementViewModel` の init signature 変更が test/UITest ターゲットに残存参照を作っていないか:

```bash
grep -rn "TaskManagementViewModel(" app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests
```

Expected: 全て新 signature（`helpRecordRepository:` 付き）

- [ ] **Step 6.4: push + PR 作成**

```bash
git status  # HEAD ブランチ再確認 (CLAUDE.md ルール)
gh pr list --head feat/issue-122-123-task-ordering  # 既存 PR 確認
git push -u origin feat/issue-122-123-task-ordering
gh pr create --title "feat(#122,#123): タスクの手動並べ替え + よく使う順ソート" --body "..."
```

PR description には以下を含める:
- Closes #122, Closes #123
- spec / plan へのリンク
- `## Plan からの逸脱` 節（red skip した Task があれば理由を明記）
- migration 確認結果（Step 6.2）
- 手動確認推奨事項: タスク管理画面での drag & drop 操作（XCUITest 外のため）

---

## Self-Review 結果

- **Spec coverage**: データモデル/migration (Task 2)、Domain (Task 1)、Repository (Task 3)、ViewModel/UI (Task 4-5)、i18n (Task 5.3)、テスト戦略（各 Task + 固定日 fixture）、スコープ外事項（RecordView 変更なし・通知配線なし）すべて対応。
- **Placeholder scan**: なし（全ステップに実コード/実コマンド）。
- **Type consistency**: `updateSortOrders(_ orderedIds: [UUID])` / `updatingSortOrder(_:)` / `moveTasks(from:to:)` / `sortByFrequency(now:)` の signature は全 Task で一致。
