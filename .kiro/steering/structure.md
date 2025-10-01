# プロジェクト構造

## ルートディレクトリ構成

```
OtetsudaiCoin/
├── app/                    # メインアプリケーション
├── scripts/                # 開発用スクリプト
├── .kiro/                  # Kiro仕様駆動開発
│   ├── steering/           # ステアリングドキュメント
│   └── specs/              # 仕様ドキュメント
├── .claude/                # Claude Code設定
│   └── commands/           # カスタムコマンド
├── .serena/                # Serena MCP メモリ
│   └── memories/           # プロジェクトメモリ
├── README.md               # プロジェクトREADME
├── CLAUDE.md               # Claude開発ガイド
├── PRIVACY_POLICY.md       # プライバシーポリシー
└── LICENSE                 # ライセンス
```

## app/ ディレクトリ構造（クリーンアーキテクチャ）

```
app/
├── OtetsudaiCoin.xcodeproj             # Xcodeプロジェクト
│
├── OtetsudaiCoin/                      # メインアプリ
│   ├── OtetsudaiCoinApp.swift          # アプリエントリポイント
│   ├── ContentView.swift                # ルートビュー
│   ├── Persistence.swift                # Core Data設定
│   │
│   ├── Data/                            # データ層
│   │   ├── Repositories/                # Repository実装
│   │   │   ├── CoreDataChildRepository.swift
│   │   │   ├── CoreDataHelpRecordRepository.swift
│   │   │   ├── CoreDataHelpTaskRepository.swift
│   │   │   └── InMemoryAllowancePaymentRepository.swift
│   │   └── Utils/                       # データユーティリティ
│   │
│   ├── Domain/                          # ドメイン層
│   │   ├── Entities/                    # エンティティ定義
│   │   │   ├── Child.swift
│   │   │   ├── HelpRecord.swift
│   │   │   ├── HelpTask.swift
│   │   │   └── AllowancePayment.swift
│   │   ├── Repositories/                # Repositoryプロトコル
│   │   │   ├── ChildRepositoryProtocol.swift
│   │   │   ├── HelpRecordRepositoryProtocol.swift
│   │   │   ├── HelpTaskRepositoryProtocol.swift
│   │   │   └── AllowancePaymentRepositoryProtocol.swift
│   │   └── Services/                    # ビジネスロジック
│   │       ├── AllowanceCalculator.swift
│   │       ├── MonthlyResetService.swift
│   │       ├── SoundService.swift
│   │       ├── TutorialService.swift
│   │       ├── UnpaidAllowanceDetectorService.swift
│   │       └── SampleDataService.swift
│   │
│   ├── Presentation/                    # プレゼンテーション層
│   │   ├── ViewModels/                  # ViewModel
│   │   │   ├── Base/                    # 基底ViewModel
│   │   │   ├── HomeViewModel.swift
│   │   │   ├── RecordViewModel.swift
│   │   │   ├── ChildManagementViewModel.swift
│   │   │   ├── TaskManagementViewModel.swift
│   │   │   ├── HelpHistoryViewModel.swift
│   │   │   ├── MonthlyHistoryViewModel.swift
│   │   │   └── HelpRecordEditViewModel.swift
│   │   ├── Views/                       # SwiftUIビュー
│   │   │   ├── HomeView.swift
│   │   │   ├── RecordView.swift
│   │   │   ├── ChildManagementView.swift
│   │   │   ├── TaskManagementView.swift
│   │   │   ├── HelpHistoryView.swift
│   │   │   ├── MonthlyHistoryView.swift
│   │   │   └── HelpRecordEditView.swift
│   │   └── Components/                  # 再利用コンポーネント
│   │       ├── ChildCard.swift
│   │       ├── TaskRow.swift
│   │       └── CoinAnimation.swift
│   │
│   ├── Resources/                       # リソース
│   │   └── Sounds/                      # 効果音ファイル
│   │       ├── coin.mp3
│   │       └── success.mp3
│   │
│   ├── Utils/                           # 共通ユーティリティ
│   │   ├── ErrorMessageConverter.swift
│   │   └── DateExtensions.swift
│   │
│   ├── Assets.xcassets/                 # アセット
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   │
│   └── OtetsudaiCoin.xcdatamodeld/      # Core Dataモデル
│       └── OtetsudaiCoin.xcdatamodel
│
├── OtetsudaiCoinTests/                  # 単体テスト
│   ├── Data/                            # データ層テスト
│   ├── Domain/                          # ドメイン層テスト
│   │   └── Services/
│   ├── Presentation/                    # プレゼンテーション層テスト
│   │   ├── ViewModels/
│   │   ├── Components/
│   │   └── Views/
│   └── Helpers/                         # テストヘルパー
│
└── OtetsudaiCoinUITests/                # UIテスト
```

## scripts/ ディレクトリ構造

```
scripts/
├── prepare-simulator.sh            # シミュレータ事前起動
├── benchmark-tests.sh              # パフォーマンスベンチマーク
└── test-performance-report.md      # パフォーマンスレポート
```

## レイヤー別の責務

### Data層 (`app/OtetsudaiCoin/Data/`)
**役割**: データの永続化と取得の実装
- Core Dataとの直接的なやり取り
- Repositoryプロトコルの実装
- データのCRUD操作

**依存**: Domain層のプロトコルに依存

### Domain層 (`app/OtetsudaiCoin/Domain/`)
**役割**: ビジネスロジックの定義
- エンティティの定義（純粋なSwift型）
- Repositoryプロトコルの定義
- ビジネスルールの実装（Services）

**依存**: 他のレイヤーに依存しない（中心的独立性）

### Presentation層 (`app/OtetsudaiCoin/Presentation/`)
**役割**: UIの実装と状態管理
- SwiftUIビューの実装
- ViewModelによる状態管理（@Observable）
- ユーザーインタラクションの処理

**依存**: Domain層に依存

## ファイル命名規則

### ViewModels
```
[Feature]ViewModel.swift
例: HomeViewModel.swift, RecordViewModel.swift
```

### Services
```
[Purpose]Service.swift
例: SoundService.swift, TutorialService.swift
```

### Repositories
```
CoreData[Entity]Repository.swift    # Core Data実装
InMemory[Entity]Repository.swift    # テスト用実装
例: CoreDataChildRepository.swift, InMemoryAllowancePaymentRepository.swift
```

### Views
```
[Feature]View.swift
例: HomeView.swift, RecordView.swift
```

### Components
```
[Component]Component.swift または [Component].swift
例: ChildCard.swift, TaskRow.swift
```

### Tests
```
[TargetName]Tests.swift
例: AllowanceCalculatorTests.swift, HomeViewModelTests.swift
```

## コード組織パターン

### 機能別グループ化
関連する機能は同じディレクトリに配置します。

**例**: お小遣い管理機能
- `Domain/Services/AllowanceCalculator.swift`
- `Domain/Entities/AllowancePayment.swift`
- `Presentation/ViewModels/MonthlyHistoryViewModel.swift`
- `Presentation/Views/MonthlyHistoryView.swift`

### レイヤー分離の厳守
レイヤー間の境界を越えない配置を徹底します。

**正しい例**:
```
Presentation/ViewModels/HomeViewModel.swift
Domain/Services/AllowanceCalculator.swift
Data/Repositories/CoreDataChildRepository.swift
```

**誤った例**:
```
❌ Presentation/Services/AllowanceCalculator.swift
❌ Data/ViewModels/SomeViewModel.swift
```

### テスト構造の一致
テストは本体と同じ階層構造を維持します。

**本体**:
```
app/OtetsudaiCoin/Domain/Services/AllowanceCalculator.swift
```

**テスト**:
```
app/OtetsudaiCoinTests/Domain/Services/AllowanceCalculatorTests.swift
```

## Import組織

### 依存関係の方向
```
Presentation → Domain ← Data
     ↓            ↓
   Utils      Resources
```

### Import例

**Presentation層のファイル**:
```swift
import Foundation
import SwiftUI
import Domain  // ドメイン層のみインポート可能
```

**Data層のファイル**:
```swift
import Foundation
import CoreData
import Domain  // ドメイン層のみインポート可能
```

**Domain層のファイル**:
```swift
import Foundation
// 他層への依存なし
```

### Import順序規約
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

## ファイル配置ルール

### 1. 機能単位でグループ化
関連する機能は同じディレクトリに配置します。

### 2. レイヤー分離の厳守
Data/Domain/Presentationの境界を越えないようにします。

### 3. テスト構造の一致
テストは本体と同じ階層構造を維持します。

### 4. 再利用コンポーネント
Presentation/Components/に配置します。

### 5. 共通ユーティリティ
Utils/に配置（レイヤー横断的なもの）します。

### 6. リソースファイル
Resources/に種類別に配置します。

### 7. テストヘルパー
OtetsudaiCoinTests/Helpers/に配置します。

## アーキテクチャ原則

### SOLID 原則
- **Single Responsibility**: 各クラスは単一の責任を持つ
- **Open/Closed**: 拡張に開き、修正に閉じる
- **Liskov Substitution**: 派生クラスは基底クラスと置き換え可能
- **Interface Segregation**: クライアントに不要なインターフェースを強制しない
- **Dependency Inversion**: 抽象に依存し、具象に依存しない

### クリーンアーキテクチャ原則
- **依存性の逆転**: 外側のレイヤーが内側のレイヤーに依存
- **安定依存の原則**: 不安定なものから安定したものへ依存
- **エンティティの独立性**: ビジネスルールは外部から独立

### Repository パターン原則
- **抽象化**: データソースの実装詳細を隠蔽
- **テスタビリティ**: モック実装による単体テスト
- **切り替え可能**: Core Data ⇔ InMemory の容易な切り替え

## 特殊なディレクトリ

### Base/ ディレクトリ
基底クラス、プロトコル、共通実装を配置します。

**例**: `Presentation/ViewModels/Base/`

### Utils/ ディレクトリ
レイヤー横断的なユーティリティを配置します。

**例**: `ErrorMessageConverter.swift`, `DateExtensions.swift`

### Helpers/ ディレクトリ（テスト専用）
テストヘルパー、モック、ファクトリーを配置します。

**例**: `OtetsudaiCoinTests/Helpers/`

## 拡張時のガイドライン

### 新機能追加時
1. Domain層でエンティティとプロトコルを定義
2. Data層でRepository実装を作成
3. Domain層でServiceを実装（必要な場合）
4. Presentation層でViewModelとViewを作成
5. 各層のテストを実装

### リファクタリング時
1. レイヤー分離を維持
2. 依存関係の方向を守る
3. テスト構造を同期
4. 命名規則を遵守

### テスト追加時
1. 本体と同じ階層構造に配置
2. 同じファイル命名規則を使用
3. テストヘルパーは Helpers/ に配置
