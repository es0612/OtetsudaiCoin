# 技術スタック

## アーキテクチャ
- **MVVM + クリーンアーキテクチャ**: Data/Domain/Presentation層の明確な分離
- **Repository パターン**: データアクセスの完全な抽象化
- **依存性注入**: RepositoryFactory + ViewModelFactory による高度なDI

## フロントエンド (iOS)
- **SwiftUI**: iOS 18.5+ 対応
- **状態管理**: @Observable（@MainActor/@Publishedから移行済み）
- **永続化**: Core Data
- **音響効果**: AVFoundation（SoundService）
- **触覚フィードバック**: UIKit Haptics
- **アクセシビリティ**: Dynamic Type, High Contrast対応

## テストフレームワーク
- **XCTest**: 単体テスト、統合テスト
- **ViewInspector**: SwiftUI テスト
- **TDD**: テスト駆動開発アプローチ
- **パフォーマンステスト**: benchmark-tests.sh による計測

## 開発ツール
- **Xcode**: メイン開発環境
- **Swift**: プログラミング言語
- **iOS Simulator**: テスト実行環境
- **Git**: バージョン管理

## 主要なサービス
- **AllowanceCalculator**: お小遣い計算ロジック
- **MonthlyResetService**: 月次自動処理
- **SoundService**: 効果音管理
- **TutorialService**: チュートリアル管理
- **SampleDataService**: サンプルデータ生成（DEBUG）
- **UnpaidAllowanceDetectorService**: 未払い検出

## データ層
- **Core Data**: 永続化フレームワーク
- **Repository実装**:
  - CoreDataChildRepository
  - CoreDataHelpRecordRepository
  - CoreDataHelpTaskRepository
  - InMemoryAllowancePaymentRepository
