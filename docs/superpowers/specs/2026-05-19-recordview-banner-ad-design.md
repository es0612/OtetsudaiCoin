# RecordView へのバナー広告配置 — 設計書

Issue: #49
作成日: 2026-05-19

## 背景

PR #10（`feat: お手伝い登録画面にAdMobバナー広告を追加`）でバナー広告を導入したが、実態は `TaskManagementView`（Settings 配下のお手伝いタスク管理画面）に配置されており、初期セットアップ後はほぼ訪問されないため AdMob 上の impressions が極端に低い状態だった。

Issue #49 で「お手伝い登録時に見えるようにする」案が提示され、毎日の主要利用画面である **`RecordView`** にバナーを追加する方針で合意。

## ターゲット利用者の前提

RecordView の利用者は「親が代わりに記録」と「子供が自分で記録」の両ケースがあり、家庭によって異なる。よって設計は以下を満たす必要がある:

- 子供が誤タップしにくい位置
- 親が見やすい位置
- タブの切替やリスト選択 UI（タスクカード）から十分離れている

App Store の Kids カテゴリ申請はしておらず、`GADKidApp` / `tagForChildDirectedTreatment` 等の COPPA 系フラグも未設定。AdMob は通常配信。

## 方針判断

**採用: Approach A（RecordView 下部にバナー常時配置）**、配置位置は **Option 2（ScrollView 内側、コンテンツ最下部）**

理由:

- 既存 `BannerAdView` を再利用する最小変更で、`TaskManagementView` のみだった配置を毎日触られる画面へ拡張できる
- ScrollView 内側に置くことで、子供がタスクカードを選んだりリストをタップしている瞬間には視野/タップ範囲に入らない（impressions は scroll 到達時のみ）
- Toast 風表示（Approach B）は AdMob の impression 計測 / eCPM と相性が悪い
- 親レビュー画面への分散（Approach C）は次の手として温存

検討して採用しなかった配置:

- **Option 1（ScrollView 外側 / TabBar 上に固定）**: impressions は最大化されるが、tab 切替や RecordButton 操作中に常時広告が画面に居ることで誤タップリスクが残る。impressions が伸びなかった場合のフォールバックとして温存
- **Option 3（Record button の直上）**: 露出は大きいが CTA 直近で誤タップリスクが高く、不採用

## 実装スコープ

### 1. `RecordView.swift` への BannerAdView 追加

`var body` 内の ScrollView コンテンツ末尾、`recordButtonView`（line 197 付近）の直後に `BannerAdView` を配置する。

具体的な構造:

```swift
ScrollView {
    VStack(spacing: 16) {
        childSelectionView
        dateSection
        taskListView
        recordButtonView
        BannerAdView()
            .frame(height: 50)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}
```

- `frame(height: 50)`: AdMob 標準バナーの高さ。Ad 読み込み中 / fill rate 0 でも layout shift しない
- `padding(.top, 16)`: recordButtonView との視覚的・物理的距離
- `padding(.bottom, 8)`: scroll 終端と少し余白

### 2. `TaskManagementView.swift` は変更しない

既存の BannerAdView 配置（line 46-47）はそのまま残す。削除する積極的理由がなく、ゼロコストで二重露出として保持できる。本 issue のスコープは「RecordView への追加」であり、TaskManagementView の扱いは別途必要になれば独立 issue で。

### 3. `BannerAdView` / `AdConstants` は変更しない

`AdConstants.bannerAdUnitID` は既に DEBUG / RELEASE で test ad / production ad の切り替えがある（PR #21）。Non-personalized 設定（npa=1）も既に実装済み（PR #22）。

### 4. テストの追加

`app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` を **新規作成** する（現状 `RecordViewModelTests.swift` は別ファイルとして存在するが、View 単位のテストは未整備）。最低限のスケルトン + 本 issue 用テストを追加:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class RecordViewTests: XCTestCase {
    func testRecordViewIncludesBannerAd() throws {
        // viewModel 構築は HomeViewTests / RecordViewModelTests のヘルパーに準拠
        let view = RecordView(viewModel: makeRecordViewModel())
        XCTAssertNoThrow(try view.inspect().find(BannerAdView.self))
    }

    // makeRecordViewModel() のヘルパー実装は RecordViewModelTests の setUp を参考に作成
}
```

ViewInspector で `BannerAdView` がビュー階層に存在することを確認する単一テスト。Ad のロード成功までは検証しない（外部依存）。

`makeRecordViewModel()` ヘルパーは `RecordViewModelTests` で使われている mock 構築パターン（`MockChildRepository` 等）を流用する。

### 5. やらないこと

- TaskManagementView のバナー削除
- 親レビュー画面（HelpHistoryView / MonthlyHistoryView）への追加 → Approach C は本 PR のスコープ外
- AdMob リクエスト設定の変更
- Interstitial / Rewarded 等の追加フォーマット導入

## テスト計画

- **手動 (DEBUG)**: simulator で RecordView を開き、scroll で最下部まで移動し、test ad（“Test Ad” ラベル付き）が表示されることを確認
- **手動 (RELEASE)**: TestFlight ビルドで実機検証
- **自動**:
  - 上記 `testRecordViewIncludesBannerAd` の追加
  - 既存 `RecordViewTests` スイート全件 green を維持
- **post-release**: AdMob console で merge 後 **1 週間** の impressions delta を観測

## ロールアウト

- ブランチ: `feat/issue-49-recordview-banner`
- 単一 PR、`Closes #49`
- merge 後 1 週間 impressions を観測し、想定より伸びない場合は follow-up issue で Option 1（固定下部）への移行を検討

## リスクと緩和

| リスク | 緩和策 |
| --- | --- |
| Scroll 行動依存で impressions が伸びない | 1 週間モニタ → Option 1 への移行を follow-up issue 化 |
| Ad 読み込み中の layout shift | `frame(height: 50)` で高さ固定済み → shift なし |
| Scroll 末端で子供が誤タップ | recordButtonView の直後 + `.padding(.top, 16)` で物理距離確保 |
| Ad fill rate が低く空白になる | AdMob 標準動作で透明表示、許容範囲 |
| `RecordViewTests` が banner 検出で flake | ViewInspector の `find(BannerAdView.self)` は依存少、flake リスク低い |

## 関連ファイル

- `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` — BannerAdView 追加
- `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` — **新規作成**（View 単位テスト、現状未整備）
- `app/OtetsudaiCoin/Presentation/Components/BannerAdView.swift` — 既存、変更なし
- `app/OtetsudaiCoin/AppDelegate.swift` — 既存 AdMob 初期化、変更なし

## 関連 PR / Issue

- #10 — BannerAdView 初回導入（実態は TaskManagementView）
- #21 — AdMob 本番 ID / 環境別 ID 管理
- #22 — Non-personalized 広告（npa=1）対応
- #49 — 本 issue
