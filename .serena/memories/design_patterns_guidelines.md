# 設計パターンとガイドライン

## アーキテクチャパターン

### MVVM + クリーンアーキテクチャ

**レイヤー構成:**
```
Presentation (UI + ViewModel)
     ↓
Domain (Entities + Protocols + Services)
     ↑
Data (Repository実装 + Core Data)
```

**重要な原則:**
- Domain層は他の層に依存しない（中心的な独立性）
- Data層とPresentation層はDomain層に依存
- レイヤー間の通信はプロトコル経由

### Repository パターン

**実装例:**
```swift
// Domain層: プロトコル定義
protocol ChildRepositoryProtocol {
    func fetchAll() async throws -> [Child]
    func save(_ child: Child) async throws
}

// Data層: 実装
class CoreDataChildRepository: ChildRepositoryProtocol {
    // Core Dataとの具体的なやり取り
}
```

**メリット:**
- データソースの抽象化
- テスタビリティの向上
- 実装の切り替えが容易

### Factory パターン（依存性注入）

**RepositoryFactory:**
```swift
class RepositoryFactory {
    static func createChildRepository() -> ChildRepositoryProtocol {
        return CoreDataChildRepository()
    }
}
```

**ViewModelFactory:**
```swift
class ViewModelFactory {
    static func createHomeViewModel() -> HomeViewModel {
        let repo = RepositoryFactory.createChildRepository()
        return HomeViewModel(repository: repo)
    }
}
```

**メリット:**
- 依存関係の一元管理
- テスト時のモック差し替えが簡単
- 初期化ロジックの集約

## SwiftUI 状態管理

### @Observable パターン（最新）

**基本構造:**
```swift
import Observation

@Observable
@MainActor
class MyViewModel {
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var items: [Item] = []
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await repository.fetchAll()
        } catch {
            errorMessage = ErrorMessageConverter.convert(error)
        }
    }
}
```

**重要ポイント:**
- `@Observable`マクロを使用（`@Published`は使わない）
- すべてのViewModelに`@MainActor`を付与
- `isLoading`, `errorMessage`, `successMessage`を標準プロパティとして持つ

### 従来パターンからの移行（完了済み）

**旧:**
```swift
@MainActor
class OldViewModel: ObservableObject {
    @Published var state: ViewState = .idle
}
```

**新:**
```swift
@Observable
@MainActor
class NewViewModel {
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
}
```

## エラーハンドリングパターン

### ErrorMessageConverter の使用

```swift
do {
    try await someOperation()
    successMessage = "操作が完了しました"
} catch {
    errorMessage = ErrorMessageConverter.convert(error)
}
```

**変換ルール:**
- Core Dataエラー → ユーザーフレンドリーなメッセージ
- ネットワークエラー → 接続問題の説明
- ビジネスロジックエラー → 具体的な指示

## サービスレイヤーパターン

### ビジネスロジックの配置

**AllowanceCalculator（計算サービス）:**
```swift
struct AllowanceCalculator {
    static func calculateMonthlyAllowance(
        records: [HelpRecord],
        coinRate: Int
    ) -> Int {
        let totalCoins = records.reduce(0) { $0 + $1.coins }
        return totalCoins * coinRate
    }
}
```

**MonthlyResetService（自動処理サービス）:**
```swift
class MonthlyResetService {
    func performMonthlyReset() async throws {
        // 月末の自動処理ロジック
    }
}
```

**SoundService（システムサービス）:**
```swift
@MainActor
class SoundService: SoundServiceProtocol {
    func playSound(_ type: SoundType) {
        // AVFoundation を使った音響処理
    }
}
```

## テストパターン

### ViewInspector を使った SwiftUI テスト

```swift
func test_homeView_displaysChildName() throws {
    let viewModel = HomeViewModel(/* モックリポジトリ */)
    let view = HomeView(viewModel: viewModel)
    
    let text = try view.inspect().find(text: "太郎")
    XCTAssertNotNil(text)
}
```

### モックリポジトリパターン

```swift
class MockChildRepository: ChildRepositoryProtocol {
    var mockChildren: [Child] = []
    
    func fetchAll() async throws -> [Child] {
        return mockChildren
    }
}
```

### テスト命名規約

```swift
func test_メソッド名_条件_期待結果() {
    // テストコード
}

// 例:
func test_calculateMonthlyAllowance_withValidRecords_returnsCorrectAmount() {
    // ...
}
```

## UX 実装パターン

### マルチモーダルフィードバック

**コイン獲得時の実装例:**
```swift
func recordHelp() {
    // 1. データ保存
    await repository.save(record)
    
    // 2. 視覚フィードバック
    showCoinAnimation = true
    
    // 3. 聴覚フィードバック
    soundService.playSound(.coin)
    
    // 4. 触覚フィードバック
    hapticFeedback.generate()
    
    // 5. 成功メッセージ
    successMessage = "お手伝いを記録しました！"
}
```

### アクセシビリティ対応

```swift
Text("コイン: \(coins)")
    .accessibilityLabel("獲得コイン数: \(coins)枚")
    .dynamicTypeSize(...xxxxLarge)

Button("記録する") { }
    .accessibilityHint("お手伝いを記録します")
```

## 特別なガイドライン

### DEBUG ビルド限定機能

```swift
#if DEBUG
struct DeveloperSection: View {
    var body: some View {
        Section("開発者向け") {
            Button("サンプルデータ生成") { }
            Button("全データ削除") { }
        }
    }
}
#endif
```

### Core Data 操作の注意点

1. **非同期処理**: すべてのCRUD操作は`async/await`を使用
2. **エラーハンドリング**: 必ず`do-catch`でラップ
3. **コンテキスト**: `viewContext`を使用（バックグラウンドコンテキストは不使用）
4. **保存確認**: `hasChanges`をチェックしてから保存

### パフォーマンス最適化

1. **遅延読み込み**: 大量データは必要に応じて取得
2. **計算プロパティ**: 重い計算はキャッシュまたはメモ化
3. **状態更新**: 不要な`@Observable`更新を避ける
4. **Core Dataクエリ**: フェッチリクエストを最適化

## プロジェクト固有の注意事項

### テーマカラーシステム
- 各子供に固有のテーマカラーを割り当て
- `Color`拡張でカスタムカラーを定義
- アクセシビリティのためコントラスト比を確認

### 月次処理
- `MonthlyResetService`が月末に自動実行
- お小遣い計算は`AllowanceCalculator`を使用
- 支払い記録は`AllowancePayment`エンティティで管理

### チュートリアルフロー
- `TutorialService`で進行状態を管理
- UserDefaultsで表示済みフラグを保存
- いつでも再表示可能な設計
