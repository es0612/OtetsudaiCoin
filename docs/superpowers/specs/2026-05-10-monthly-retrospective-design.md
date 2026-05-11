# 月の振り返り画面 — 設計書

**対象 Issue**: #19「その月の頑張りを子供と見返したいがいい感じに振り返られる画面がない」

**作成日**: 2026-05-10

## 1. 背景

既存の `MonthlyHistoryView` は月単位の集計を表示するが、UI はリストベースで utilitarian、子供と一緒に見返して達成感を共有できる体験になっていない（タスク名すら placeholder の「お手伝い」表記）。

ユーザー（保護者）は **月末・月初の「認めるタイミング」** に、子供と一緒に「今月もこんなに頑張ったね」と話しながら、お小遣いを渡す導線で使いたい。既存画面では満たせないこの体験ニーズを、新規の振り返り画面で実現する。

## 2. 機能要件

### 2.1 起点と画面遷移

| 項目 | 仕様 |
|---|---|
| エントリポイント | `HomeView` に「📅 今月の振り返り」ボタンを追加、タップで画面をモーダル表示 |
| 表示形式 | `.sheet` モーダル、内部に `NavigationStack`、左上「閉じる」ボタン |
| 月の範囲 | 今月をデフォルト、左右スワイプで過去 12 ヶ月まで遷移、未来月は不可 |

### 2.2 含める要素（縦スクロール順）

1. **月ヒーロー**: 月名 / 子供名 / 「N 回 ¥N,NNN」の大きな数字
2. **ハイライトバッジ**: 3 種類を自動算出
   - 🔥 月内の最大連続記録日数
   - 🌟 一番頑張った日（HelpRecord 件数最多日、同数なら最新）
   - 🏆 一番やったお手伝い種別（HelpTask 件数最多、同数なら最新）
3. **内訳チャート**: HelpTask 別件数を横棒で表示
4. **月内カレンダー**: 7 列グリッドで日別ヒートマップ（記録ありの日が濃く色づく）
5. **支払い CTA**: 選択月が未払いのときのみ「お小遣いを渡す」ボタン表示、押下で既存の `payAllowance` フローへ

### 2.3 含めない要素（YAGNI）

- 個別 HelpRecord の詳細リスト（既存 `MonthlyHistoryView` で代替）
- AI 生成のひと言コメント（テンプレ文字列で十分）
- 先月との比較表示（後付けで追加可能）
- 共有・SNS 投稿
- 写真・サムネイル

### 2.4 エッジケース

| 状態 | 挙動 |
|---|---|
| 記録 0 件の月 | 「0 回」、バッジは「まだお手伝いなし」プレースホルダ、CTA 非表示 |
| 記録 1 件のみ | streak=1、その日が topDay、そのタスクが topTask |
| 子供が未登録 | HomeView の振り返りボタンを disabled |
| 12 ヶ月より前にスワイプ | 反応なし（境界停止） |
| 未来月にスワイプ | 反応なし（境界停止） |

## 3. アーキテクチャ

### 3.1 新規ファイル

| ファイル | 責務 |
|---|---|
| `app/OtetsudaiCoin/Presentation/Views/MonthlyRetrospectiveView.swift` | 振り返り画面の主体 View |
| `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift` | 月選択・データロード・スナップショット保持 |
| `app/OtetsudaiCoin/Domain/Services/RetrospectiveHighlightService.swift` | 純関数のハイライト算出ロジック |
| `app/OtetsudaiCoinTests/Domain/Services/RetrospectiveHighlightServiceTests.swift` | バッジ算出の単体テスト |
| `app/OtetsudaiCoinTests/Presentation/MonthlyRetrospectiveViewModelTests.swift` | ViewModel テスト |

### 3.2 修正ファイル

| ファイル | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Presentation/Views/HomeView.swift` | 「📅 今月の振り返り」ボタンを追加、タップで `MonthlyRetrospectiveView` をモーダル起動 |

### 3.3 変更しないファイル

- `MonthlyHistoryView` / `MonthlyHistoryViewModel` — 用途が違うので温存
- `MonthlyRecord` — 既存型を流用
- `AllowanceCalculator`、`UnpaidAllowanceDetectorService` — そのまま依存

### 3.4 依存グラフ

```text
MonthlyRetrospectiveView
   └─ @Bindable MonthlyRetrospectiveViewModel
        ├─ ChildRepository (現在選択中の子供)
        ├─ HelpRecordRepository.findByChildId
        ├─ HelpTaskRepository.findAll (タスク名解決)
        ├─ AllowancePaymentRepository.findByChildId
        ├─ AllowanceCalculator (月額計算、既存)
        ├─ UnpaidAllowanceDetectorService (未払い判定、既存)
        └─ RetrospectiveHighlightService (新規、純関数)
```

## 4. データフロー

```text
[ユーザー操作]
   ┌─ 初期表示 (Home から起動): selectedMonth = 今月
   ├─ 左スワイプ: selectedMonth = .month - 1 (過去 12 ヶ月まで)
   └─ 右スワイプ: selectedMonth = .month + 1 (今月が上限、未来不可)
                       │
                       ▼
        ViewModel.loadMonth(selectedMonth)
                       │
   ┌───────────────────┼─────────────────────┐
   ▼                   ▼                     ▼
findByChildId    findAll (tasks)    findByChildIdAndMonth
（選択月で       （タスク名解決用     （AllowancePayment）
 フィルタ）      辞書を作成）
                       │
                       ▼
   AllowanceCalculator.calculateMonthlyAllowance(records, tasks)
   UnpaidAllowanceDetectorService.detectUnpaidPeriods(...)
   RetrospectiveHighlightService.compute(records, tasks)
                       │
                       ▼
        viewModel.snapshot = MonthSnapshot(...)
```

### 4.1 `MonthSnapshot` の構造

```swift
struct MonthSnapshot: Equatable {
    let monthLabel: String        // "2026年5月"
    let totalCount: Int           // 23
    let totalCoins: Int           // 1150
    let taskBreakdown: [(name: String, count: Int, coinTotal: Int)]
    let highlights: Highlights
    let calendar: [DailyActivity] // 月の各日の活動
    let paymentStatus: PaymentStatus  // .paid | .unpaid | .partiallyPaid
}

struct DailyActivity: Equatable {
    let day: Int
    let count: Int
}

enum PaymentStatus { case paid, unpaid, partiallyPaid }
```

### 4.2 `RetrospectiveHighlightService` の API

```swift
struct Highlights: Equatable {
    let consecutiveDayStreak: Int            // 月内の最大連続日数
    let topDay: (date: Date, count: Int)?    // 件数最多日
    let topTaskName: String?                 // 件数最多タスク名
}

class RetrospectiveHighlightService {
    func compute(records: [HelpRecord], tasks: [HelpTask]) -> Highlights {
        // 1. records が空なら全 nil/0 を返す
        // 2. records を日付グルーピング → 連続日数・最多日を算出
        // 3. records.helpTaskId → tasks.name に解決して最頻タスク
    }
}
```

### 4.3 連続日数の定義

「**月内の最大連続記録日数**」と定義：

- 例: 5 月に「1, 2, 3, 5, 6, 7, 8 日」に記録 → 最大連続 = 4 日（5-8 日）
- 月をまたぐ連続（4 月末 + 5 月初）は **カウントしない**（月内に閉じた指標）

これは「月の振り返り」体験を素直に表現するためのデザイン判断。

## 5. UI 詳細

### 5.1 画面構造（縦スクロール）

```text
NavigationStack
└─ ScrollView
   ├─ MonthHeader        ← 月名タイトル + 子供名 + ‹ ›（前後月）
   ├─ HeroSection        ← 大きな数字「23 回 / ¥1,150」
   ├─ HighlightBadges    ← 3 つのバッジカード横並び
   ├─ TaskBreakdownChart ← タスク別件数の横棒
   ├─ MonthCalendar      ← 7 列グリッド、件数で色濃淡
   └─ PaymentCTA         ← 未払い時のみ表示
```

### 5.2 スワイプジェスチャ

```swift
.gesture(
    DragGesture(minimumDistance: 50)
        .onEnded { value in
            if value.translation.width < -50 {
                viewModel.goToPreviousMonth()
            } else if value.translation.width > 50 {
                viewModel.goToNextMonth()
            }
        }
)
.animation(.easeInOut, value: viewModel.selectedMonth)
```

### 5.3 Design System の活用

- 数字: `.appFont(.appTitle)` で大きく
- セクション見出し: `.appFont(.sectionHeader)`
- カラー: `AccessibilityColors.primaryBlue / successGreen / warningOrange`
- バッジ背景: 子供のテーマカラーを subtle にグラデーション
- 支払い CTA: `primaryGradientButton()` を流用
- アクセシビリティ: 各セクションに `accessibilityLabel`、CTA に `accessibilityIdentifier("retrospective_payment_cta")`

## 6. テスト戦略

### 6.1 Service 単体（純関数で網羅的に）

`RetrospectiveHighlightServiceTests`:

| テスト | 検証内容 |
|---|---|
| `testEmptyRecordsReturnsAllZero` | 空 → streak=0, topDay=nil, topTaskName=nil |
| `testSingleRecord` | 1 件 → streak=1, その日が topDay |
| `testConsecutiveStreak` | 1,2,3,5,6,7,8 → streak=4 |
| `testTopDayWithTie` | 同件数なら最新を返す |
| `testTopTaskName` | task 件数最多のタスク名解決 |
| `testTopTaskNameWithTie` | 同件数なら最新を返す |
| `testIgnoresAcrossMonthBoundary` | 月またぎは連続にカウントしない |

### 6.2 ViewModel 単体

`MonthlyRetrospectiveViewModelTests`:

| テスト | 検証内容 |
|---|---|
| `testInitialMonthIsCurrentMonth` | 起動時 selectedMonth = 今月 |
| `testGoToPreviousMonthDecrements` | スワイプで前月に |
| `testCannotGoBeyondTwelveMonthsAgo` | 12 ヶ月超は移動しない |
| `testCannotGoToFutureMonth` | 未来月へは移動しない |
| `testLoadMonthPopulatesSnapshot` | データロードで snapshot が埋まる |
| `testPaymentStatusReflectsAllowancePayment` | 支払い済みなら CTA 非表示 |

### 6.3 View 軽量テスト

ViewInspector で：

- HeroSection に合計回数・コイン額が含まれる
- 未払い時に PaymentCTA が表示
- 支払い済み時に PaymentCTA 非表示

### 6.4 手動確認項目

- 過去月へのスワイプ実機操作
- ヒートマップの濃淡が件数を反映
- ダークモード対応
- VoiceOver 動作

## 7. リリース観点

- **互換性**: 既存スキーマ変更なし、データマイグレーション不要
- **回帰リスク**: HomeView にボタンを 1 つ追加するのみ、既存挙動に影響しない
- **ロールバック**: revert 容易（追加のみ）
