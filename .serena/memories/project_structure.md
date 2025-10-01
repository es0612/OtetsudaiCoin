# プロジェクト構造

## ルートディレクトリ構成
```
OtetsudaiCoin/
├── app/                    # メインアプリケーション
├── scripts/                # 開発用スクリプト
├── .kiro/                  # Kiro仕様駆動開発
├── .claude/                # Claude Code設定
├── README.md               # プロジェクトREADME
├── CLAUDE.md               # Claude開発ガイド
└── PRIVACY_POLICY.md       # プライバシーポリシー
```

## app/ ディレクトリ構造
```
app/
├── OtetsudaiCoin.xcodeproj         # Xcodeプロジェクト
├── OtetsudaiCoin/                  # メインアプリ
│   ├── OtetsudaiCoinApp.swift      # アプリエントリポイント
│   ├── ContentView.swift            # ルートビュー
│   ├── Persistence.swift            # Core Data設定
│   │
│   ├── Data/                        # データ層
│   │   ├── Repositories/            # Repository実装
│   │   │   ├── CoreDataChildRepository.swift
│   │   │   ├── CoreDataHelpRecordRepository.swift
│   │   │   ├── CoreDataHelpTaskRepository.swift
│   │   │   └── InMemoryAllowancePaymentRepository.swift
│   │   └── Utils/                   # データユーティリティ
│   │
│   ├── Domain/                      # ドメイン層
│   │   ├── Entities/                # エンティティ定義
│   │   │   ├── Child.swift
│   │   │   ├── HelpRecord.swift
│   │   │   ├── HelpTask.swift
│   │   │   └── AllowancePayment.swift
│   │   ├── Repositories/            # Repositoryプロトコル
│   │   │   ├── ChildRepositoryProtocol.swift
│   │   │   ├── HelpRecordRepositoryProtocol.swift
│   │   │   ├── HelpTaskRepositoryProtocol.swift
│   │   │   └── AllowancePaymentRepositoryProtocol.swift
│   │   └── Services/                # ビジネスロジック
│   │       ├── AllowanceCalculator.swift
│   │       ├── MonthlyResetService.swift
│   │       ├── SoundService.swift
│   │       ├── TutorialService.swift
│   │       └── UnpaidAllowanceDetectorService.swift
│   │
│   ├── Presentation/                # プレゼンテーション層
│   │   ├── ViewModels/              # ViewModel
│   │   │   ├── Base/                # 基底ViewModel
│   │   │   ├── HomeViewModel.swift
│   │   │   ├── RecordViewModel.swift
│   │   │   ├── ChildManagementViewModel.swift
│   │   │   ├── TaskManagementViewModel.swift
│   │   │   ├── HelpHistoryViewModel.swift
│   │   │   ├── MonthlyHistoryViewModel.swift
│   │   │   └── HelpRecordEditViewModel.swift
│   │   ├── Views/                   # SwiftUIビュー
│   │   │   ├── HomeView.swift
│   │   │   ├── RecordView.swift
│   │   │   ├── ChildManagementView.swift
│   │   │   ├── TaskManagementView.swift
│   │   │   ├── HelpHistoryView.swift
│   │   │   ├── MonthlyHistoryView.swift
│   │   │   └── HelpRecordEditView.swift
│   │   └── Components/              # 再利用コンポーネント
│   │       ├── ChildCard.swift
│   │       ├── TaskRow.swift
│   │       └── CoinAnimation.swift
│   │
│   ├── Resources/                   # リソース
│   │   └── Sounds/                  # 効果音ファイル
│   │       ├── coin.mp3
│   │       └── success.mp3
│   │
│   ├── Utils/                       # 共通ユーティリティ
│   │   ├── ErrorMessageConverter.swift
│   │   └── DateExtensions.swift
│   │
│   ├── Assets.xcassets/             # アセット
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   │
│   └── OtetsudaiCoin.xcdatamodeld/  # Core Dataモデル
│       └── OtetsudaiCoin.xcdatamodel
│
├── OtetsudaiCoinTests/              # 単体テスト
│   ├── Data/                        # データ層テスト
│   ├── Domain/                      # ドメイン層テスト
│   │   └── Services/
│   ├── Presentation/                # プレゼンテーション層テスト
│   │   ├── ViewModels/
│   │   ├── Components/
│   │   └── Views/
│   └── Helpers/                     # テストヘルパー
│
└── OtetsudaiCoinUITests/            # UIテスト
```

## scripts/ ディレクトリ構造
```
scripts/
├── prepare-simulator.sh            # シミュレータ事前起動
├── benchmark-tests.sh              # パフォーマンスベンチマーク
└── test-performance-report.md      # パフォーマンスレポート
```

## 階層別の責務

### Data層 (app/OtetsudaiCoin/Data/)
- Core Dataとの直接的なやり取り
- Repositoryプロトコルの実装
- データの永続化・取得・更新・削除

### Domain層 (app/OtetsudaiCoin/Domain/)
- ビジネスロジックの定義
- エンティティの定義（Data層のモデルとは独立）
- Repositoryプロトコルの定義
- サービス層のビジネスルール

### Presentation層 (app/OtetsudaiCoin/Presentation/)
- UIの実装（SwiftUIビュー）
- ViewModelによる状態管理
- ユーザーインタラクションの処理
- Domainレイヤーへの橋渡し

## ファイル配置ルール

1. **機能単位でグループ化**: 関連する機能は同じディレクトリに配置
2. **レイヤー分離の厳守**: Data/Domain/Presentationの境界を越えない
3. **テスト構造の一致**: テストは本体と同じ階層構造を維持
4. **再利用コンポーネント**: Presentation/Components/に配置
5. **共通ユーティリティ**: Utils/に配置（レイヤー横断的なもの）

## Import組織

### 依存関係の方向
```
Presentation → Domain ← Data
     ↓            ↓
   Utils      Resources
```

### Import例
```swift
// Presentation層のファイル
import Foundation
import SwiftUI
import Domain  // ドメイン層のみインポート

// Data層のファイル
import Foundation
import CoreData
import Domain  // ドメイン層のみインポート

// Domain層のファイル
import Foundation
// 他層への依存なし
```
