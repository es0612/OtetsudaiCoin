# プロジェクト構造

## ルートディレクトリ構成

```text
OtetsudaiCoin/
├── app/                    # Xcode プロジェクト（下記）
├── scripts/                # 開発用スクリプト（下記）
├── docs/                   # GitHub Pages・リリース手順書 (releases/)・スクショ (screenshots/)・superpowers の spec/plan
├── fastlane/               # ASC メタデータ (metadata/)
├── .github/workflows/      # CI
├── .kiro/steering/         # ステアリングドキュメント（自動では読み込まれない）
├── .claude/commands/       # カスタムコマンド
├── README.md
├── CLAUDE.md               # Claude 開発ガイド
├── PRIVACY_POLICY.md
└── LICENSE
```

## app/ ディレクトリ構造（クリーンアーキテクチャ）

```text
app/
├── OtetsudaiCoin.xcodeproj/
├── OtetsudaiCoin/                   # メインアプリ（単一モジュール）
│   ├── Data/Repositories/           # Core Data によるリポジトリ実装 (CoreData[Entity]Repository)
│   ├── Domain/
│   │   ├── Entities/                # ドメインモデル
│   │   ├── Repositories/            # リポジトリのプロトコル ([Entity]Repository)
│   │   └── Services/                # ビジネスロジック
│   ├── Presentation/
│   │   ├── Components/              # 画面をまたぐ部品
│   │   ├── ViewModels/ (Base/)      # @Observable ViewModel と基底クラス
│   │   └── Views/ (Components/, Tutorial/)
│   ├── Resources/Sounds/            # 効果音
│   ├── Utils/                       # レイヤー横断のユーティリティ・デザイントークン
│   ├── en.lproj/, ja.lproj/
│   └── OtetsudaiCoin.xcdatamodeld/  # Core Data モデル（バージョン付き）
├── OtetsudaiCoinTests/              # 単体テスト: Data/ Domain/ (Services/) Helpers/ Localization/ Presentation/ (Components/ ViewModels/ Views/) Utils/
└── OtetsudaiCoinUITests/            # UI テスト・スクショ撮影 (ASCScreenshotUITests / VerificationScreenshotUITests)
```

ファイル単位の一覧は載せない（コードの変更ですぐ古くなるため）。実際のファイルは `find app/OtetsudaiCoin -name '*.swift'` で確認する。

## scripts/ ディレクトリ構造

```text
scripts/
├── lib/common.sh                         # 共通関数 (resolve_jq / resolve_udid ほか)
├── capture-asc-screenshots.sh            # ASC 提出用スクショ撮影
├── capture-verification-screenshots.sh   # 検証用スクショ撮影（外観・文字サイズ切替）
├── compare-screenshots.sh                # 検証スクショの before/after 比較
├── release-status.sh                     # 公開中 version と未出荷件数
├── version-bump-check.sh                 # リリース PR の version bump 検査 (CI)
├── prepare-simulator.sh                  # シミュレータ事前起動
└── benchmark-tests.sh                    # テスト実行時間の計測
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
```text
[Entity]Repository.swift            # Domain/Repositories/ のプロトコル
CoreData[Entity]Repository.swift    # Data/Repositories/ の Core Data 実装
Mock[Entity]Repository              # テスト用のモック（OtetsudaiCoinTests/Helpers/TestMocks.swift）
例: ChildRepository.swift, CoreDataChildRepository.swift, MockChildRepository
```

### Views
```
[Feature]View.swift
例: HomeView.swift, RecordView.swift
```

### Components
```text
[Component]View.swift または [Component].swift
例: TaskCardView.swift, CoinAnimationView.swift, StatisticsCard.swift
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
- `Presentation/ViewModels/MonthlySummaryViewModel.swift`
- `Presentation/Views/MonthlySummaryView.swift`

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
```text
app/OtetsudaiCoin/Domain/Services/MonthlyResetService.swift
```

**テスト**:
```text
app/OtetsudaiCoinTests/Domain/Services/MonthlyResetServiceTests.swift
```

（例外もある: `AllowanceCalculatorTests.swift` は `OtetsudaiCoinTests/Domain/` 直下にある。テストを探すときは `find app -name '<対象>Tests.swift'` で全階層を探す）

## Import組織

### 依存関係の方向
```
Presentation → Domain ← Data
     ↓            ↓
   Utils      Resources
```

### Import
アプリは単一モジュールなので、層ごとの `import Domain` のような import は無い（書くとビルドが通らない）。層の境界は import では強制されないため、ディレクトリ配置と命名で守る。

```swift
// 1. Apple のフレームワーク
import Foundation
import SwiftUI

// 2. 外部ライブラリ（GoogleMobileAds、テストでは ViewInspector）
import GoogleMobileAds

// テストターゲットではアプリ本体を @testable で読む
@testable import OtetsudaiCoin
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
- **差し替え可能**: テストでは Mock[Entity]Repository に差し替える

## 特殊なディレクトリ

### Base/ ディレクトリ
基底クラス、プロトコル、共通実装を配置します。

**例**: `Presentation/ViewModels/Base/`

### Utils/ ディレクトリ
レイヤー横断的なユーティリティを配置します。

**例**: `ErrorMessageConverter.swift`, `TimeStringFormatter.swift`

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
