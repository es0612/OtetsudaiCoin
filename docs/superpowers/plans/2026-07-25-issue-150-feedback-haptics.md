# 演出強化（ハプティクス配線 + サウンド/触覚 OFF 設定）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 未使用の `HapticFeedback` を記録・選択の各操作へ配線し、設定画面から効果音と触覚を個別に OFF にできるようにする（#150 提案 1・3・4）。

**Architecture:** 設定値は `FeedbackSettingsService` が `UserDefaults` を毎回読む形で提供し（キャッシュしない）、触覚は `HapticFeedbackProviding` protocol 越しに発火する。ON/OFF の判定は `RecordViewModel` 側で行い、既存の `MockSoundService` spy をそのまま使って「OFF なら鳴らさない」を検証できるようにする。

**Tech Stack:** Swift 5 / SwiftUI / `@Observable` / XCTest / UserDefaults / UIKit `UIFeedbackGenerator`（既存 `HapticFeedback` 経由）

**Spec:** `docs/superpowers/specs/2026-07-25-issue-150-feedback-haptics-design.md`

## Global Constraints

- ブランチは `feature/issue-150-feedback-haptics`（作成済み・spec commit 済み）。新規ブランチを切らない
- **`xcodebuild` は必ず FOREGROUND で実行する**（background 実行は結果未確認のまま停止する事故が既往）
- **テスト結果は exit code で判定しない**。`grep -E "\*\* TEST|Failing tests"` で判定行を抽出し、`** TEST SUCCEEDED **` の文言で判定する
- Xcode project は `PBXFileSystemSynchronizedRootGroup` を採用しているため、**新規 `.swift` はディレクトリに置くだけで認識される**。`project.pbxproj` の編集は不要
- `Localizable.xcstrings` を Python の `json.dump` で書き換えない（Xcode の `" : "` 整形が壊れ diff が爆発する）。手編集で `" : "` の空白を維持する
- commit メッセージは日本語。フッタに以下を付ける

```text
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
```

- テスト実行コマンドのひな形（`<TestClass>/<testMethod>` は各ステップで指定）

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/<TestClass>/<testMethod> 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

## File Structure

| ファイル | 役割 |
| --- | --- |
| `app/OtetsudaiCoin/Domain/Services/FeedbackSettingsService.swift`（新規） | 効果音・触覚の ON/OFF を `UserDefaults` から毎回読む薄いラッパー |
| `app/OtetsudaiCoin/Utils/HapticFeedbackProvider.swift`（新規） | 触覚発火の seam（protocol + 実機実装）。ON/OFF 判定は持たない |
| `app/OtetsudaiCoin/Presentation/ViewModels/FeedbackSettingsViewModel.swift`（新規） | 設定画面の 2 トグルを仲介する `@Observable` ViewModel |
| `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`（変更） | 2 つの依存を注入し、演出発火を helper に集約。選択系に触覚を追加 |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`（変更） | 一括モードのタップを ViewModel 経由に変更 |
| `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift`（変更） | 「サウンドと触覚」Section を追加 |
| `app/OtetsudaiCoin/Utils/HapticFeedback.swift`（変更） | 重複する `HapticPreferences` と `*IfEnabled` 拡張を削除 |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings`（変更） | 新規 UI 文言 3 件の英訳 |
| `app/OtetsudaiCoinTests/Helpers/TestMocks.swift`（変更） | `MockHapticFeedbackProvider` と `FakeFeedbackSettingsService` を追加 |

---

### Task 1: 設定の永続化サービス

**Files:**

- Create: `app/OtetsudaiCoin/Domain/Services/FeedbackSettingsService.swift`
- Test: `app/OtetsudaiCoinTests/Domain/Services/FeedbackSettingsServiceTests.swift`

**Interfaces:**

- Consumes: なし（最初のタスク）
- Produces: `FeedbackSettingsServiceProtocol`（`var isSoundEnabled: Bool { get set }` / `var isHapticEnabled: Bool { get set }`、`AnyObject` 制約）と `final class FeedbackSettingsService`（`init(userDefaults: UserDefaults = .standard)`）

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Domain/Services/FeedbackSettingsServiceTests.swift` を新規作成する。

```swift
import XCTest
@testable import OtetsudaiCoin

final class FeedbackSettingsServiceTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // グローバルな UserDefaults.standard を汚さないよう suite を分離する
        suiteName = "FeedbackSettingsServiceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_defaults_areBothEnabled() {
        let service = FeedbackSettingsService(userDefaults: userDefaults)

        XCTAssertTrue(service.isSoundEnabled, "未保存時のサウンド既定値は true であるべき")
        XCTAssertTrue(service.isHapticEnabled, "未保存時のハプティクス既定値は true であるべき")
    }

    func test_setValues_arePersistedToUserDefaults() {
        let service = FeedbackSettingsService(userDefaults: userDefaults)

        service.isSoundEnabled = false
        service.isHapticEnabled = false

        XCTAssertFalse(userDefaults.bool(forKey: "sound_enabled"))
        XCTAssertFalse(userDefaults.bool(forKey: "haptic_enabled"))
    }

    func test_newInstance_readsStoredValues() {
        let first = FeedbackSettingsService(userDefaults: userDefaults)
        first.isHapticEnabled = false

        let second = FeedbackSettingsService(userDefaults: userDefaults)

        XCTAssertFalse(second.isHapticEnabled)
        XCTAssertTrue(second.isSoundEnabled, "触っていない側は既定値のままであるべき")
    }

    /// 回帰ガード: 値を init で読んで stored property に持つ方式へ退行すると落ちる。
    /// アプリ上では「設定画面で OFF にしても記録画面は再起動まで ON のまま」という形で
    /// 現れるが、単一インスタンスしか触らない他のテストは全て green のまま素通りする。
    func test_liveInstance_seesWriteFromAnotherInstance() {
        let recordSide = FeedbackSettingsService(userDefaults: userDefaults)
        let settingsSide = FeedbackSettingsService(userDefaults: userDefaults)
        XCTAssertTrue(recordSide.isHapticEnabled)

        settingsSide.isHapticEnabled = false

        XCTAssertFalse(
            recordSide.isHapticEnabled,
            "別インスタンスの書き込みが即座に読めていない (値をキャッシュしている)"
        )
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/FeedbackSettingsServiceTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests|error:" | tail -5
```

期待: `** BUILD FAILED **` または `error: cannot find 'FeedbackSettingsService' in scope`（型が未定義のためコンパイルが通らない）。

- [ ] **Step 3: 実装を書く**

`app/OtetsudaiCoin/Domain/Services/FeedbackSettingsService.swift` を新規作成する。

```swift
import Foundation

/// 効果音とハプティクスの ON/OFF 設定 (#150)。
protocol FeedbackSettingsServiceProtocol: AnyObject {
    var isSoundEnabled: Bool { get set }
    var isHapticEnabled: Bool { get set }
}

/// `ReminderNotificationService` と同じ「protocol + UserDefaults 注入」の流儀に従うが、
/// 値を stored property にキャッシュせず computed property で毎回 UserDefaults を読む。
///
/// SettingsView は service を自前生成する作りのため (SettingsView.swift:34-37)、
/// 記録画面と設定画面でインスタンスが並存する。init で読んだ値を保持する方式だと
/// 設定画面で OFF にしても記録画面は起動時の true を読み続け、
/// アプリを再起動するまで OFF が効かない。UserDefaults を single source of truth に
/// することでこの不整合を構造的に排除する。
final class FeedbackSettingsService: FeedbackSettingsServiceProtocol {
    private enum UserDefaultsKey {
        static let sound = "sound_enabled"
        static let haptic = "haptic_enabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 未保存なら true（初回起動時は両方 ON = 従来の効果音挙動を維持）
    var isSoundEnabled: Bool {
        get { userDefaults.object(forKey: UserDefaultsKey.sound) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: UserDefaultsKey.sound) }
    }

    var isHapticEnabled: Bool {
        get { userDefaults.object(forKey: UserDefaultsKey.haptic) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: UserDefaultsKey.haptic) }
    }
}
```

- [ ] **Step 4: テストを実行して成功を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/FeedbackSettingsServiceTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 5: commit**

```bash
git add app/OtetsudaiCoin/Domain/Services/FeedbackSettingsService.swift \
        app/OtetsudaiCoinTests/Domain/Services/FeedbackSettingsServiceTests.swift
git commit -m "$(cat <<'EOF'
feat(#150): 効果音/ハプティクスの ON/OFF 設定サービスを追加

値は stored property にキャッシュせず computed property で毎回 UserDefaults を
読む。SettingsView が service を自前生成する作りのためインスタンスが並存し、
スナップショット方式だと OFF が再起動まで効かないため。インスタンス跨ぎの
回帰ガードテストを同時に置く。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 2: 触覚発火の seam とテストダブル

**Files:**

- Create: `app/OtetsudaiCoin/Utils/HapticFeedbackProvider.swift`
- Create: `app/OtetsudaiCoinTests/Utils/HapticFeedbackProviderTests.swift`
- Modify: `app/OtetsudaiCoinTests/Helpers/TestMocks.swift`（末尾に追記）

**Interfaces:**

- Consumes: Task 1 の `FeedbackSettingsServiceProtocol`（`FakeFeedbackSettingsService` が準拠する）
- Produces:
  - `protocol HapticFeedbackProviding`：`func helpRecorded()` / `func taskSelection()` / `func childSelection()` / `func errorOccurred()`（いずれも戻り値なし・引数なし）
  - `struct SystemHapticFeedbackProvider: HapticFeedbackProviding`（引数なし `init()`）
  - `final class MockHapticFeedbackProvider: HapticFeedbackProviding`：`helpRecordedCallCount` / `taskSelectionCallCount` / `childSelectionCallCount` / `errorOccurredCallCount`（いずれも `private(set) var ... = 0`）
  - `final class FakeFeedbackSettingsService: FeedbackSettingsServiceProtocol`：`init(isSoundEnabled: Bool = true, isHapticEnabled: Bool = true)`

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Utils/HapticFeedbackProviderTests.swift` を新規作成する。

```swift
import XCTest
@testable import OtetsudaiCoin

final class HapticFeedbackProviderTests: XCTestCase {

    /// 実機実装は UIKit のジェネレータを叩くだけで観測可能な戻り値を持たないため、
    /// 「protocol の 4 経路が呼べてクラッシュしない」ことだけを担保する smoke test。
    /// 呼ばれたかどうかの検証は MockHapticFeedbackProvider を使う側 (RecordViewModel) で行う。
    @MainActor
    func test_systemProvider_invokesAllChannelsWithoutCrashing() {
        let provider = SystemHapticFeedbackProvider()

        provider.helpRecorded()
        provider.taskSelection()
        provider.childSelection()
        provider.errorOccurred()
    }

    @MainActor
    func test_mockProvider_countsEachChannelIndependently() {
        let mock = MockHapticFeedbackProvider()

        mock.helpRecorded()
        mock.helpRecorded()
        mock.taskSelection()

        XCTAssertEqual(mock.helpRecordedCallCount, 2)
        XCTAssertEqual(mock.taskSelectionCallCount, 1)
        XCTAssertEqual(mock.childSelectionCallCount, 0)
        XCTAssertEqual(mock.errorOccurredCallCount, 0)
    }

    func test_fakeSettings_defaultsToBothEnabled() {
        let fake = FakeFeedbackSettingsService()

        XCTAssertTrue(fake.isSoundEnabled)
        XCTAssertTrue(fake.isHapticEnabled)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/HapticFeedbackProviderTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests|error:" | tail -5
```

期待: `** BUILD FAILED **`（`SystemHapticFeedbackProvider` / `MockHapticFeedbackProvider` / `FakeFeedbackSettingsService` がいずれも未定義）。

- [ ] **Step 3: protocol と実機実装を書く**

`app/OtetsudaiCoin/Utils/HapticFeedbackProvider.swift` を新規作成する。

```swift
import Foundation

/// 触覚フィードバックの発火口 (#150)。
///
/// `HapticFeedback` は static メソッドの集まりでテスト時に差し替えられないため、
/// 呼び出し側から見える seam としてこの protocol を挟む。
/// ON/OFF の判定はここでは行わない (呼び出し側が FeedbackSettingsService を見て決める)。
protocol HapticFeedbackProviding {
    func helpRecorded()
    func taskSelection()
    func childSelection()
    func errorOccurred()
}

/// 実機向けの実装。既存の `HapticFeedback` へ委譲するだけの薄いアダプタ。
struct SystemHapticFeedbackProvider: HapticFeedbackProviding {
    func helpRecorded() { HapticFeedback.helpRecorded() }
    func taskSelection() { HapticFeedback.taskSelection() }
    func childSelection() { HapticFeedback.childSelection() }
    func errorOccurred() { HapticFeedback.errorOccurred() }
}
```

- [ ] **Step 4: テストダブルを追加する**

`app/OtetsudaiCoinTests/Helpers/TestMocks.swift` の**末尾**に追記する。

```swift
// MARK: - #150 Feedback Mocks

/// 触覚が「どの経路で何回」呼ばれたかを記録する spy。
final class MockHapticFeedbackProvider: HapticFeedbackProviding {
    private(set) var helpRecordedCallCount = 0
    private(set) var taskSelectionCallCount = 0
    private(set) var childSelectionCallCount = 0
    private(set) var errorOccurredCallCount = 0

    func helpRecorded() { helpRecordedCallCount += 1 }
    func taskSelection() { taskSelectionCallCount += 1 }
    func childSelection() { childSelectionCallCount += 1 }
    func errorOccurred() { errorOccurredCallCount += 1 }
}

/// UserDefaults を経由せずに ON/OFF を直接指定できる設定のフェイク。
final class FakeFeedbackSettingsService: FeedbackSettingsServiceProtocol {
    var isSoundEnabled: Bool
    var isHapticEnabled: Bool

    init(isSoundEnabled: Bool = true, isHapticEnabled: Bool = true) {
        self.isSoundEnabled = isSoundEnabled
        self.isHapticEnabled = isHapticEnabled
    }
}
```

- [ ] **Step 5: テストを実行して成功を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/HapticFeedbackProviderTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Utils/HapticFeedbackProvider.swift \
        app/OtetsudaiCoinTests/Utils/HapticFeedbackProviderTests.swift \
        app/OtetsudaiCoinTests/Helpers/TestMocks.swift
git commit -m "$(cat <<'EOF'
feat(#150): 触覚発火の protocol seam とテストダブルを追加

static な HapticFeedback は差し替え不能なため HapticFeedbackProviding を挟む。
ON/OFF 判定は持たせず、呼び出し側が設定を見て決める責務分割にする。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 3: 記録完了・失敗時の演出を RecordViewModel へ配線

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`（プロパティ :38-40 付近、`init` :45-58、`recordBulkHelp` の効果音ブロック :226-234 と失敗分岐 :254-256、`recordHelp` の効果音ブロック :289-296 と catch :307-309）
- Test: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`（`setUp` :11-25 を変更し、末尾へテスト追加）

**Interfaces:**

- Consumes: Task 1 の `FeedbackSettingsServiceProtocol` / `FeedbackSettingsService`、Task 2 の `HapticFeedbackProviding` / `SystemHapticFeedbackProvider` / `MockHapticFeedbackProvider` / `FakeFeedbackSettingsService`
- Produces: `RecordViewModel.init` に `hapticFeedback: HapticFeedbackProviding? = nil` と `feedbackSettings: FeedbackSettingsServiceProtocol? = nil` の 2 引数が増える（既定値ありのため既存の生成箇所は無変更）

- [ ] **Step 1: setUp を新しい依存に対応させる**

`app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` の先頭（:5-25）を次のように書き換える。

```swift
final class RecordViewModelTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!
    private var mockHaptic: MockHapticFeedbackProvider!
    private var fakeFeedbackSettings: FakeFeedbackSettingsService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockSoundService = MockSoundService()
        mockHaptic = MockHapticFeedbackProvider()
        fakeFeedbackSettings = FakeFeedbackSettingsService()

        viewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService,
            hapticFeedback: mockHaptic,
            feedbackSettings: fakeFeedbackSettings
        )
    }
```

`tearDown`（:27-34）にも 2 行足す。

```swift
    override func tearDown() {
        viewModel = nil
        fakeFeedbackSettings = nil
        mockHaptic = nil
        mockSoundService = nil
        mockHelpRecordRepository = nil
        mockHelpTaskRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }
```

- [ ] **Step 2: 失敗するテストを書く**

同ファイルの末尾（最後の `}` の直前）に追記する。`waitUntil` は同クラス内の既存ヘルパー（:297）を使う。選択メソッド経由だと選択触覚が混ざるため、fixture はプロパティへ直接代入する。

```swift
    // MARK: - #150 Feedback Tests

    @MainActor
    private func makeSingleRecordFixture() -> (Child, HelpTask) {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true, coinRate: 10)
        viewModel.availableChildren = [child]
        viewModel.availableTasks = [task]
        // selectChild / selectTask を通すと選択触覚が加算されるため直接代入する
        viewModel.selectedChild = child
        viewModel.selectedTask = task
        return (child, task)
    }

    @MainActor
    func test_recordHelp_playsSoundAndHaptic() async {
        _ = makeSingleRecordFixture()

        viewModel.recordHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertTrue(mockSoundService.playCoinEarnSoundCalled)
        XCTAssertTrue(mockSoundService.playTaskCompleteSoundCalled)
        XCTAssertEqual(mockHaptic.helpRecordedCallCount, 1)
    }

    @MainActor
    func test_recordHelp_hapticDisabled_playsSoundOnly() async {
        fakeFeedbackSettings.isHapticEnabled = false
        _ = makeSingleRecordFixture()

        viewModel.recordHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        // fixture が壊れて guard で早期 return すると isLoading が false のままとなり
        // 「何も起きていないのに green」になる。記録が成立したことを先に固定する。
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertTrue(mockSoundService.playCoinEarnSoundCalled, "サウンドは ON のままなので鳴るべき")
        XCTAssertEqual(mockHaptic.helpRecordedCallCount, 0, "ハプティクス OFF なのに触覚が鳴っている")
    }

    @MainActor
    func test_recordHelp_soundDisabled_playsHapticOnly() async {
        fakeFeedbackSettings.isSoundEnabled = false
        _ = makeSingleRecordFixture()

        viewModel.recordHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        // 「鳴らないこと」だけを見るテストは、記録自体が起きていなくても green になる。
        // 記録の成立を先に固定してから不在を assert する。
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertFalse(mockSoundService.playCoinEarnSoundCalled, "サウンド OFF なのに効果音が鳴っている")
        XCTAssertFalse(mockSoundService.playTaskCompleteSoundCalled)
        XCTAssertEqual(mockHaptic.helpRecordedCallCount, 1, "触覚は ON のままなので鳴るべき")
    }

    @MainActor
    func test_recordBulkHelp_partialFailure_playsSuccessHapticOnly() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t2.id]

        viewModel.recordBulkHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        XCTAssertEqual(mockHaptic.helpRecordedCallCount, 1, "成功分があるので成功触覚は鳴るべき")
        XCTAssertEqual(mockHaptic.errorOccurredCallCount, 0, "部分失敗でエラー触覚まで鳴らすと二重振動になる")
    }

    @MainActor
    func test_recordBulkHelp_allFailed_playsErrorHaptic() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t1.id]

        viewModel.recordBulkHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        XCTAssertEqual(mockHaptic.errorOccurredCallCount, 1)
        XCTAssertEqual(mockHaptic.helpRecordedCallCount, 0)
        XCTAssertFalse(mockSoundService.playCoinEarnSoundCalled, "1 件も成功していないので成功音は鳴らない")
    }

    @MainActor
    func test_recordBulkHelp_allFailed_hapticDisabled_playsNothing() async {
        fakeFeedbackSettings.isHapticEnabled = false
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t1.id]

        viewModel.recordBulkHelp()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }

        XCTAssertEqual(mockHaptic.errorOccurredCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage, "触覚 OFF でもエラーメッセージ表示は従来どおり")
    }
```

- [ ] **Step 3: テストを実行して失敗を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests|error:" | tail -5
```

期待: `** BUILD FAILED **`（`RecordViewModel.init` に `hapticFeedback` 引数が存在しない）。

- [ ] **Step 4: RecordViewModel に依存を注入する**

`app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` のプロパティ宣言（:38-40 付近）へ 2 行足す。

```swift
    private let soundService: SoundServiceProtocol
    private let hapticFeedback: HapticFeedbackProviding
    private let feedbackSettings: FeedbackSettingsServiceProtocol
```

`init`（:45-58）を次に置き換える。

```swift
    init(
        childRepository: ChildRepository,
        helpTaskRepository: HelpTaskRepository,
        helpRecordRepository: HelpRecordRepository,
        soundService: SoundServiceProtocol? = nil,
        hapticFeedback: HapticFeedbackProviding? = nil,
        feedbackSettings: FeedbackSettingsServiceProtocol? = nil
    ) {
        self.childRepository = childRepository
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
        self.soundService = soundService ?? SoundService()
        self.hapticFeedback = hapticFeedback ?? SystemHapticFeedbackProvider()
        self.feedbackSettings = feedbackSettings ?? FeedbackSettingsService()
        super.init()
    }
```

- [ ] **Step 5: 演出の helper を追加する**

`init` の直後に private helper を 2 つ追加する。

```swift
    /// 記録が 1 件以上成功したときの演出 (#150)。
    /// 効果音とハプティクスはそれぞれ設定で個別に OFF にできる。
    /// recordHelp / recordBulkHelp の両方から呼ぶため、従来 2 箇所に重複していた
    /// 効果音ブロックもここへ集約する。
    private func playSuccessFeedback() {
        if feedbackSettings.isSoundEnabled {
            do {
                try soundService.playCoinEarnSound()
                try soundService.playTaskCompleteSound()
            } catch {
                // 効果音の再生に失敗した場合はエラー音にフォールバックする (従来挙動)
                try? soundService.playErrorSound()
            }
        }
        if feedbackSettings.isHapticEnabled {
            hapticFeedback.helpRecorded()
        }
    }

    /// 記録が 1 件も成功しなかったときの演出 (#150)。
    /// 効果音は従来どおり鳴らさず、触覚だけを足す。
    private func playErrorFeedback() {
        if feedbackSettings.isHapticEnabled {
            hapticFeedback.errorOccurred()
        }
    }
```

- [ ] **Step 6: recordBulkHelp を helper 経由にする**

`recordBulkHelp` 内の効果音ブロック（:226-234）を次に置き換える。

```swift
            // 演出 (成功 1 件以上で発火。部分失敗でも成功側のみ鳴らす)
            if !successIds.isEmpty {
                playSuccessFeedback()
            }
```

同メソッドの全件失敗分岐（:254-256）を次に置き換える。

```swift
            if successIds.isEmpty && !failureIds.isEmpty {
                playErrorFeedback()
                setError(String(localized: "記録に失敗しました"))
            }
```

- [ ] **Step 7: recordHelp を helper 経由にする**

`recordHelp` 内の効果音ブロック（:289-296）を次に置き換える。

```swift
                // 演出 (効果音 + 触覚)
                playSuccessFeedback()
```

同メソッドの `catch`（:307-309）を次に置き換える。

```swift
            } catch {
                playErrorFeedback()
                setUserFriendlyError(error)
            }
```

- [ ] **Step 8: テストを実行して成功を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 9: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(#150): 記録完了/失敗時の触覚を配線し演出を helper に集約

recordHelp と recordBulkHelp に重複していた効果音ブロックを
playSuccessFeedback / playErrorFeedback へ統合し、設定に応じて
効果音と触覚をそれぞれ抑止する。部分失敗は成功触覚のみ鳴らし
二重振動を避ける (既存の効果音挙動と同じ)。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 4: 選択時の触覚と一括モードのロジック移設

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift`（`selectChild` :159-170、`selectTask` :176-180）
- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`（:215-225 の `onTap` closure）
- Test: `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift`（末尾へ追加）

**Interfaces:**

- Consumes: Task 3 で注入済みの `hapticFeedback` / `feedbackSettings`
- Produces: `RecordViewModel.toggleTaskSelection(_ task: HelpTask)`（戻り値なし。`selectedTaskIds` に未収録なら追加、収録済みなら削除する）

- [ ] **Step 1: 失敗するテストを書く**

`RecordViewModelTests.swift` の末尾に追記する。

```swift
    // MARK: - #150 Selection Haptics

    @MainActor
    func test_selectTask_firesTaskSelectionHaptic() {
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)

        viewModel.selectTask(task)

        XCTAssertEqual(viewModel.selectedTask?.id, task.id)
        XCTAssertEqual(mockHaptic.taskSelectionCallCount, 1)
    }

    @MainActor
    func test_selectChild_firesChildSelectionHaptic() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")

        viewModel.selectChild(child)

        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(mockHaptic.childSelectionCallCount, 1)
    }

    @MainActor
    func test_toggleTaskSelection_addsThenRemoves() {
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)
        viewModel.isBulkMode = true

        viewModel.toggleTaskSelection(task)
        XCTAssertEqual(viewModel.selectedTaskIds, [task.id])

        viewModel.toggleTaskSelection(task)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
    }

    @MainActor
    func test_toggleTaskSelection_firesHapticOnBothDirections() {
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)
        viewModel.isBulkMode = true

        viewModel.toggleTaskSelection(task)
        viewModel.toggleTaskSelection(task)

        XCTAssertEqual(mockHaptic.taskSelectionCallCount, 2, "選択・解除のどちらでも手応えを返すべき")
    }

    @MainActor
    func test_selection_hapticDisabled_firesNothing() {
        fakeFeedbackSettings.isHapticEnabled = false
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)

        viewModel.selectChild(child)
        viewModel.selectTask(task)
        viewModel.toggleTaskSelection(task)

        XCTAssertEqual(mockHaptic.childSelectionCallCount, 0)
        XCTAssertEqual(mockHaptic.taskSelectionCallCount, 0)
        XCTAssertEqual(viewModel.selectedTaskIds, [task.id], "触覚 OFF でも選択自体は機能するべき")
    }
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests|error:" | tail -5
```

期待: `** BUILD FAILED **`（`toggleTaskSelection` が未定義）。

- [ ] **Step 3: 選択系メソッドを実装する**

`RecordViewModel.swift` の `selectChild`（:159-170）の末尾に触覚を足す。

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
        loadRecordedDaysForDisplayedMonth()
        if feedbackSettings.isHapticEnabled {
            hapticFeedback.childSelection()
        }
    }
```

`selectTask`（:176-180）を置き換え、直後に `toggleTaskSelection` を追加する。

```swift
    func selectTask(_ task: HelpTask) {
        selectedTask = task
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
        if feedbackSettings.isHapticEnabled {
            hapticFeedback.taskSelection()
        }
    }

    /// 一括モードでのタスク選択トグル (#150)。
    ///
    /// 従来は RecordView の onTap closure が selectedTaskIds を直接書き換えていたため、
    /// テストが書けず触覚も挟めなかった。判定を ViewModel 側へ寄せて両方を解決する。
    func toggleTaskSelection(_ task: HelpTask) {
        if selectedTaskIds.contains(task.id) {
            selectedTaskIds.remove(task.id)
        } else {
            selectedTaskIds.insert(task.id)
        }
        if feedbackSettings.isHapticEnabled {
            hapticFeedback.taskSelection()
        }
    }
```

- [ ] **Step 4: RecordView を ViewModel 経由に変える**

`app/OtetsudaiCoin/Presentation/Views/RecordView.swift` の `onTap`（:215-225）を置き換える。

```swift
                            onTap: {
                                if viewModel.isBulkMode {
                                    viewModel.toggleTaskSelection(task)
                                } else {
                                    viewModel.selectTask(task)
                                }
                            }
```

- [ ] **Step 5: テストを実行して成功を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 6: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift \
        app/OtetsudaiCoin/Presentation/Views/RecordView.swift \
        app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(#150): タスク/子ども選択に触覚を追加し一括選択を ViewModel へ移設

一括モードのタップは View が selectedTaskIds を直接書き換えており、
テスト不能かつ触覚を挟めなかったため toggleTaskSelection(_:) を新設して
RecordView から呼ぶ形に寄せる。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 5: 設定画面のトグルと i18n

**Files:**

- Create: `app/OtetsudaiCoin/Presentation/ViewModels/FeedbackSettingsViewModel.swift`
- Create: `app/OtetsudaiCoinTests/Presentation/ViewModels/FeedbackSettingsViewModelTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift`（`init` の :34-38 付近と、`Section("通知")` の直後 :130 付近）
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`

**Interfaces:**

- Consumes: Task 1 の `FeedbackSettingsServiceProtocol` / `FeedbackSettingsService`、Task 2 の `FakeFeedbackSettingsService`
- Produces: `FeedbackSettingsViewModel`（`init(service: FeedbackSettingsServiceProtocol)`、`var isSoundEnabled: Bool`、`var isHapticEnabled: Bool`）

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Presentation/ViewModels/FeedbackSettingsViewModelTests.swift` を新規作成する。

```swift
import XCTest
@testable import OtetsudaiCoin

final class FeedbackSettingsViewModelTests: XCTestCase {

    @MainActor
    func test_initialState_reflectsService() {
        let fake = FakeFeedbackSettingsService(isSoundEnabled: false, isHapticEnabled: true)

        let viewModel = FeedbackSettingsViewModel(service: fake)

        XCTAssertFalse(viewModel.isSoundEnabled)
        XCTAssertTrue(viewModel.isHapticEnabled)
    }

    @MainActor
    func test_togglingSound_writesThroughToService() {
        let fake = FakeFeedbackSettingsService()
        let viewModel = FeedbackSettingsViewModel(service: fake)

        viewModel.isSoundEnabled = false

        XCTAssertFalse(fake.isSoundEnabled, "トグル操作が設定サービスへ反映されていない")
        XCTAssertTrue(fake.isHapticEnabled, "触っていない側は変わらないべき")
    }

    @MainActor
    func test_togglingHaptic_writesThroughToService() {
        let fake = FakeFeedbackSettingsService()
        let viewModel = FeedbackSettingsViewModel(service: fake)

        viewModel.isHapticEnabled = false

        XCTAssertFalse(fake.isHapticEnabled)
        XCTAssertTrue(fake.isSoundEnabled)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/FeedbackSettingsViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests|error:" | tail -5
```

期待: `** BUILD FAILED **`（`FeedbackSettingsViewModel` が未定義）。

- [ ] **Step 3: ViewModel を実装する**

`app/OtetsudaiCoin/Presentation/ViewModels/FeedbackSettingsViewModel.swift` を新規作成する。`NotificationSettingsViewModel` と同じく `BaseViewModel` は継承しない。

```swift
import Foundation

/// 設定画面の「サウンドと触覚」トグルを仲介する ViewModel (#150)。
///
/// SwiftUI の Toggle へ束縛するため値を stored property に持つが、
/// 変更は didSet で即座に service (= UserDefaults) へ書き戻す。
/// 記録画面側は service を毎回読むため、ここでの変更は次の発火から反映される。
@MainActor
@Observable
class FeedbackSettingsViewModel {

    var isSoundEnabled: Bool {
        didSet { service.isSoundEnabled = isSoundEnabled }
    }

    var isHapticEnabled: Bool {
        didSet { service.isHapticEnabled = isHapticEnabled }
    }

    private let service: FeedbackSettingsServiceProtocol

    init(service: FeedbackSettingsServiceProtocol) {
        self.service = service
        self.isSoundEnabled = service.isSoundEnabled
        self.isHapticEnabled = service.isHapticEnabled
    }
}
```

- [ ] **Step 4: テストを実行して成功を確認する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/FeedbackSettingsViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 5: SettingsView に Section を追加する**

`app/OtetsudaiCoin/Presentation/Views/SettingsView.swift` の `@State` プロパティ群（`notificationSettingsViewModel` の宣言箇所の隣）へ 1 行足す。

```swift
    @State private var feedbackSettingsViewModel: FeedbackSettingsViewModel
```

`init` 内、`self._notificationSettingsViewModel = ...`（:38）の直後に初期化を足す。

```swift
        self._feedbackSettingsViewModel = State(wrappedValue: FeedbackSettingsViewModel(
            service: FeedbackSettingsService(userDefaults: .standard)
        ))
```

`Section("通知") { ... }` の閉じ括弧の直後（:130 付近、`#if DEBUG` の直前）へ Section を挿入する。

```swift
                Section("サウンドと触覚") {
                    Toggle("効果音", isOn: $feedbackSettingsViewModel.isSoundEnabled)
                    Toggle("振動（ハプティクス）", isOn: $feedbackSettingsViewModel.isHapticEnabled)
                }
```

**コンパイルが通らない場合のフォールバック**: `@State` + `@Observable` の projected binding（`$viewModel.property`）は iOS 17+ で有効だが、このリポジトリには前例がない（既存の `NotificationSettingsView` は `Binding(get:set:)` を明示する形、:10-16）。もし `$feedbackSettingsViewModel.isSoundEnabled` が解決できなければ、既存の流儀へ切り替える。この差し替えは plan からの逸脱ではないので PR への記載は不要。

```swift
                Section("サウンドと触覚") {
                    Toggle("効果音", isOn: Binding(
                        get: { feedbackSettingsViewModel.isSoundEnabled },
                        set: { feedbackSettingsViewModel.isSoundEnabled = $0 }
                    ))
                    Toggle("振動（ハプティクス）", isOn: Binding(
                        get: { feedbackSettingsViewModel.isHapticEnabled },
                        set: { feedbackSettingsViewModel.isHapticEnabled = $0 }
                    ))
                }
```

- [ ] **Step 6: 英訳を追加する**

`app/OtetsudaiCoin/Resources/Localizable.xcstrings` の `"strings"` オブジェクト内に 3 エントリを追加する。既存エントリと同じ `" : "` の空白を保った手編集で行う（Python の `json.dump` は使わない）。

```json
    "サウンドと触覚" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sound & Haptics"
          }
        }
      }
    },
    "効果音" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sound Effects"
          }
        }
      }
    },
    "振動（ハプティクス）" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Haptics"
          }
        }
      }
    },
```

JSON として妥当であればキーの並び順は問わない（Xcode で開くと自動で並び替わる）。編集後に妥当性を確認する。

```bash
python3 -c "import json;json.load(open('app/OtetsudaiCoin/Resources/Localizable.xcstrings'));print('JSON OK')"
```

期待: `JSON OK`

- [ ] **Step 7: ローカライズテストとビューモデルテストを実行する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests \
  -only-testing:OtetsudaiCoinTests/FeedbackSettingsViewModelTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 8: commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/FeedbackSettingsViewModel.swift \
        app/OtetsudaiCoinTests/Presentation/ViewModels/FeedbackSettingsViewModelTests.swift \
        app/OtetsudaiCoin/Presentation/Views/SettingsView.swift \
        app/OtetsudaiCoin/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
feat(#150): 設定画面に「サウンドと触覚」トグルを追加

通知 Section の下に効果音・振動の 2 トグルを置き、FeedbackSettingsViewModel
経由で UserDefaults へ書き戻す。新規 UI 文言 3 件は ja/en を追加。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 6: 重複する旧設定機構の削除

**Files:**

- Modify: `app/OtetsudaiCoin/Utils/HapticFeedback.swift`（:277-360 を削除）

**Interfaces:**

- Consumes: なし
- Produces: なし（削除のみ。`HapticFeedback` の static メソッド群と `HapticButtonStyle`、View 拡張は残す）

- [ ] **Step 1: 削除対象が本当に未参照であることを確認する**

app・テスト・UI テストの全ターゲットを見る（app だけ見て CI が落ちた既往があるため）。

```bash
grep -rn "HapticPreferences\|IfEnabled" \
  app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests --include="*.swift"
```

期待: `app/OtetsudaiCoin/Utils/HapticFeedback.swift` 内の定義行のみがヒットする。他ファイルが 1 件でも出たら削除を中止し、その参照の扱いを報告する。

- [ ] **Step 2: 削除する**

`app/OtetsudaiCoin/Utils/HapticFeedback.swift` の 277 行目（`// MARK: - Haptic Preferences`）からファイル末尾（360 行目）までを削除する。削除対象は `HapticPreferences` クラス全体と、`// MARK: - Safe Haptic Execution` の `extension HapticFeedback`（`executeIfEnabled` と `lightIfEnabled` / `mediumIfEnabled` / `heavyIfEnabled` / `successIfEnabled` / `errorIfEnabled` / `warningIfEnabled` / `selectionIfEnabled` の計 8 メソッド）。

削除後、ファイルは `// MARK: - Button Style with Haptic Feedback` の `extension ButtonStyle where Self == HapticButtonStyle { ... }` の閉じ括弧で終わる。

- [ ] **Step 3: unit テスト全体を実行する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 4: commit**

```bash
git add app/OtetsudaiCoin/Utils/HapticFeedback.swift
git commit -m "$(cat <<'EOF'
refactor(#150): 重複する HapticPreferences と *IfEnabled 拡張を削除

設定の保持は FeedbackSettingsService へ一本化したため、ObservableObject
シングルトン + グローバル UserDefaults 直読みの旧機構は不要。全ターゲットで
参照ゼロを確認済み。HapticButtonStyle と View 拡張は今回のスコープ外として残す。

Refs #150

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

---

### Task 7: 検証と PR 作成

**Files:**

- 変更なし（検証と PR 作成のみ）

**Interfaces:**

- Consumes: Task 1〜6 の全成果
- Produces: PR

- [ ] **Step 1: unit テスト全体を実行する**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests 2>&1 \
  | grep -E "\*\* TEST|Failing tests" | tail -5
```

期待: `** TEST SUCCEEDED **`

- [ ] **Step 2: 設定画面のスクリーンショットで Section を目視する**

シミュレータでは触覚を体感できないため、視覚的に確認できるのは設定画面の Section 追加のみ。既存の撮影スクリプトを流用する。

```bash
./scripts/capture-asc-screenshots.sh
```

`docs/screenshots/asc/v1.1.x/ja/03-settings.png` と `docs/screenshots/asc/v1.1.x/en/03-settings.png` を Read で開き、「サウンドと触覚 / Sound & Haptics」Section とトグル 2 つが「通知」の下に表示されていることを確認する。

- [ ] **Step 3: 撮影結果を破棄する**

出力は ASC 提出用の committed artifact なので、目視後に必ず破棄して PR に含めない。

```bash
git checkout -- docs/screenshots/
git status --short
```

期待: `docs/screenshots/` 配下の差分が消えている。

- [ ] **Step 4: PR を作成する**

同一ブランチの既存 PR がないことを先に確認する。

```bash
git status --short --branch
gh pr list --head feature/issue-150-feedback-haptics
```

期待: HEAD が `feature/issue-150-feedback-haptics`、PR 一覧は空。

```bash
git push -u origin feature/issue-150-feedback-haptics
gh pr create --title "feat(#150): 記録演出にハプティクスを追加しサウンド/触覚の OFF 設定を新設" --body "$(cat <<'EOF'
## 概要

Closes #150（提案 1・3・4）

未使用のまま放置されていた `HapticFeedback` を記録・選択の各操作へ配線し、設定画面から効果音と触覚を個別に OFF にできるようにしました。効果音は既に配線済みだったため、これで「音 + コインアニメーション + 触覚」の三点が揃います。

## 変更内容

- `FeedbackSettingsService`: 効果音・触覚の ON/OFF を `UserDefaults` から毎回読む設定サービス
- `HapticFeedbackProviding`: 触覚発火の protocol seam（static な `HapticFeedback` を差し替え可能にする）
- `RecordViewModel`: 記録成功・失敗と選択 3 経路に演出を配線。重複していた効果音ブロックを helper へ集約
- `RecordView`: 一括モードのタップを `toggleTaskSelection(_:)` 経由に変更
- `SettingsView`: 「サウンドと触覚」Section を追加（ja/en）
- `HapticFeedback.swift`: 重複する `HapticPreferences` と `*IfEnabled` 拡張を削除

## 設計判断

**設定値をキャッシュしない**: `ReminderNotificationService` は `init` で読んだ値を stored property に持つ流儀ですが、`SettingsView` が service を自前生成するため記録画面とインスタンスが並存します。スナップショット方式だと設定画面で OFF にしても記録画面は起動時の値を読み続け、**再起動するまで OFF が効かない**バグになります。computed property で毎回 `UserDefaults` を読む形にし、インスタンス跨ぎの回帰ガードテストを置きました。

**コインアニメーション開始時の触覚は入れていません**: 記録完了の 0.1 秒後にアニメーションが出るため、両方に入れると二重振動になります。一括記録の部分失敗時も成功触覚のみを鳴らします（既存の効果音挙動と同じ）。

## テスト

- `FeedbackSettingsServiceTests`: 既定値 / 永続化 / インスタンス跨ぎの反映（回帰ガード）
- `RecordViewModelTests`: 成功・失敗・部分失敗の演出、サウンド/触覚それぞれの OFF、選択 3 経路
- `FeedbackSettingsViewModelTests`: トグルの書き戻し
- `HapticFeedbackProviderTests`: 実機実装の smoke とテストダブルの計数
- unit スイート全体で `** TEST SUCCEEDED **`

## 確認をお願いしたいこと

**触覚はシミュレータでは体感できません**。実機で以下をご確認ください。

- お手伝いを記録したときに振動が返ること（単発・一括の両方）
- タスク・子どもを選んだときに軽い手応えがあること
- 設定画面で「振動（ハプティクス）」を OFF にすると振動しなくなること
- 「効果音」を OFF にすると音が鳴らなくなること

## Plan からの逸脱

なし

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_012sB9aRViNmyTgi397HYtHt
EOF
)"
```

- [ ] **Step 5: 完了報告**

PR 番号と、実機確認をユーザーへ依頼する旨を報告する。

---

## Self-Review

**1. Spec coverage**

| spec の要求 | 対応タスク |
| --- | --- |
| `FeedbackSettingsService`（computed property・既定 true） | Task 1 |
| `HapticFeedbackProviding` + 実機実装 | Task 2 |
| 記録完了（単発・一括）の触覚 | Task 3 |
| 記録失敗（成功 0 件）の触覚 | Task 3 |
| 一括の部分失敗は成功触覚のみ | Task 3 Step 2 のテスト |
| 効果音ブロックの重複解消 | Task 3 Step 5-7 |
| タスク・子ども選択の触覚 | Task 4 |
| `toggleTaskSelection` 新設と RecordView 移設 | Task 4 |
| `FeedbackSettingsViewModel` | Task 5 |
| 設定画面の 2 トグル | Task 5 Step 5 |
| i18n（3 文言 ja/en） | Task 5 Step 6 |
| `HapticPreferences` と `*IfEnabled` の削除 | Task 6 |
| インスタンス跨ぎの回帰ガード | Task 1 Step 1 の 4 番目のテスト |
| 受け入れ条件「実機目視」 | Task 7 Step 4 の PR 本文で依頼 |

**2. Placeholder scan**: プレースホルダなし。全ステップに実コードまたは実コマンドを記載済み。

**3. Type consistency**

- `FeedbackSettingsServiceProtocol` のプロパティ名 `isSoundEnabled` / `isHapticEnabled` は Task 1・2・3・5 で一貫
- `HapticFeedbackProviding` のメソッド名 `helpRecorded()` / `taskSelection()` / `childSelection()` / `errorOccurred()` は Task 2・3・4 で一貫
- `MockHapticFeedbackProvider` の計数プロパティ名 `*CallCount` は Task 2 の定義と Task 3・4 の assert で一貫
- `RecordViewModel.init` の引数順（`soundService` → `hapticFeedback` → `feedbackSettings`）は Task 3 Step 1 のテストと Step 4 の実装で一致
