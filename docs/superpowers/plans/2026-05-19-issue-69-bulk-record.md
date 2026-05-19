# お手伝い記録 一括登録 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RecordView に「一括モード」Toggle を追加し、選択した複数の HelpTask をまとめて記録できる UX を実現する。1 件登録の既存 flow と両立、部分失敗時は成功分のみ DB に保存し失敗分のみ再選択状態として残す。

**Architecture:** 新規 ViewModel は作らず、既存 `RecordViewModel` を拡張 (`isBulkMode: Bool`, `selectedTaskIds: Set<UUID>`, `recordBulkHelp()`)。View 側は `RecordView` 内 `toolbar` に Toggle、`TaskCardView` を `isBulkMode` で表示分岐、`recordButtonView` を mode 別 label に。Mode 切替 / Child 切替 / 一括記録完了 で両 selection を reset。

**Tech Stack:** SwiftUI / Swift / `@Observable` / XCTest / ViewInspector / xcodebuild / xcstrings

**Spec:** `docs/superpowers/specs/2026-05-19-issue-69-bulk-record-design.md`

---

## File Structure

| 種別 | パス | 責務 |
|---|---|---|
| Modify | `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` | `isBulkMode`, `selectedTaskIds` プロパティ、`toggleBulkMode()`, `recordBulkHelp()`, `selectTask()`/`selectChild()` 拡張 |
| Modify | `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | toolbar Toggle、TaskCardView 表示分岐、recordButtonView mode 別 label、bulk summary row、partial-failure warning row |
| Modify | `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 一括モード関連 6 新規キー (ja sourceLanguage + en translation) |
| Modify | `app/OtetsudaiCoinTests/Helpers/TestMocks.swift` | `MockHelpRecordRepository` に `failingHelpTaskIds: Set<UUID>` プロパティ追加 |
| Modify | `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` | 一括記録テスト 6 件追加 |
| Create | `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` | ViewInspector による UI 構造テスト 2 件 (新規ファイル) |

**変更しないファイル**:

- `app/OtetsudaiCoin/Domain/Entities/HelpRecord.swift` (model 変更なし、id ごと 1 件 = 1 record)
- `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift` (model 変更なし)
- `app/OtetsudaiCoin/Presentation/ViewModels/Base/BaseViewModel.swift` (setError / setSuccess 等を再利用)

---

## Pre-flight Verification

- [ ] **Branch 確認 (CLAUDE.md ルール)**

Run:
```bash
git status
```
Expected: `On branch feat/issue-69-bulk-record`、working tree clean (spec の自己修正 commit `60c6a59` 含む 2 commits ahead of main)。

- [ ] **origin 同期確認 (CLAUDE.md ルール)**

Run:
```bash
git fetch origin && git log --oneline -1 origin/main
```
Expected: origin/main は `97e7515` 以降 (#49 RecordView バナー対応の merge commit より新しい)。

- [ ] **既存 PR の重複確認 (CLAUDE.md ルール)**

Run:
```bash
gh pr list --head feat/issue-69-bulk-record --json number,state,title
```
Expected: `[]` (空配列)。並列セッションが先に PR を作っていないこと。

---

## Task 1: TestMocks に partial-failure 模擬を追加

**Files:**
- Modify: `app/OtetsudaiCoinTests/Helpers/TestMocks.swift` (`MockHelpRecordRepository`, line 121-191)

部分失敗ケースをテストするため、特定の `helpTaskId` のみ失敗させられるように mock を拡張する。`shouldThrowError = true` (全件失敗) は既存挙動として残す。

- [ ] **Step 1: `MockHelpRecordRepository` に `failingHelpTaskIds` を追加**

`MockHelpRecordRepository` のプロパティ定義部 (line 121〜125 付近、`var records: [HelpRecord] = []` の直後) に追加:

```swift
class MockHelpRecordRepository: HelpRecordRepository {
    var records: [HelpRecord] = []
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
    var failingHelpTaskIds: Set<UUID> = []
    var findCallCount = 0
```

- [ ] **Step 2: `save()` を拡張**

既存の `save()` (line 127〜132):

```swift
    func save(_ record: HelpRecord) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        records.append(record)
    }
```

を次に置き換える:

```swift
    func save(_ record: HelpRecord) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        if failingHelpTaskIds.contains(record.helpTaskId) {
            throw errorToThrow
        }
        records.append(record)
    }
```

- [ ] **Step 3: build が通ることだけ確認 (test 実行はまだ)**

Run:
```bash
xcodebuild build-for-testing -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED` で終わる。warning は無視可。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinTests/Helpers/TestMocks.swift
git commit -m "test(#69): MockHelpRecordRepository に partial-failure 模擬プロパティ追加"
```

---

## Task 2: Localizable.xcstrings に新規キー 6 件追加

**Files:**
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`

xcstrings-bulk-update skill の方針に従い (Python `json.dump` で整形を壊さないこと、既存翻訳を上書きしないこと)、Edit ツールで挿入する。

追加するキー一覧 (`sourceLanguage: ja` のためキー自体は ja の表記):

| key (ja) | en value |
|---|---|
| `一括モード` | `Bulk Mode` |
| `%lld 件をまとめて記録する` | `Record %lld items` |
| `選択中 %lld 件 / 計 %lld コイン` | `%lld selected / %lld coins` |
| `%lld 件記録しました！` | `Recorded %lld items!` |
| `%lld 件失敗、もう一度タップしてください` | `%lld failed, tap to retry` |
| `記録に失敗しました` | `Failed to record` |

- [ ] **Step 1: xcstrings の現在末尾を確認**

Run:
```bash
tail -30 app/OtetsudaiCoin/Resources/Localizable.xcstrings
```
末尾 2 行が
```
  "version" : "1.0"
}
```
であることを確認 (top-level の閉じ波括弧)。`"strings" : { ... }` の閉じ波括弧の直前に新規エントリを追加する。

- [ ] **Step 2: 既存キー (例えば `"記録する"`) を grep で位置確認**

Run:
```bash
grep -n '"記録する"' app/OtetsudaiCoin/Resources/Localizable.xcstrings | head -5
```
Expected: 既に存在するキーの位置を確認。挿入は `"strings"` ブロックの末尾 (`"version"` の直前) に行う。

- [ ] **Step 3: 6 キーをまとめて挿入**

`"strings"` ブロック末尾の閉じ波括弧 (`}` の前に `,`) の直前に下記を挿入:

```json
    "一括モード" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bulk Mode"
          }
        }
      }
    },
    "%lld 件をまとめて記録する" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Record %lld items"
          }
        }
      }
    },
    "選択中 %lld 件 / 計 %lld コイン" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%1$lld selected / %2$lld coins"
          }
        }
      }
    },
    "%lld 件記録しました！" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Recorded %lld items!"
          }
        }
      }
    },
    "%lld 件失敗、もう一度タップしてください" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%lld failed, tap to retry"
          }
        }
      }
    },
    "記録に失敗しました" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Failed to record"
          }
        }
      }
    }
```

挿入後、既存末尾キー (挿入位置直前のエントリ) の閉じ波括弧の後ろに `,` があることを確認すること。

- [ ] **Step 4: JSON 妥当性検証**

Run:
```bash
python3 -m json.tool app/OtetsudaiCoin/Resources/Localizable.xcstrings > /dev/null && echo OK
```
Expected: `OK` (JSON として valid)。失敗した場合は jq や json.tool が示すエラー位置を確認して fix。

- [ ] **Step 5: LocalizationStringCatalogTests 実行**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests 2>&1 | tail -15
```
Expected: `Test Suite 'LocalizationStringCatalogTests' passed` または該当テスト全 PASS。

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Resources/Localizable.xcstrings
git commit -m "i18n(#69): 一括記録機能用の文字列 6 キーを ja/en で追加"
```

---

## Task 3: RecordViewModel に isBulkMode と toggleBulkMode を追加 (TDD)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Failing test を追加** (`RecordViewModelTests.swift` の最後の `}` の直前に挿入)

```swift
    @MainActor
    func test_toggleBulkMode_resetsSelections() {
        // Given: 1 件モードで何かしら選択済み
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)
        viewModel.selectedTask = task
        XCTAssertFalse(viewModel.isBulkMode)

        // When: 一括モードに切替
        viewModel.toggleBulkMode()

        // Then: bulk mode on、selectedTask は nil、selectedTaskIds は empty
        XCTAssertTrue(viewModel.isBulkMode)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)

        // When: 一括モードで何か選択して 1 件モードに戻す
        viewModel.selectedTaskIds.insert(task.id)
        viewModel.toggleBulkMode()

        // Then: bulk mode off、両 selection 空に
        XCTAssertFalse(viewModel.isBulkMode)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
    }
```

- [ ] **Step 2: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_toggleBulkMode_resetsSelections 2>&1 | tail -20
```
Expected: コンパイルエラー `Value of type 'RecordViewModel' has no member 'isBulkMode'` 等。

- [ ] **Step 3: `RecordViewModel.swift` にプロパティと method を追加**

`RecordViewModel` クラスの既存 `var recordedDate: Date = Date()` (line 13) の直後に追加:

```swift
    var recordedDate: Date = Date()
    var hasRecordedInSession: Bool = false
    var isBulkMode: Bool = false
    var selectedTaskIds: Set<UUID> = []
```

そして `resetSessionState()` (line 16〜20) の直後に新規メソッド追加:

```swift
    func toggleBulkMode() {
        isBulkMode.toggle()
        selectedTask = nil
        selectedTaskIds = []
        clearErrorMessage()
    }
```

- [ ] **Step 4: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_toggleBulkMode_resetsSelections 2>&1 | tail -10
```
Expected: `Test Case '-[OtetsudaiCoinTests.RecordViewModelTests test_toggleBulkMode_resetsSelections]' passed`。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#69): RecordViewModel に isBulkMode と toggleBulkMode を追加"
```

---

## Task 4: Child 切替時の selectedTaskIds reset (TDD)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` (`selectChild` メソッド)
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Failing test 追加**

```swift
    @MainActor
    func test_selectChild_resetsBulkSelection() {
        // Given: 一括モードで複数選択済み
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [UUID(), UUID(), UUID()]
        viewModel.selectChild(child1)
        XCTAssertEqual(viewModel.selectedTaskIds.count, 3)

        // When: 別の child に切替
        viewModel.selectChild(child2)

        // Then: selectedTaskIds が空になる
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
        XCTAssertEqual(viewModel.selectedChild?.id, child2.id)
    }
```

- [ ] **Step 2: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_selectChild_resetsBulkSelection 2>&1 | tail -10
```
Expected: アサーション失敗 (`selectedTaskIds.isEmpty == false`)。

- [ ] **Step 3: `selectChild(_:)` を拡張**

既存 (line 140〜144):

```swift
    func selectChild(_ child: Child) {
        selectedChild = child
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
    }
```

を次に置き換え:

```swift
    func selectChild(_ child: Child) {
        let isDifferentChild = selectedChild?.id != child.id
        selectedChild = child
        if isDifferentChild {
            selectedTaskIds = []
            selectedTask = nil
        }
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
    }
```

注: `isDifferentChild` 判定により、同じ child を再 tap した場合は selection を保持する。

- [ ] **Step 4: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_selectChild_resetsBulkSelection 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 5: 既存テスト regression check**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 | tail -25
```
Expected: 全テスト PASS。失敗があれば selectedTask = nil の副作用が問題ないか確認 (既存テストは初回 selectChild 想定なので isDifferentChild = true で従来挙動と等価)。

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#69): selectChild で別 child 切替時に selectedTask/selectedTaskIds を reset"
```

---

## Task 5: recordBulkHelp() 全件成功 + コインアニメ合計 (TDD)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Failing test 追加**

```swift
    @MainActor
    func test_recordBulkHelp_allSuccess() async {
        // Given: child 選択済み、tasks 3 件選択 (coinRate 10/20/30)
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        let t3 = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 30)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2, t3]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id, t3.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 3 件保存、selectedTaskIds 空、合計 60 コイン、success メッセージ
        XCTAssertEqual(mockHelpRecordRepository.records.count, 3)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 60)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
    }
```

- [ ] **Step 2: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_allSuccess 2>&1 | tail -10
```
Expected: コンパイルエラー `no member 'recordBulkHelp'`。

- [ ] **Step 3: `recordBulkHelp()` を実装**

`recordHelp()` (line 156〜) の直後に追加:

```swift
    @MainActor
    func recordBulkHelp() {
        clearErrorMessage()

        guard let child = selectedChild else {
            setError(String(localized: "お子様を選択してください"))
            return
        }
        guard !selectedTaskIds.isEmpty else {
            return
        }

        let targetIds = selectedTaskIds
        let tasksById = Dictionary(uniqueKeysWithValues: availableTasks.map { ($0.id, $0) })

        setLoading(true)

        Task {
            var successIds: Set<UUID> = []
            var failureIds: Set<UUID> = []
            var totalCoins = 0
            let normalizedDate = Self.normalizeToNoon(recordedDate)

            for taskId in targetIds {
                guard let task = tasksById[taskId] else {
                    failureIds.insert(taskId)
                    continue
                }
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: taskId,
                    recordedAt: normalizedDate
                )
                do {
                    try await helpRecordRepository.save(helpRecord)
                    successIds.insert(taskId)
                    totalCoins += task.coinRate
                } catch {
                    failureIds.insert(taskId)
                }
            }

            // 効果音 (成功 1 件以上で再生)
            if !successIds.isEmpty {
                do {
                    try soundService.playCoinEarnSound()
                    try soundService.playTaskCompleteSound()
                } catch {
                    try? soundService.playErrorSound()
                }
            }

            lastRecordedCoinValue = totalCoins
            selectedTaskIds = failureIds

            NotificationManager.shared.notifyHelpRecordUpdated()

            if !successIds.isEmpty {
                hasRecordedInSession = true
                let format = String(localized: "%lld 件記録しました！")
                setSuccess(String(format: format, successIds.count))
            }
            if successIds.isEmpty && !failureIds.isEmpty {
                setError(String(localized: "記録に失敗しました"))
            }
            setLoading(false)
        }
    }
```

- [ ] **Step 4: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_allSuccess 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#69): recordBulkHelp() を追加し全件成功時に成功分のコイン合計値を反映"
```

---

## Task 6: recordBulkHelp() 部分失敗時に失敗のみ残す (TDD)

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

実装は Task 5 で完成済み (`failureIds` を `selectedTaskIds` に再代入する logic)。本タスクはそのテストを追加し挙動を保証する。

- [ ] **Step 1: Failing test 追加**

```swift
    @MainActor
    func test_recordBulkHelp_partialFailure_failedRemain() async {
        // Given: 3 件選択、うち中央 1 件 (t2) のみ save 失敗
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        let t3 = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 30)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2, t3]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id, t3.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t2.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 2 件保存、失敗 1 件のみ selectedTaskIds に残る、合計コイン 40
        XCTAssertEqual(mockHelpRecordRepository.records.count, 2)
        XCTAssertEqual(viewModel.selectedTaskIds, [t2.id])
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 40)
        XCTAssertNotNil(viewModel.successMessage) // 成功分があるので success メッセージは出る
    }
```

- [ ] **Step 2: テスト PASS 確認 (実装は Task 5 で完了済みなのでそのまま緑になるはず)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_partialFailure_failedRemain 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 3: Commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "test(#69): recordBulkHelp 部分失敗時に失敗のみ selectedTaskIds に残る挙動を検証"
```

---

## Task 7: recordBulkHelp() 全件失敗時 (TDD)

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`

- [ ] **Step 1: Failing test 追加**

```swift
    @MainActor
    func test_recordBulkHelp_allFailed() async {
        // Given: 2 件選択、全件 save 失敗 (shouldThrowError 全体 ON)
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]
        mockHelpRecordRepository.shouldThrowError = true

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 0 件保存、選択は全て残る、error メッセージ
        XCTAssertEqual(mockHelpRecordRepository.records.count, 0)
        XCTAssertEqual(viewModel.selectedTaskIds, [t1.id, t2.id])
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 0)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertNotNil(viewModel.errorMessage)
    }
```

- [ ] **Step 2: テスト PASS 確認**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_allFailed 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 3: 全 RecordViewModelTests を回して regression check**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 | tail -30
```
Expected: 全 PASS。flake が疑われる場合 `xcodebuild test -only-testing:` で個別再実行 (CLAUDE.md iOS テスト flake 切り分けルール)。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "test(#69): recordBulkHelp 全件失敗時に error メッセージと選択保持を検証"
```

---

## Task 8: RecordViewTests スケルトン + bulkModeToggle 存在テスト (TDD)

**Files:**
- Create: `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift`
- Modify (red→green 過程で): `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`

`HomeViewTests.swift` の ViewInspector パターンを参照しつつ、`RecordViewModelTests.swift` の RecordViewModel dependencies (4 つ) を inject する形で組む。

- [ ] **Step 1: HomeViewTests.swift の構造を確認**

Run:
```bash
sed -n '1,40p' app/OtetsudaiCoinTests/Presentation/Views/HomeViewTests.swift
```
Expected: `@testable import OtetsudaiCoin` と ViewInspector の import、 `final class HomeViewTests: XCTestCase` の骨格、`setUp` での mock 生成パターンが見える。

- [ ] **Step 2: RecordViewTests.swift を新規作成**

`app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` を新規作成し以下を書く:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class RecordViewTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!

    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockSoundService = MockSoundService()
        viewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockSoundService = nil
        mockHelpRecordRepository = nil
        mockHelpTaskRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }

    func test_recordView_has_bulkModeToggle() throws {
        let view = RecordView(viewModel: viewModel)
        let toggle = try view.inspect().find(ViewType.Toggle.self)
        let labelText = try toggle.labelView().text().string()
        XCTAssertTrue(labelText.contains("一括モード"), "toolbar に '一括モード' Toggle が存在すること")
    }
}
```

- [ ] **Step 3: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_has_bulkModeToggle 2>&1 | tail -15
```
Expected: テスト失敗 (Toggle が見つからない、`InspectionError` 系)。

- [ ] **Step 4: RecordView の `NavigationStack` に `toolbar` 追加**

`RecordView.swift` の `.navigationTitle("お手伝い記録")` (line 60) の直後に `.toolbar` 修飾子を追加:

```swift
                .navigationTitle("お手伝い記録")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Toggle("一括モード", isOn: Binding(
                            get: { viewModel.isBulkMode },
                            set: { _ in viewModel.toggleBulkMode() }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityIdentifier("bulk_mode_toggle")
                        .accessibilityLabel(Text("一括モード"))
                    }
                }
                .onAppear {
```

注: `labelsHidden()` で見た目はスイッチのみ。`accessibilityLabel` で VoiceOver/テスト判定用にラベル文字列を保持する。ViewInspector の `labelView().text()` は `accessibilityLabel` ではなく `Toggle` の label 引数を見るので、Toggle 自体に `"一括モード"` を渡す。

- [ ] **Step 5: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_has_bulkModeToggle 2>&1 | tail -10
```
Expected: PASS。fail なら `find(ViewType.Toggle.self)` のパスを `find(viewWithAccessibilityIdentifier:)` 等に置き換えて再度試行。

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "feat(#69): RecordView toolbar に '一括モード' Toggle を追加"
```

---

## Task 9: TaskCardView を bulk mode 表示分岐に対応

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` (`TaskCardView` 内 + `taskListView` の呼び出し)

bulk mode の判定を `TaskCardView` に渡し、左上角に checkbox 風アイコンを表示。色変化は既存 `isSelected` を流用 (bulk 時は `selectedTaskIds.contains` を渡す)。

- [ ] **Step 1: `taskListView` の `TaskCardView` 呼び出しを bulk 対応に**

`RecordView.swift` の `taskListView` 内 (line 187〜199 付近)、既存:

```swift
                    ForEach(viewModel.availableTasks, id: \.id) { task in
                        TaskCardView(
                            task: task,
                            isSelected: viewModel.selectedTask?.id == task.id,
                            onTap: {
                                viewModel.selectTask(task)
                            }
                        )
                        .accessibilityIdentifier("task_button")
                    }
```

を次に置き換え:

```swift
                    ForEach(viewModel.availableTasks, id: \.id) { task in
                        TaskCardView(
                            task: task,
                            isSelected: viewModel.isBulkMode
                                ? viewModel.selectedTaskIds.contains(task.id)
                                : viewModel.selectedTask?.id == task.id,
                            isBulkMode: viewModel.isBulkMode,
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

- [ ] **Step 2: `TaskCardView` に `isBulkMode` パラメータを追加**

既存 `struct TaskCardView: View` (line 246〜) の冒頭 (`let onTap: () -> Void` の直後) に追加:

```swift
struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    let onTap: () -> Void
```

- [ ] **Step 3: `selectionIndicator` を bulk mode 用に変更**

既存 `selectionIndicator` (line 296〜304):

```swift
    private var selectionIndicator: some View {
        Group {
            if isSelected {
                selectedIndicator
            } else {
                unselectedIndicator
            }
        }
    }
```

を次に置き換え:

```swift
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
```

- [ ] **Step 4: Build 通過確認**

Run:
```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "feat(#69): TaskCardView を bulk mode 対応、選択 indicator を checkbox 表示に分岐"
```

---

## Task 10: recordButtonView の mode 別 label + bulk summary 表示 (TDD)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` (`recordButtonView`)
- Modify: `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift`

- [ ] **Step 1: Failing test 追加**

```swift
    func test_recordView_bulkMode_recordButton_label() throws {
        // Given: bulk mode で 2 件選択中
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]

        // When
        let view = RecordView(viewModel: viewModel)
        let button = try view.inspect().find(viewWithAccessibilityIdentifier: "record_button")
        let labelText = try button.find(ViewType.Text.self, where: { (text, _) in
            let s = (try? text.string()) ?? ""
            return s.contains("2 件をまとめて記録する")
        })

        // Then
        XCTAssertNotNil(labelText)
    }
```

- [ ] **Step 2: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_bulkMode_recordButton_label 2>&1 | tail -10
```
Expected: 失敗 (`"2 件をまとめて記録する"` テキストが見つからない)。

- [ ] **Step 3: `recordButtonView` を mode 別 label + summary に変更**

既存 `recordButtonView` (line 203〜243) を次に置き換える:

```swift
    private var recordButtonView: some View {
        VStack(spacing: 8) {
            // 選択状態の表示
            if viewModel.isBulkMode {
                bulkSummaryView
            } else if let selectedChild = viewModel.selectedChild, let selectedTask = viewModel.selectedTask {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(selectedChild.name)さんの「\(selectedTask.name)」")
                        .appFont(.captionText)
                        .foregroundColor(.secondary)
                    Text("\(selectedTask.coinRate)コイン")
                        .appFont(.captionText)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("お手伝いする人とタスクを選んでください")
                        .appFont(.captionText)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // 記録ボタン
            Button(action: {
                if viewModel.isBulkMode {
                    viewModel.recordBulkHelp()
                } else {
                    viewModel.recordHelp()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(recordButtonLabel)
                }
            }
            .successGradientButton(isDisabled: recordButtonDisabled)
            .disabled(recordButtonDisabled)
            .accessibilityIdentifier("record_button")
        }
    }

    private var recordButtonLabel: String {
        if viewModel.isBulkMode {
            let count = viewModel.selectedTaskIds.count
            let format = String(localized: "%lld 件をまとめて記録する")
            return String(format: format, count)
        } else {
            return String(localized: "記録する")
        }
    }

    private var recordButtonDisabled: Bool {
        if viewModel.isBulkMode {
            return viewModel.selectedChild == nil || viewModel.selectedTaskIds.isEmpty
        } else {
            return viewModel.selectedChild == nil || viewModel.selectedTask == nil
        }
    }

    private var bulkSummaryView: some View {
        let count = viewModel.selectedTaskIds.count
        let tasksById = Dictionary(uniqueKeysWithValues: viewModel.availableTasks.map { ($0.id, $0) })
        let totalCoins = viewModel.selectedTaskIds.reduce(0) { acc, id in
            acc + (tasksById[id]?.coinRate ?? 0)
        }
        let format = String(localized: "選択中 %lld 件 / 計 %lld コイン")
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(String(format: format, count, totalCoins))
                .appFont(.captionText)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
```

- [ ] **Step 4: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_bulkMode_recordButton_label 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift
git commit -m "feat(#69): recordButtonView を mode 別 label に分岐、bulk summary を表示"
```

---

## Task 11: 部分失敗 warning row 表示

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` (success message 表示部分の下)
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` (warning message プロパティ追加)
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` (test 1 件追加)

部分失敗時は `successMessage` + `warningMessage` (新規) を両方表示する。`errorMessage` は全件失敗時のみ。

- [ ] **Step 1: Failing test 追加**

`RecordViewModelTests.swift` に追加:

```swift
    @MainActor
    func test_recordBulkHelp_partialFailure_setsWarningMessage() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t1.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertNotNil(viewModel.warningMessage)
        XCTAssertTrue(viewModel.warningMessage?.contains("1") ?? false)
    }
```

- [ ] **Step 2: テスト失敗確認 (red)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_partialFailure_setsWarningMessage 2>&1 | tail -10
```
Expected: コンパイルエラー `no member 'warningMessage'`。

- [ ] **Step 3: `RecordViewModel` に `warningMessage` プロパティと `setWarning()`/clearWarning logic を追加**

`var selectedTaskIds: Set<UUID> = []` の直後に追加:

```swift
    var isBulkMode: Bool = false
    var selectedTaskIds: Set<UUID> = []
    var warningMessage: String? = nil
```

`recordBulkHelp()` 内、`if !successIds.isEmpty { ... setSuccess(...) }` ブロックの直後に warning 設定 logic を追加:

既存:
```swift
            if !successIds.isEmpty {
                hasRecordedInSession = true
                let format = String(localized: "%lld 件記録しました！")
                setSuccess(String(format: format, successIds.count))
            }
            if successIds.isEmpty && !failureIds.isEmpty {
                setError(String(localized: "記録に失敗しました"))
            }
```

を次に置き換え:
```swift
            if !successIds.isEmpty {
                hasRecordedInSession = true
                let format = String(localized: "%lld 件記録しました！")
                setSuccess(String(format: format, successIds.count))
            }
            if !successIds.isEmpty && !failureIds.isEmpty {
                let format = String(localized: "%lld 件失敗、もう一度タップしてください")
                warningMessage = String(format: format, failureIds.count)
            } else {
                warningMessage = nil
            }
            if successIds.isEmpty && !failureIds.isEmpty {
                setError(String(localized: "記録に失敗しました"))
            }
```

`recordBulkHelp()` の冒頭 `clearErrorMessage()` の直後に `warningMessage = nil` を追加:
```swift
    @MainActor
    func recordBulkHelp() {
        clearErrorMessage()
        warningMessage = nil
```

- [ ] **Step 4: テスト PASS 確認 (green)**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/test_recordBulkHelp_partialFailure_setsWarningMessage 2>&1 | tail -10
```
Expected: PASS。

- [ ] **Step 5: RecordView に warning row を追加**

`RecordView.swift` の `successMessage` 表示ブロック (line 20〜31) の直後に warning row を追加:

既存:
```swift
                                    if let successMessage = viewModel.successMessage {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AccessibilityColors.successGreen)
                                            Text(successMessage)
                                                .appFont(.buttonText)
                                                .foregroundColor(AccessibilityColors.successGreen)
                                        }
                                        .padding()
                                        .background(AccessibilityColors.successGreenLight)
                                        .cornerRadius(8)
                                    }
```

の直後 (`childSelectionView` の直前) に追加:

```swift
                                    if let warningMessage = viewModel.warningMessage {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text(warningMessage)
                                                .appFont(.buttonText)
                                                .foregroundColor(.orange)
                                        }
                                        .padding()
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(8)
                                    }
```

- [ ] **Step 6: Build 通過確認**

Run:
```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 7: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift app/OtetsudaiCoin/Presentation/Views/RecordView.swift app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat(#69): 部分失敗時に warningMessage を表示し、リトライ導線を提示"
```

---

## Task 12: 全テスト実行で regression check

**Files:** 変更なし

- [ ] **Step 1: 全テスト実行**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40
```
Expected: 全 PASS。`TEST SUCCEEDED` で終わる。

- [ ] **Step 2: flake suspicion テストの個別再実行**

並列実行で UI テストや load 系がランダム失敗する場合、CLAUDE.md ルールに従い該当テストを個別実行:

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/<疑わしいテストクラス名> 2>&1 | tail -15
```
個別で PASS すれば parallel flake として regression ではないと判定。

- [ ] **Step 3: 失敗があれば修正、再実行**

regression があれば原因を特定して修正、再度全テスト実行。

---

## Task 13: Simulator で手動 verification (ios-simulator-app-verification skill 参照)

**Files:** 変更なし

- [ ] **Step 1: ビルド + 起動**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`。

Run:
```bash
xcrun simctl boot "iPhone 16" || true
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/OtetsudaiCoin-*/Build/Products/Debug-iphonesimulator/OtetsudaiCoin.app
xcrun simctl launch booted com.asapapalab.OtetsudaiCoin
```
Expected: アプリが起動して "お手伝い記録" タブに遷移可能。

- [ ] **Step 2: 一括モードの golden path**

UI を手動操作するか、UserDefaults でセットアップ完了状態に飛ばす (ios-simulator-app-verification skill の手順)。

確認項目:

1. "お手伝い記録" タブを開く → toolbar 右上に "一括モード" Toggle が見える
2. Toggle を ON → task カードが checkbox 表示に変わる
3. 2〜3 件タップ → "選択中 N 件 / 計 M コイン" が表示される
4. "N 件をまとめて記録する" ボタンが label 変化 + enable
5. ボタン tap → コインアニメ (合計値) + success message
6. 選択がクリアされ、checkbox は全 unchecked に戻る
7. Toggle を OFF → 1 件モードに戻り、既存 flow が動く

- [ ] **Step 3: スクリーンショット取得**

```bash
xcrun simctl io booted screenshot /tmp/issue-69-bulk-mode-1.png
```
PR の test plan 用に 1〜2 枚撮っておく。

- [ ] **Step 4: 検証結果メモ**

`PR` description に貼る用に、確認した項目と発見した issue (もしあれば) を書き出す。

---

## Task 14: Push + PR 作成 (finishing-a-development-branch skill 参照)

**Files:** 変更なし

- [ ] **Step 1: コミットログ確認**

Run:
```bash
git log --oneline origin/main..HEAD
```
Expected: Task 1〜11 のコミットがリストされる (概ね 11 件)。

- [ ] **Step 2: Push**

```bash
git push -u origin feat/issue-69-bulk-record
```

- [ ] **Step 3: 既存 PR 重複再確認 (CLAUDE.md ルール)**

```bash
gh pr list --head feat/issue-69-bulk-record --json number,state,title
```
Expected: `[]`。並列セッション PR が無い。

- [ ] **Step 4: PR 作成**

```bash
gh pr create --title "feat(#69): お手伝いを複数選択して一括記録できる UX を追加" --body "$(cat <<'EOF'
## Summary

issue #69: 1 日の終わりにまとめて記録したいときの UX 改善。

- RecordView の toolbar に "一括モード" Toggle を追加
- bulk mode 時は TaskCard が checkbox 表示に切り替わり、複数選択可能
- "N 件をまとめて記録する" ボタンで一括 save → コインアニメは合計値
- 部分失敗時は成功分のみ DB に保存、失敗分のみ selectedTaskIds に残り再度タップでリトライ可能 (warning row 表示)
- Child 切替 / mode 切替 で両 selection を reset

## Spec / Plan

- Spec: docs/superpowers/specs/2026-05-19-issue-69-bulk-record-design.md
- Plan: docs/superpowers/plans/2026-05-19-issue-69-bulk-record.md

## Test plan

- [x] RecordViewModelTests: bulk mode toggle / child reset / 全件成功 / 部分失敗 / 全件失敗 / warning message (6 件追加)
- [x] RecordViewTests: bulkModeToggle 存在 + recordButton bulk label (2 件、新規ファイル)
- [x] LocalizationStringCatalogTests PASS
- [x] xcodebuild test 全 PASS
- [x] Simulator で golden path 手動確認 (スクショ添付)
- [ ] Reviewer 確認後 merge

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: PR URL を確認**

Expected: `https://github.com/es0612/OtetsudaiCoin/pull/<番号>` が返る。URL をユーザーに共有。

- [ ] **Step 6: CI 状態確認**

```bash
gh pr checks $(gh pr list --head feat/issue-69-bulk-record --json number --jq '.[0].number')
```
Expected: 全 check が pass、または in_progress。失敗があれば原因確認し修正 commit を push。

---

## Done Criteria

- All 14 tasks completed (チェックボックス全埋め)
- `xcodebuild test` 全 PASS
- Simulator で一括モード ON/OFF, 部分失敗時の warning row, コインアニメ合計値 が動作確認済
- PR が CI green
- Reviewer 承認待ち
