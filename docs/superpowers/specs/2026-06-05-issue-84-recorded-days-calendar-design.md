# Issue #84: 記録登録時に「記録がある日」をカレンダーで可視化

- Issue: [#84](https://github.com/es0612/OtetsudaiCoin/issues/84) お手伝い登録時にすでに記録がある日が見たい。記録漏れや二重登録に事前に気づける
- 作成日: 2026-06-05
- ステータス: 設計確定（ユーザーレビュー待ち）

## 背景

記録画面（`RecordView`, tab 1）の「記録日」は現在 `.compact` スタイルの `DatePicker` で、**どの日に記録があるかは日付を選んでみないと分からない**。そのため:

- **記録漏れ**: つけ忘れた日（前後に記録があるのに空いている日）に気づきにくい。
- **二重登録**: その日に既に記録済みかどうかは、日を選んでタスクカードのバッジ（#73）を見るまで分からない。

ユーザーは「登録の前に、月全体を俯瞰して記録の有無を見たい」と要望している。

### #73 との違い（既実装の確認済み）

`git log --since=<#84 createdAt> -- RecordView/RecordViewModel` および `-S loadExistingCountsForCurrentDateAndChild` で既存実装を検証した結果、**#84 は #73 と補完関係にある別機能**であることを確認した。

| | #73（実装済み） | #84（本 issue） |
|---|---|---|
| 何を見せる | 選択中の「その日」の各タスク既存記録**件数** | 「どの日」に記録があるか（月全体） |
| どこに出る | `TaskCardView` のバッジ（`existingCount`） | 日付選択（カレンダー）のレベル |
| いつ気づく | 日を選んだ**後** | 日を選ぶ**前**に俯瞰して |
| 防ぐ | 同じ日・同タスクの二重登録 | 記録**漏れ** ＋ 二重登録 |

データ層（`helpRecordRepository.findByDateRange(from:to:)`）と per-child 件数集約の前例は #73 で既にあり、再利用できる。

## 製品判断（確定）

ブレストのビジュアル比較（`.superpowers/brainstorm/` のモックアップ）で以下を確定:

| 軸 | 結論 |
|---|---|
| 可視化方式 | **Option A: インライン月カレンダー**（`.compact` DatePicker を置換） |
| マーカー | **ドット**（記録の「有無」のみ。件数は出さない。データは `Set<日>`） |
| レイアウト | **インライン常時表示**（タップ不要で俯瞰が目に入る＝「事前に気づく」に最も忠実。画面高 +約160pt は許容） |
| マーク対象 | **選択中の子ども 1 人分**の記録（#73 の per-child と一貫） |
| 未来日 | **選択不可**（既存 `in: ...Date()` を踏襲、今日まで） |
| 月移動 | **過去方向のみ**（記録漏れ補完のため）。今日を含む月より先へは進めない |

### なぜ標準 `DatePicker(.graphical)` を使わないか

SwiftUI 標準の `DatePicker(.graphical)` は各日へドット等の装飾を付ける API を持たない。マーカー表示には**カスタムの月グリッド**が必須。幸い既存 `MonthlyRetrospectiveView.monthCalendarHeatmap`（7 列 `LazyVGrid` の月ヒートマップ）と同じパターンで描けるため、ゼロからの発明にはならない。

## スコープ外（本 issue では着手しない）

- 既存 `monthCalendarHeatmap`（`MonthlyRetrospectiveView`）の共通コンポーネント化リファクタ。`MonthlyRetrospectiveView` に触れると #84 のスコープを越える。**パターンを真似るのみ**。統合に価値があれば別 issue を立てる（out-of-scope-finding ルール）。
- 家族全員（複数子ども）の記録を 1 カレンダーに重畳する俯瞰ビュー。
- 件数バッジ表示（ドットで確定）。
- 記録済み日タップ時の追加警告ダイアログ（per-task の二重登録警告は #73 の `TaskCardView` バッジで担保済み）。

## 設計

### コンポーネント

新規プレゼンテーショナル・コンポーネントを `Presentation/Components/` に切り出す（`RecordButtonBar` / `TaskCardView` / `ChildCardView` の前例に揃える）。ViewModel から状態を受け取り、操作はクロージャで上げる純表示コンポーネントにすることで **ViewInspector の NavigationStack+ScrollView+BannerAdView traversal 制約**（#74/#106）を回避し、コンポーネント単独でテスト可能にする。

```
RecordCalendarView  (Presentation/Components/RecordCalendarView.swift)
  入力:
    displayedMonth: Date          // 表示中の月のアンカー（月初）
    selectedDate: Date            // 選択中の記録日（recordedDate）
    recordedDays: Set<Int>        // displayedMonth 内で記録がある日(d)の集合（選択中の子ども分）
    today: Date                   // 未来日判定の基準（テスト注入のため引数化）
    canGoNextMonth: Bool          // 今日を含む月より先へ進めるか（常に false 想定だが計算は ViewModel）
  操作（クロージャ）:
    onSelectDay: (Int) -> Void    // 日タップ → その日を recordedDate に
    onPrevMonth: () -> Void
    onNextMonth: () -> Void
```

- ヘッダー: `‹  2026年 6月  ›`（`onPrevMonth`/`onNextMonth`。`canGoNextMonth == false` のとき `›` を disabled 表示）。
- グリッド: 7 列 `LazyVGrid`。曜日ヘッダー（日〜土）＋ 月初の曜日オフセット分の空セル ＋ 各日セル。
- 日セル: 日番号 ＋ `recordedDays.contains(d)` なら緑ドット。`selectedDate` の日なら塗り丸ハイライト。未来日（`displayedMonth` が今日の月かつ `d > 今日の日`）は淡色＋タップ無効。
- ヘッダー下に小キャプション `記録日: M月D日` を表示（月をナビゲートして選択日が画面外でも、記録対象日を常に明示し誤記録を防ぐ）。

`RecordView.dateSection` の `DatePicker` を本コンポーネントに置換する。

### ViewModel（`RecordViewModel`）の追加状態とロジック

ロジックはすべて ViewModel 側に置き unit-test 可能にする（コンポーネントは表示のみ）。

```swift
// 追加状態
var displayedMonth: Date = Self.startOfMonth(Date())   // 月初アンカー
var recordedDays: Set<Int> = []                        // displayedMonth 内・選択中の子の記録がある日

// 追加メソッド
func loadRecordedDaysForDisplayedMonth()   // displayedMonth と selectedChild から Set<Int> を算出
func goToPreviousMonth()                    // displayedMonth を 1 ヶ月戻す → 再ロード
func goToNextMonth()                        // 今日の月まで・それ以上は no-op → 再ロード
func canGoToNextMonth() -> Bool             // displayedMonth < 今日の月 のとき true
func selectDay(_ day: Int)                  // displayedMonth の day を recordedDate に（noon 正規化、未来日は無視）
```

- `loadRecordedDaysForDisplayedMonth()` は `helpRecordRepository.findByDateRange(from: 月初, to: 月末)` を引き、`childId == selectedChild` で filter、`Calendar.current.component(.day, from: recordedAt)` で日番号へ写像して `Set<Int>` を作る。`selectedChild == nil` のときは空集合。既存 `loadExistingCountsForCurrentDateAndChild()` と同じ非同期 + `loadCountsTask` 相当のキャンセル方式に揃える（専用 `Task` ハンドルを別に持つ）。
- 既存 `existingRecordCounts`（per-task 件数）とは**別の集約**（per-day 有無）。混ぜない。
- `selectDay` は `normalizeToNoon` を使い `recordedDate` を更新。これにより既存 `dateSection` の `onChange(recordedDate)` 経路で per-task `existingRecordCounts` も連動更新される。

### データフロー（reload trigger の集約 — #73 学び）

`recordedDays` の再ロードは **data-lifecycle の入口にのみ**置く。`recordHelp` / `recordBulkHelp` の中では絶対に呼ばない（`setLoading(true)` が `errorMessage` をクリアする副作用の罠を回避）。

| トリガ | 理由 |
|---|---|
| `loadData()` 末尾 | 初期ロード／`notifyHelpRecordUpdated` observer 経由の再取得時。既存 `loadExistingCountsForCurrentDateAndChild()` の直後に `loadRecordedDaysForDisplayedMonth()` を追加 |
| `selectChild()` 末尾 | 子ども切替で対象記録が変わる（既存 count reload と同じ場所） |
| `displayedMonth` 変更（`goToPreviousMonth`/`goToNextMonth` 内） | 表示月が変わったら当月分を引き直す |
| `notifyHelpRecordUpdated` observer | 記録保存後の反映。observer は既に `loadData()` を呼ぶので、↑の `loadData` 末尾追加で自動的にカバー（新規 dot が出る） |

→ 記録直後に新しい日へドットが付くのは `recordHelp`→`notifyHelpRecordUpdated()`→observer→`loadData()`→`loadRecordedDaysForDisplayedMonth()` の既存 data-lifecycle 経路で実現。write 操作内で直接 reload しない。

### 月移動と選択日の関係

- `displayedMonth` はナビゲーション状態、`recordedDate`（=selectedDate）は選択状態で独立。
- 過去月へナビゲートしても `recordedDate` は変わらない。選択丸ハイライトは `recordedDate` がその月にあるときだけ表示。
- ヘッダー下キャプション `記録日: M月D日` で記録対象を常に明示し、月を移動して選択日が画面外でも誤記録を防ぐ。
- 記録ボタンは従来どおり `recordedDate` を対象に保存。

### エラー処理

`loadRecordedDaysForDisplayedMonth()` の取得失敗は **無視**（`recordedDays` を据え置き、`errorMessage` を上書きしない）。既存 `loadExistingCountsForCurrentDateAndChild()` の `catch` 方針（UX 影響低・既存エラーを潰さない）に一致させる。

### アクセシビリティ

標準 DatePicker の VoiceOver を失うため、各日セルに明示ラベルを付ける:

- `accessibilityLabel`: `"6月3日"`（＋ 状態 `"記録あり"` / `"記録なし"`、選択中なら `"選択中"`、未来日なら `"選択できません"`）。
- 月移動 `‹ ›` ボタンにもラベル（`"前の月"` / `"次の月"`）。
- 色（緑ドット）は `AccessibilityColors` を使用し、有無は色だけでなくラベルでも伝える。

### i18n

新規文字列はすべて `String(localized:)` 経由。対象: 月ラベル（`DateFormatter` の locale 連動 or `String(localized:)`）、曜日ヘッダー、`記録日: …` キャプション、アクセシビリティラベル、前/次の月ボタン。`%lld` 系の件数文字列は本機能では不要（ドットのみ）。

## テスト戦略

ViewInspector の制約（RecordView 本体は NavigationStack+ScrollView+BannerAdView で深く traverse 不可）を踏まえ、以下で担保:

1. **ViewModel unit test**（ロジックの中核）
   - `recordedDays` 算出: 指定月に複数子の記録がある状態で、選択中の子の記録日のみが日番号集合に入る（他child除外）。
   - 月境界: 月初/月末の記録が正しく当月集合に入る／隣月の記録が混入しない（#112 の日付境界 flake 学びに留意し `today` を注入してテスト決定的に）。
   - `canGoToNextMonth()`: 今日の月で false、過去月で true。
   - `goToPreviousMonth`/`goToNextMonth` が `displayedMonth` を正しく移動し、next は今日の月で頭打ち。
   - `selectDay(d)` が `recordedDate` を noon 正規化で更新し、未来日は無視。
   - reload trigger: `selectChild` 後に `recordedDays` が対象児童分へ更新される。
2. **コンポーネント behavior test**（`RecordCalendarView` 単独）
   - 日タップで `onSelectDay` が正しい日で呼ばれる。
   - `canGoNextMonth == false` で `›` が disabled（`find(ViewType.Button.self)` 経由で state 確認。`AccessibilityImageLabel` blocker 回避のため identifier 依存にしない）。
   - `recordedDays` に含まれる日にマーカー要素が描画される（`findAll(ViewType.Text.self)` で blocker を跨いで観測、assertion message に観測値を dump して未検証 traversal を可視化＝#106 学び）。
3. RecordView 本体の構造テストは**書かない**。最終 visual は simulator 手動 / 既存 ASC スクショ系で確認。

## 受け入れ条件

- [ ] 記録画面の「記録日」がインライン月カレンダーになっている。
- [ ] 選択中の子どもの記録がある日に緑ドットが表示される（他の子の記録は出ない）。
- [ ] 今日より未来の日は淡色で選択できない。
- [ ] `‹` で過去月へ移動でき、`›` は今日を含む月で無効。
- [ ] 日をタップするとその日が記録日（青丸ハイライト）になり、記録ボタンでその日に保存される。
- [ ] 記録直後、保存した日へドットが付く（observer→loadData 経路）。
- [ ] 各日セル・月移動ボタンにアクセシビリティラベルがある。
- [ ] ViewModel テストとコンポーネント behavior テストが green。

## 関連

- Issue #73（PR で実装済み）— per-task 既存記録件数バッジ。本機能と補完関係。
- `MonthlyRetrospectiveView.monthCalendarHeatmap` — 月グリッドの既存パターン（真似る対象、改変しない）。
- CLAUDE.md「NotificationManager 発火と error message の干渉」/「reload trigger は data-lifecycle の入り口に集約」（#73）。
- CLAUDE.md「SwiftUI View テスト戦略」（#74/#106 のコンポーネント分離・blocker 回避）。
- CLAUDE.md「テスト日付境界バグ」（#112、`today` 注入で決定的に）。
- `superpowers:writing-plans` — 次工程（本 spec 承認後）。
