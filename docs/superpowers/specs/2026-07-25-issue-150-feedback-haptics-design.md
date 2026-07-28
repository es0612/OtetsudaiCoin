# 演出強化: ハプティクス配線とサウンド/触覚 OFF 設定 (#150)

- Issue: #150 子どもが喜ぶ演出の強化（未使用 HapticFeedback の活用 + 記録時のお祝い体験）
- 作成日: 2026-07-25
- ステータス: 設計承認済み

## 背景

対象ユーザーは親子（特に子ども）だが、記録体験が事務的である。一方でコードベースには 361 行の `Utils/HapticFeedback.swift` が実装済みかつ**全ターゲット参照ゼロ**で存在しており、配線するだけで体験が向上する余地が大きい。

効果音は `RecordViewModel` から既に再生されており（`playCoinEarnSound()` / `playTaskCompleteSound()`）、コイン獲得アニメーション `CoinAnimationView` も稼働している。ここに触覚を足すと「音 + アニメ + 触覚」の三点セットが揃う。

## スコープ

issue の提案 1〜5 のうち、**提案 1・3・4** を対象とする。

| 提案 | 内容 | 今回 |
| --- | --- | --- |
| 1 | 記録完了時の三点セット（音 + アニメ + 触覚） | 対象 |
| 2 | 節目のお祝い演出（紙吹雪等） | スコープ外 |
| 3 | タスク/子ども選択時の軽いハプティクス | 対象 |
| 4 | 設定に「サウンド / ハプティクス OFF」トグル | 対象 |
| 5 | 未使用分の `#143` デッドコード削除送り | 一部のみ（`HapticPreferences` と `*IfEnabled` 拡張だけ削除。`HapticButtonStyle` と View 拡張は温存） |

### 触覚を発火させるタイミング

| タイミング | 触覚 | 呼び出し元 |
| --- | --- | --- |
| 記録完了（単発） | `helpRecorded()` = success | `RecordViewModel.recordHelp()` |
| 記録完了（一括） | `helpRecorded()` = success | `RecordViewModel.recordBulkHelp()` |
| 一括の部分失敗（成功 1 件以上 + 失敗あり） | `helpRecorded()` のみ | `RecordViewModel.recordBulkHelp()` |
| 記録失敗（成功 0 件） | `errorOccurred()` = error | 同上の失敗経路 |
| タスク選択 | `taskSelection()` = selection | `RecordViewModel.selectTask()` / `toggleTaskSelection()` |
| 子ども選択 | `childSelection()` = medium | `RecordViewModel.selectChild()` |

一括記録で「一部成功・一部失敗」になった場合は `helpRecorded()` のみを鳴らし、`errorOccurred()` は鳴らさない。既存の効果音が `if !successIds.isEmpty` で成功音のみ鳴らす挙動（`RecordViewModel.swift:227`）と揃え、二重振動も避けるため。失敗分は既存の `warningMessage` で伝える。

コインアニメーション開始時の `coinAnimationStarted()` は**意図的に除外する**。記録完了の 0.1 秒後に `CoinAnimationView` が表示される（`RecordView.swift:99-103`）ため、両方に触覚を入れると二重振動になり体験が損なわれる。

## 現状分析

### 落とし穴 1: アプリ固有 API が設定を無視する

`HapticFeedback` には 2 系統の API が混在している。

- `helpRecorded()` / `taskSelection()` / `childSelection()` — アプリ固有だが**設定を無視**し、生の `success()` 等を直接呼ぶ
- `successIfEnabled()` / `selectionIfEnabled()` — 設定（`HapticPreferences`）を尊重するが汎用名のみ

issue の提案どおり `helpRecorded()` をそのまま配線すると、受け入れ条件「OFF 設定が機能する」を満たせない。

### 落とし穴 2: 既存 `HapticPreferences` がリポジトリの流儀から外れている

`HapticPreferences` は `ObservableObject` + `@Published` のシングルトンで、グローバル `UserDefaults` を直接読み書きする。リポジトリの現在の流儀は `@Observable` + `UserDefaults` 注入（`ReminderNotificationService` 参照）であり、テストがグローバル状態を汚す問題もある。`#154` の Swift 6 移行でも負債になる。

### 落とし穴 3: 効果音にも OFF 設定が存在しない

`SoundService` は `setMuted(_:)` / `setVolume(_:)` を持つが、設定画面にトグルがなく永続化もされていない。設定を新設するなら音と触覚をセットで扱うのが自然。

### 落とし穴 4: 一括モードのタップが ViewModel を経由していない

`RecordView.swift:216-221` は一括モード時に `viewModel.selectedTaskIds` を View から直接書き換えている。ViewModel 側に触覚を置くと**一括モードだけ鳴らない**不揃いが生じる。

## 設計

### 新規ファイル

| ファイル | 役割 |
| --- | --- |
| `Domain/Services/FeedbackSettingsService.swift` | `FeedbackSettingsServiceProtocol`（`isSoundEnabled` / `isHapticEnabled`）と実装。`UserDefaults` 注入 + `didSet` 永続化 |
| `Utils/HapticFeedbackProvider.swift` | `HapticFeedbackProviding` protocol と `SystemHapticFeedbackProvider`（既存 static `HapticFeedback` への薄いアダプタ） |
| `Presentation/ViewModels/FeedbackSettingsViewModel.swift` | `@MainActor @Observable`。設定画面の 2 トグルを仲介 |

`FeedbackSettingsService` は `ReminderNotificationService` の「protocol + `UserDefaults` 注入」の流儀を踏襲するが、**値を stored property にキャッシュせず computed property で毎回 `UserDefaults` から読む**点だけ意図的に変える。

```swift
protocol FeedbackSettingsServiceProtocol: AnyObject {
    var isSoundEnabled: Bool { get set }
    var isHapticEnabled: Bool { get set }
}

final class FeedbackSettingsService: FeedbackSettingsServiceProtocol {
    private enum UserDefaultsKey {
        static let sound = "sound_enabled"
        static let haptic = "haptic_enabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    // 未保存なら true（初回起動時は両方 ON = 現状の効果音挙動を維持）
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

### なぜ stored property + `didSet` にしないのか

`ReminderNotificationService` は `init` で値を読み stored property に持ち `didSet` で保存する形だが、この設計を `FeedbackSettingsService` にそのまま持ち込むと**インスタンスごとに起動時のスナップショットを抱える**ことになる。

`SettingsView` は `ReminderNotificationService` を自前で生成しており（`SettingsView.swift:34-37`）、同じ流儀で `FeedbackSettingsService` を作ると、設定画面のインスタンスと `RecordViewModel` が持つインスタンスが別物になる。stored property 方式ではトグルを OFF にしても記録画面側は起動時の `true` を読み続け、**アプリを再起動するまで OFF が効かない**。これは受け入れ条件「OFF にすると実際に鳴らない」への直撃バグである。

computed property にすれば `UserDefaults` が single source of truth になり、どのインスタンス経由でも常に最新値が読める。結果として「単一インスタンスを全画面へ配る」という配線制約自体が不要になる。

この差分は `ReminderNotificationService` からの意図的な逸脱なので、実装時の commit メッセージにも理由を残す。

キー `haptic_enabled` は既存 `HapticPreferences` と同名を再利用する（`HapticPreferences` は未使用のため実データは存在しないが、キーを揃えておく）。

`HapticFeedbackProviding` は `RecordViewModel` から差し替え可能にするための seam であり、設定判定は持たない。

```swift
protocol HapticFeedbackProviding {
    func helpRecorded()
    func taskSelection()
    func childSelection()
    func errorOccurred()
}

struct SystemHapticFeedbackProvider: HapticFeedbackProviding {
    func helpRecorded() { HapticFeedback.helpRecorded() }
    func taskSelection() { HapticFeedback.taskSelection() }
    func childSelection() { HapticFeedback.childSelection() }
    func errorOccurred() { HapticFeedback.errorOccurred() }
}
```

### 変更ファイル

| ファイル | 変更内容 |
| --- | --- |
| `Presentation/ViewModels/RecordViewModel.swift` | `hapticFeedback` / `feedbackSettings` を既定引数つきで注入。`playSuccessFeedback()` / `playErrorFeedback()` の private helper に集約。選択系 3 メソッドに触覚を追加し、`toggleTaskSelection(_:)` を新設 |
| `Presentation/Views/RecordView.swift` | 一括モードの `selectedTaskIds` 直接操作を `viewModel.toggleTaskSelection(task)` へ寄せる |
| `Presentation/Views/SettingsView.swift` | 「通知」Section の下に「サウンドと触覚」Section（トグル 2 つ）を追加 |
| `Utils/HapticFeedback.swift` | `HapticPreferences` と `*IfEnabled` 拡張（`executeIfEnabled` 含む 8 メソッド）を削除 |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 新規 UI 文言を ja/en で追加 |

`RecordViewModel` の注入は既存の `soundService` と同じく既定引数（`= nil` のとき実装を内部生成）にする。設定値の実体は `UserDefaults` 側にあるため、既存の生成箇所 4 か所（`RepositoryFactory.swift:66`、`SettingsView.swift:306`、`RecordTutorialView.swift:553`、`TutorialContainerView.swift:68`）はいずれも**無変更で済む**。テストでは fake を直接注入する。

効果音の再生ブロックは現在 `recordBulkHelp()`（:226-234）と `recordHelp()`（:289-296）に重複しているため、helper への集約でこの重複も解消される。

```swift
private func playSuccessFeedback() {
    if feedbackSettings.isSoundEnabled {
        do {
            try soundService.playCoinEarnSound()
            try soundService.playTaskCompleteSound()
        } catch {
            try? soundService.playErrorSound()
        }
    }
    if feedbackSettings.isHapticEnabled {
        hapticFeedback.helpRecorded()
    }
}
```

設定判定を実装側ではなく `RecordViewModel` 側に置く理由は、既存の `MockSoundService`（`playCoinEarnSoundCalled` 等の spy を持つ）をそのまま使って「OFF なら鳴らさない」を検証できるため。実装側に隠すと、モックが判定を持たないためテストが書けなくなる。

### データフロー

- 設定変更: `Toggle` → `FeedbackSettingsViewModel` → `FeedbackSettingsService` → `UserDefaults` へ即永続化
- 記録成功: `recordHelp()` / `recordBulkHelp()` → `playSuccessFeedback()` → 設定を参照 → 効果音 + 触覚
- 記録失敗: 失敗経路 → `playErrorFeedback()` → 設定を参照 → エラー音 + エラー触覚
- 選択時: View の `onTap` → `selectTask` / `selectChild` / `toggleTaskSelection` → 設定を参照 → 選択触覚

設定値の single source of truth は `UserDefaults` であり、`FeedbackSettingsService` は毎回そこを読む薄いラッパーに過ぎない。そのため設定画面と記録画面がそれぞれ別インスタンスを持っていても値はズレず、トグル変更は次の発火から即座に反映される。

### UI 文言（i18n）

| 用途 | ja | en |
| --- | --- | --- |
| Section 見出し | サウンドと触覚 | Sound & Haptics |
| トグル 1 | 効果音 | Sound Effects |
| トグル 2 | 振動（ハプティクス） | Haptics |

`Localizable.xcstrings` への追加は [[xcstrings-bulk-update]] の手順に従う（Python の `json.dump` で整形を壊さないこと）。plural variations は不要。

## エラー処理

- 触覚 API（`UIFeedbackGenerator`）は例外を投げないため、失敗しても無視してよい
- 効果音は既存どおり `catch` → `playErrorSound()` にフォールバックする
- 設定の読み書きは `UserDefaults` のため失敗経路なし。未保存時は両方 `true`
- 記録失敗時のエラーメッセージ表示は既存実装を維持する。特に「save 成功が 0 件のときは `NotificationManager` へ通知しない」ガード（`RecordViewModel.swift:240`）は触らない。通知すると observer 経由の `setLoading(true)` で `errorMessage` が消えるため

## テスト戦略

TDD で進める。特に「OFF のとき鳴らさない」は設定ガードの入れ忘れが green を素通りしやすいため、**実装前に必ず RED を確認する**。

| 対象 | テスト内容 |
| --- | --- |
| `FeedbackSettingsServiceTests` | 既定値が両方 true / 変更が永続化される / 再生成後も保持される。`UserDefaults(suiteName:)` を注入しグローバル状態を汚さない |
| `FeedbackSettingsServiceTests`（インスタンス跨ぎ） | **同じ `UserDefaults(suiteName:)` で 2 インスタンスを作り、片方の書き込みをもう片方が即座に読めることを検証**。stored property へ退行すると落ちる回帰ガード（この退行はアプリでは「再起動まで OFF が効かない」として現れるが、他のテストは全て green のまま素通りする） |
| `RecordViewModelTests`（追加） | 記録成功で `helpRecorded()` が呼ばれる / ハプティクス OFF で呼ばれない / サウンド OFF で `playCoinEarnSoundCalled` が false / 記録失敗で `errorOccurred()` が呼ばれる / `selectTask` `selectChild` `toggleTaskSelection` で対応する触覚が呼ばれる |
| `FeedbackSettingsViewModelTests` | トグル操作がサービスへ反映される |
| `toggleTaskSelection` | 未選択なら追加、選択済みなら削除（View から移設したロジックの直接検証） |

`MockHapticFeedbackProvider`（呼び出し記録つき spy）を新設する。

`SettingsView` の Toggle 表示自体は ViewInspector で traverse できない既知制約があるため（`BannerAdView` / `Material` / `AccessibilityImageLabel` blocker）、structural test は書かず ViewModel テストで担保し、最終確認は simulator 目視で行う。

英訳漏れは既存の `LocalizationStringCatalogTests` が検出する。

## スコープ外

- コインアニメーション開始時の触覚（二重振動を避けるため意図的に除外）
- 節目のお祝い演出（紙吹雪・連続記録など、issue 提案 2）— #150 に残すか別 issue へ切り出す
- `HapticButtonStyle` と View 拡張（`hapticButtonFeedback()` 等）の削除。未使用だが今回の設定機構とは重複しないため触らない
- 音量調整 UI（`setVolume` は既存のまま）
- ホーム/履歴など記録画面以外への触覚展開

## 受け入れ条件

- 記録完了時に効果音・コインアニメーション・触覚の三点が揃う（単発・一括の両モード）
- タスク選択・子ども選択で軽い触覚が鳴る（単発・一括の両モード）
- 設定画面の「効果音」「振動」トグルが動作し、OFF にすると実際に鳴らない
- 設定がアプリ再起動後も保持される
- 上記がユニットテストで検証されている（実機目視のみに依存しない）
- 実機またはシミュレータで記録フローを目視確認する

## 関連

- Issue #150
- 既存実装: `Utils/HapticFeedback.swift`、`Domain/Services/SoundService.swift`、`Presentation/Components/CoinAnimationView.swift`
- 参考にする流儀: `Domain/Services/ReminderNotificationService.swift`、`Presentation/ViewModels/NotificationSettingsViewModel.swift`
- 関連スキル: [[xcstrings-bulk-update]]
