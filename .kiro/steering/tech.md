# 技術スタック

## アーキテクチャ

### 設計パターン
- **MVVM + クリーンアーキテクチャ**: Data/Domain/Presentation層の明確な分離
- **Repository パターン**: データアクセスの完全な抽象化
- **依存性注入**: RepositoryFactory + ViewModelFactory による高度なDI
- **TDD（テスト駆動開発）**: 品質を保証する開発プロセス

### レイヤー構成
```
Presentation (UI + ViewModel)
     ↓
Domain (Entities + Protocols + Services)
     ↑
Data (Repository実装 + Core Data)
```

**依存関係の方向**: Presentation → Domain ← Data

## iOS 開発環境

### フレームワーク
- **SwiftUI**: 宣言的UIフレームワーク
- **Core Data**: データ永続化フレームワーク
- **AVFoundation**: 音響効果の再生
- **UIKit Haptics**: 触覚フィードバック

### 最小対応環境
- **iOS**: 18.5以上
- **Xcode**: 最新版推奨
- **Swift**: 最新安定版

## 状態管理

### @Observable パターン（最新）
- **@Observable マクロ**: SwiftUIネイティブな状態管理
- **@MainActor**: すべてのViewModelで使用
- **移行完了**: @Published/@MainActorから@Observableへ完全移行済み

### 従来パターン（廃止済み）
- ~~@Published~~ → @Observable に置き換え
- ~~ObservableObject~~ → @Observable マクロに置き換え

## データ層

### Core Data 実装
- **永続化ストレージ**: Core Data フレームワーク
- **Repository パターン**: データアクセスの抽象化
- **コンテキスト**: viewContext を使用（バックグラウンドコンテキストは不使用）

### Repository 実装
- **CoreDataChildRepository**: 子供データ管理
- **CoreDataHelpRecordRepository**: お手伝い記録管理
- **CoreDataHelpTaskRepository**: タスクデータ管理
- **InMemoryAllowancePaymentRepository**: お小遣い支払い記録（メモリ内）

## ビジネスロジック層

### サービス
- **AllowanceCalculator**: お小遣い計算ロジック
- **MonthlyResetService**: 月次自動処理
- **SoundService**: 効果音管理
- **TutorialService**: チュートリアル管理
- **UnpaidAllowanceDetectorService**: 未払い検出
- **SampleDataService**: サンプルデータ生成（DEBUG専用）

### エンティティ
- **Child**: 子供エンティティ
- **HelpRecord**: お手伝い記録エンティティ
- **HelpTask**: タスクエンティティ
- **AllowancePayment**: お小遣い支払い記録エンティティ

## テストフレームワーク

### テストツール
- **XCTest**: 単体テスト、統合テスト
- **ViewInspector**: SwiftUI ビューテスト
- **パフォーマンステスト**: benchmark-tests.sh による計測

### テスト戦略
- **TDD アプローチ**: テスト駆動開発
- **テスト構造**: 本体と同じ階層構造を維持
- **モックリポジトリ**: テスト用のインメモリ実装

## 開発コマンド

### テスト実行
```bash
# 全テスト実行
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# 特定のテスト実行
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/AllowanceCalculatorTests
```

### ビルド
```bash
# ビルド実行
xcodebuild build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# クリーンビルド
xcodebuild clean build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### シミュレータ管理
```bash
# シミュレータ事前起動（テスト高速化）
./scripts/prepare-simulator.sh -s "iPhone 16"

# シミュレータ一覧
xcrun simctl list devices available

# シミュレータ起動
xcrun simctl boot "iPhone 16"

# シミュレータシャットダウン
xcrun simctl shutdown all
```

### パフォーマンステスト
```bash
# ベンチマーク実行
./scripts/benchmark-tests.sh
```

## アクセシビリティ

### 対応機能
- **Dynamic Type**: 動的文字サイズ対応
- **High Contrast**: 高コントラストモード対応
- **VoiceOver**: スクリーンリーダー対応（一部実装）

### 実装方針
- すべてのUI要素に適切な accessibilityLabel を設定
- インタラクティブ要素に accessibilityHint を提供
- 視覚・聴覚・触覚の複数の感覚でフィードバック

## UX 実装技術

### マルチモーダルフィードバック
- **視覚**: SwiftUI アニメーション、色彩、アイコン
- **聴覚**: AVFoundation による効果音
- **触覚**: UIKit Haptics による振動フィードバック

### 実装例
```swift
// コイン獲得時のフィードバック
func recordHelp() {
    showCoinAnimation = true        // 視覚
    soundService.playSound(.coin)   // 聴覚
    hapticFeedback.generate()       // 触覚
}
```

## 開発環境設定

### 必須ツール
- **Xcode**: iOS開発IDE
- **Git**: バージョン管理
- **Bash**: スクリプト実行環境

### 推奨ツール
- **ripgrep (rg)**: 高速コード検索
- **SwiftLint**: コード品質チェック（未導入、今後検討）

## 環境変数

現在、特定の環境変数設定は不要です。

## ポート設定

iOSアプリケーションのため、ポート設定は不要です。

## 依存関係管理

### 現在の依存関係
- **標準フレームワークのみ**: 外部ライブラリ依存なし
- **SwiftUI**: OS標準
- **Core Data**: OS標準
- **AVFoundation**: OS標準
- **UIKit**: OS標準（Haptics用）

### 将来的な検討事項
- **SwiftLint**: コード品質の自動チェック
- **Firebase**: アナリティクス、クラッシュレポート（必要に応じて）

## 開発プロセス

### ワークフロー
1. **Red**: テストを書く（失敗）
2. **Green**: 最小限の実装で通す
3. **Refactor**: コードを改善
4. **Repeat**: 次の機能へ

### 品質保証
- TDDによる継続的なテスト
- パフォーマンスベンチマークによる性能確認
- アクセシビリティ標準への準拠確認

### デバッグ機能（DEBUGビルドのみ）
- サンプルデータ生成（3ヶ月分）
- 記録データのみ削除
- 全データ削除

## バージョン管理

### Git ブランチ戦略
- **main**: 本番ブランチ
- **feature/***: 機能開発ブランチ
- **fix/***: バグ修正ブランチ

### コミットメッセージ規約
- `feat:` - 新機能
- `fix:` - バグ修正
- `refactor:` - リファクタリング
- `test:` - テスト追加・修正
- `docs:` - ドキュメント更新
- `chore:` - その他の変更
