# 過去日付指定でのお手伝い登録 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** イシュー #20「過去の日付を指定してお手伝い登録したい」を実装する。`RecordView` の登録フローに常時表示の DatePicker を追加し、保護者が「後でまとめて入力」できるようにする。

**Architecture:** `RecordViewModel` に `recordedDate: Date` プロパティを追加（@Observable）し、`recordHelp()` で日付を当日 12:00 にスナップして `HelpRecord.recordedAt` に渡す。View 側は `dateSection` を子供選択とタスク選択の間に挿入。永続化なし（ViewModel のライフサイクル内のみ保持）。

**Tech Stack:** Swift, SwiftUI, XCTest, UserNotifications, Calendar

**Spec:** `docs/superpowers/specs/2026-05-10-past-date-help-record-design.md`

**事前状態:**
- ブランチ `feat/past-date-help-record` 作成済み
- 設計書コミット済み (`e674840`)
- main は `origin/main` と同期済み

---

## File Structure

### 修正ファイル

| パス | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` | `recordedDate: Date` プロパティ追加、`recordHelp()` で 12:00 スナップして利用 |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | `dateSection` を新規追加、`childSelectionView` と `taskListView` の間に配置 |
| `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` | テスト 4 件追加（初期値・スナップ・持続・リセット） |

### 新規ファイルなし

### 注意点

- プロジェクトは `PBXFileSystemSynchronizedRootGroup` を採用しているため、Xcode への手動ファイル追加は不要
- テスト destination は `iPhone 16 Pro, OS=18.5`（プロジェクトの IPHONEOS_DEPLOYMENT_TARGET と一致）
- 「記録日」の文字列は `String(localized: "記録日")` で書けば Xcode が `Localizable.xcstrings` に自動抽出する

---

## Task 1: recordedDate プロパティ追加（RED → GREEN）

**目的:** `RecordViewModel` に新しい状態 `recordedDate` を追加。デフォルトは今日、別インスタンスを作っても今日にリセットされる（永続化なし）ことを保証。

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` (テスト追加)
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` (プロパティ追加)

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` の `testClearMessages` の後に以下 2 つのテストを追加：

```swift
    // MARK: - 記録日（過去日付登録機能）

    @MainActor
    func testRecordedDateDefaultsToToday() {
        // Given: ViewModel が初期化された直後
        // When: recordedDate を読む
        // Then: 今日の日付が入っている
        XCTAssertTrue(
            Calendar.current.isDateInToday(viewModel.recordedDate),
            "ViewModel 初期化時の recordedDate が今日でない: \(viewModel.recordedDate)"
        )
    }

    @MainActor
    func testRecordedDateResetsToTodayOnNewViewModelInstance() {
        // Given: 既存 ViewModel で過去の日付を選択
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        viewModel.recordedDate = pastDate

        // When: 新しい ViewModel インスタンスを作成（永続化されないことの確認）
        let newViewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService
        )

        // Then: 新インスタンスは今日に戻っている
        XCTAssertTrue(
            Calendar.current.isDateInToday(newViewModel.recordedDate),
            "新 ViewModel の recordedDate が今日でない: \(newViewModel.recordedDate)"
        )
    }
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordedDateDefaultsToToday 2>&1 | tail -10
```

期待: コンパイルエラー `Value of type 'RecordViewModel' has no member 'recordedDate'`

- [ ] **Step 3: 最小実装でプロパティを追加**

`app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` の `lastRecordedCoinValue` の下、`hasRecordedInSession` の前に追加：

```swift
    var availableChildren: [Child] = []
    var availableTasks: [HelpTask] = []
    var selectedChild: Child?
    var selectedTask: HelpTask?
    var lastRecordedCoinValue: Int = 10
    var recordedDate: Date = Date()  // ★追加: 過去日付登録用
    var hasRecordedInSession: Bool = false
```

- [ ] **Step 4: テスト再実行で成功を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordedDateDefaultsToToday \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordedDateResetsToTodayOnNewViewModelInstance 2>&1 | tail -10
```

期待: TEST SUCCEEDED、両テスト PASS

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat: RecordViewModel に recordedDate プロパティを追加 (#20)"
```

---

## Task 2: recordHelp() で recordedDate を使用（12:00 スナップ）

**目的:** `recordHelp()` が `Date()` ではなく `recordedDate` を使うようにし、当日 12:00 にスナップして `HelpRecord.recordedAt` に渡す。これで過去日付指定が実機能となる。

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` (テスト追加)
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` (recordHelp() の中身変更)

- [ ] **Step 1: 失敗するテストを書く**

Task 1 で追加した 2 つのテストの後に追加：

```swift
    @MainActor
    func testRecordHelpUsesRecordedDateSnappedToNoon() async {
        // Given: 30 日前の日付を選択
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true)

        viewModel.selectChild(child)
        viewModel.selectTask(task)
        viewModel.recordedDate = pastDate

        // When: 記録する
        viewModel.recordHelp()

        let expectation = XCTestExpectation(description: "Record help with past date")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: 保存された record の recordedAt が pastDate と同日、かつ 12:00
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        let saved = mockHelpRecordRepository.records.first!

        let cal = Calendar.current
        XCTAssertTrue(
            cal.isDate(saved.recordedAt, inSameDayAs: pastDate),
            "保存された日付が選択日と異なる: saved=\(saved.recordedAt), expected=\(pastDate)"
        )
        let comps = cal.dateComponents([.hour, .minute, .second], from: saved.recordedAt)
        XCTAssertEqual(comps.hour, 12, "時刻が 12:00 にスナップされていない")
        XCTAssertEqual(comps.minute, 0, "分が 0 にスナップされていない")
        XCTAssertEqual(comps.second, 0, "秒が 0 にスナップされていない")
    }
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordHelpUsesRecordedDateSnappedToNoon 2>&1 | tail -10
```

期待: テストが FAIL する。理由は `recordHelp()` がまだ `Date()` を使っているため、保存される `recordedAt` が今日になり、`isDate(_, inSameDayAs:)` で false になる。

- [ ] **Step 3: recordHelp() を修正**

`app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` の `recordHelp()` 内、`HelpRecord` 生成箇所を変更：

変更前：
```swift
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: task.id,
                    recordedAt: Date()
                )
```

変更後：
```swift
                // recordedDate を当日 12:00 にスナップ（時刻まで意識させない設計）
                let normalizedDate = Self.normalizeToNoon(recordedDate)
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: task.id,
                    recordedAt: normalizedDate
                )
```

そして同ファイル末尾の `}` の直前（`recordHelp` メソッド外、クラス内）に static helper を追加：

```swift
    private static func normalizeToNoon(_ date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
    }
```

- [ ] **Step 4: テスト再実行で成功を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordHelpUsesRecordedDateSnappedToNoon 2>&1 | tail -10
```

期待: TEST SUCCEEDED

- [ ] **Step 5: 既存テストの回帰確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 | grep -E "TEST SUCC|TEST FAIL|failed " | head -10
```

期待: TEST SUCCEEDED（既存の `testRecordHelpSuccess` は `recordedAt` を assert していないため引き続き PASS する想定）

- [ ] **Step 6: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "feat: recordHelp() で recordedDate を使い 12:00 にスナップ (#20)"
```

---

## Task 3: 連続記録時の日付持続テスト

**目的:** 同 ViewModel で 2 回連続記録しても `recordedDate` がリセットされないことを保証。バッチ入力体験の根幹。

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` (テスト追加のみ、実装変更なし)

- [ ] **Step 1: テストを追加**

Task 2 で追加したテストの後に追加：

```swift
    @MainActor
    func testRecordedDatePersistsAcrossMultipleRecords() async {
        // Given: 過去日付を選択して 1 回目の記録
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task1 = HelpTask(id: UUID(), name: "皿洗い", isActive: true)
        let task2 = HelpTask(id: UUID(), name: "洗濯", isActive: true)

        viewModel.selectChild(child)
        viewModel.recordedDate = pastDate
        viewModel.selectTask(task1)
        viewModel.recordHelp()

        let exp1 = XCTestExpectation(description: "First record")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        await fulfillment(of: [exp1], timeout: 1.0)

        // When: 2 回目の記録（recordedDate は触らない）
        viewModel.selectTask(task2)
        viewModel.recordHelp()

        let exp2 = XCTestExpectation(description: "Second record")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        await fulfillment(of: [exp2], timeout: 1.0)

        // Then: 2 件保存され、両方 pastDate と同日（12:00）
        XCTAssertEqual(mockHelpRecordRepository.records.count, 2)
        let cal = Calendar.current
        for (index, record) in mockHelpRecordRepository.records.enumerated() {
            XCTAssertTrue(
                cal.isDate(record.recordedAt, inSameDayAs: pastDate),
                "\(index + 1) 件目の日付が異なる: \(record.recordedAt)"
            )
        }
        // recordedDate プロパティ自体も pastDate と同日のまま
        XCTAssertTrue(
            cal.isDate(viewModel.recordedDate, inSameDayAs: pastDate),
            "recordedDate が記録後にリセットされている: \(viewModel.recordedDate)"
        )
    }
```

- [ ] **Step 2: テスト実行で成功を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests/testRecordedDatePersistsAcrossMultipleRecords 2>&1 | tail -10
```

期待: TEST SUCCEEDED（Task 2 の実装で既に振る舞いが満たされている — recordHelp() は selectedTask は nil にするが recordedDate は触らない）

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "test: 連続記録時の recordedDate 持続を確認するテストを追加 (#20)"
```

---

## Task 4: RecordView に dateSection を追加

**目的:** UI に DatePicker を実装。子供選択とタスク選択の間に「記録日」セクションを挿入。未来日付は選択不可（DatePicker の `in:` 制約）。

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`

- [ ] **Step 1: dateSection コンピュテッドプロパティを追加**

`app/OtetsudaiCoin/Presentation/Views/RecordView.swift` の `private var childSelectionView` の上、または `private var childrenScrollView` の後あたり（`childSelectionView` 系のメソッド群の隣）に追加：

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
        }
        .padding(.horizontal)
    }
```

- [ ] **Step 2: dateSection を VStack に挿入**

同ファイルの `body` 内、`childSelectionView` と `taskListView` の間に挿入。具体的には：

変更前（行 33-35 付近）：
```swift
                                    childSelectionView
                                    
                                    taskListView
```

変更後：
```swift
                                    childSelectionView

                                    dateSection

                                    taskListView
```

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' 2>&1 | grep -E "BUILD|error:" | tail -10
```

期待: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 全テスト走らせて回帰なしを確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:OtetsudaiCoinTests 2>&1 | grep -E "TEST SUCC|TEST FAIL" | head -3
```

期待: `** TEST SUCCEEDED **`（既存の HomeViewTests / LocalizationStringCatalogTests の既知失敗を除く）

- [ ] **Step 5: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "feat: 記録画面に日付ピッカーを追加 (#20)"
```

---

## Task 5: シミュレータ手動確認

**目的:** 自動テストでは確認できない UI 操作・体験を実機相当でチェック。

**Files:** なし（手動確認のみ）

- [ ] **Step 1: シミュレータ起動 + アプリ実行**

Xcode を開き、`iPhone 16 Pro (OS 18.5)` シミュレータで Run。

- [ ] **Step 2: 確認チェックリスト**

以下を全て確認：

1. [ ] 記録タブを開くと「記録日」セクションが子供選択とタスクの間に表示される
2. [ ] DatePicker をタップ → 日付選択ダイアログが開く
3. [ ] 未来の日付（明日以降）はグレーアウトで選択できない
4. [ ] 1 ヶ月前の日付を選んで子供＋タスクを選び「記録する」
5. [ ] ホームタブに戻り、月別履歴で 1 ヶ月前の月にカウントされていることを確認
6. [ ] 記録タブに戻り、別のタスクを選んで再度「記録する」
7. [ ] 日付が前回選んだ 1 ヶ月前のまま保持されていることを確認
8. [ ] アプリを完全終了（タスクスイッチャーで上にスワイプ）
9. [ ] 再度起動して記録タブを開くと、日付が「今日」にリセットされていることを確認

- [ ] **Step 3: 問題があれば修正、なければ次タスクへ**

問題があれば修正コミットを作成。なければスキップ。

---

## Task 6: PR 作成

**Files:** なし（git/gh 操作のみ）

- [ ] **Step 1: ブランチを push**

```bash
git push -u origin feat/past-date-help-record
```

- [ ] **Step 2: PR body をファイル化**

`pr-body.md` を新規作成（gitignore 済み）：

```markdown
## Summary

- 記録画面（RecordView）に常時表示の DatePicker を追加し、過去日付でのお手伝い登録に対応
- 日付のみ選択可（時刻は当日 12:00 に自動スナップ）、未来禁止、過去無制限
- 同セッション内では選んだ日付が保持されてバッチ入力が楽
- アプリを完全終了して再起動すると今日にリセット（永続化なし）

## 設計書・実装プラン

- 設計書: `docs/superpowers/specs/2026-05-10-past-date-help-record-design.md`
- 実装プラン: `docs/superpowers/plans/2026-05-10-past-date-help-record.md`

## 実装の構造

修正:
- `Presentation/ViewModels/RecordViewModel.swift` — `recordedDate` プロパティ追加、`recordHelp()` で 12:00 スナップ
- `Presentation/Views/RecordView.swift` — `dateSection` を子供選択とタスク選択の間に挿入
- `Presentation/RecordViewModelTests.swift` — テスト 4 件追加

不変:
- `Domain/Entities/HelpRecord.swift` — 既存スキーマのまま
- `Presentation/Views/HelpRecordEditView.swift` — 編集画面はそのまま温存（責務分離）
- `Domain/Services/UnpaidAllowanceDetectorService.swift` — 既存の月単位判定が自動で過去月集計

## Test plan

- [x] `RecordViewModelTests` 全テスト PASS（新規 4 件含む）
- [ ] シミュレータ実行: 記録画面に日付ピッカーが表示される
- [ ] 過去日付で記録 → 月別履歴で該当月にカウント
- [ ] 未来日付選択不可
- [ ] 同セッション内で日付保持、再起動でリセット

## 既知のテスト状況（このPRに無関係）

PR #23 でも確認済みの既存失敗：
- `HomeViewTests.testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild`
- `LocalizationStringCatalogTests.testAllKeysHaveEnglishTranslation`

Closes #20

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- [ ] **Step 3: PR 作成**

```bash
gh pr create --title "feat: 過去日付指定でのお手伝い登録 (#20)" --body-file pr-body.md
```

- [ ] **Step 4: PR URL を確認・記録**

PR URL を控えてユーザーに共有。

---

## Self-Review チェックリスト

- [ ] 設計書の各セクションがプランで実装されているか確認
  - 1. 背景 → Task 1 で文脈
  - 2. 機能要件 → Task 1-4
  - 3. 非機能要件 → Task 1（永続化なし）, Task 5（手動確認）
  - 4. アーキテクチャ → Task 1, 2, 4
  - 5. データフロー → Task 2（12:00 スナップ）, Task 3（連続入力）
  - 6. 既存システムへの影響 → Task 5 手動確認 (5)
  - 7. UI 詳細 → Task 4
  - 8. テスト戦略 → Task 1-3 + Task 5

- [ ] 各タスクに `[ ]` チェックボックスがある
- [ ] コード例にプレースホルダなし
- [ ] 型名・メソッド名がタスク間で一貫（`recordedDate`、`normalizeToNoon`、`dateSection`）
- [ ] 各タスクで `git commit` 手順が含まれる

---

## メモ・実装上の注意点

1. **Localizable.xcstrings の手動更新は不要**: `String(localized: "記録日")` を書けば Xcode のビルドが xcstrings に自動エントリ追加。テスト的に PASS する。
2. **既存 `testRecordHelpSuccess` の挙動**: 現状このテストは `recordedAt` を直接 assert していないので、Task 2 の実装後も PASS する想定。万一 FAIL したら、デフォルト `recordedDate = Date()` で当日 12:00 が保存されるだけなので、テスト側で `cal.isDate(_, inSameDayAs: Date())` を確認するように調整する。
3. **flaky テストへの注意**: `HelpHistoryViewModelTests.testDeleteRecord` と `HelpRecordEditViewModelTests.testLoadDataError` は並列実行時に稀に失敗する既知 flaky。Task 4 Step 4 の全テストで失敗が見えても、単独実行で PASS することを確認すれば OK。
