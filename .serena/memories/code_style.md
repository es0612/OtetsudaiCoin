# コードスタイルと規約

## 命名規則

### ファイル命名
- **ViewModels**: `[Feature]ViewModel.swift`
  - 例: `HomeViewModel.swift`, `RecordViewModel.swift`
- **Services**: `[Purpose]Service.swift`
  - 例: `SoundService.swift`, `TutorialService.swift`
- **Repositories**: `CoreData[Entity]Repository.swift` または `InMemory[Entity]Repository.swift`
  - 例: `CoreDataChildRepository.swift`, `InMemoryAllowancePaymentRepository.swift`
- **Views**: `[Feature]View.swift`
  - 例: `HomeView.swift`, `RecordView.swift`

### クラス・構造体命名
- **PascalCase**: クラス、構造体、プロトコル、列挙型
- **camelCase**: 変数、関数、プロパティ
- **Protocol命名**: 末尾に`Protocol`を付ける
  - 例: `SoundServiceProtocol`, `ChildRepositoryProtocol`

## アーキテクチャパターン

### レイヤー分離
```
Data/          # データ層
├── Repositories/   # Repository実装
└── Utils/          # データユーティリティ

Domain/        # ドメイン層
├── Entities/       # エンティティ定義
├── Repositories/   # Repositoryプロトコル
└── Services/       # ビジネスロジック

Presentation/  # プレゼンテーション層
├── ViewModels/     # ViewModel
├── Views/          # SwiftUIビュー
└── Components/     # 再利用コンポーネント
```

### 依存関係
- **依存の方向**: Presentation → Domain ← Data
- **プロトコル指向**: Domain層にプロトコル、Data層に実装
- **DI (依存性注入)**: Factory パターン使用

## 状態管理

### @Observable パターン
```swift
@Observable
class HomeViewModel {
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    // ...
}
```

### 重要な規約
- **@MainActor**: すべてのViewModelは`@MainActor`を使用
- **Observable**: `@Observable`マクロで状態管理（`@Published`は使用しない）
- **プロパティ**: `var`で宣言、計算プロパティは`computed`属性

## エラーハンドリング

### エラーメッセージ変換
- `ErrorMessageConverter`を使用してユーザーフレンドリーなメッセージに変換
- ViewModelで`errorMessage`プロパティを使用

### パターン
```swift
do {
    try await someOperation()
} catch {
    errorMessage = ErrorMessageConverter.convert(error)
}
```

## テスト規約

### テストファイル配置
- テストは`app/OtetsudaiCoinTests/`に配置
- 同じ階層構造を維持: `Data/`, `Domain/`, `Presentation/`

### テスト命名
- `test_[機能]_[条件]_[期待結果]()`形式
- 例: `test_calculateMonthlyAllowance_withValidData_returnsCorrectAmount()`

### ViewInspector使用
- SwiftUIビューのテストには`ViewInspector`を使用
- UI要素の存在確認、テキスト検証、アクション実行

## import順序
```swift
// 1. Foundation/UIKit
import Foundation
import SwiftUI

// 2. 外部ライブラリ
import ViewInspector

// 3. プロジェクト内モジュール（階層順）
import Domain
import Presentation
```

## その他の規約

### コメント
- 公開API: ドキュメントコメント使用
- 複雑なロジック: インラインコメントで説明
- TODO: 使用禁止（issueで管理）

### ファイル構成
- 1ファイル = 1主要型（class/struct/enum）
- 関連する小さな型は同じファイルに配置可能
- Extensions は別ファイルまたは同ファイル末尾

### アクセス制御
- デフォルト: `internal`
- 公開API: `public`
- 実装詳細: `private` または `fileprivate`
