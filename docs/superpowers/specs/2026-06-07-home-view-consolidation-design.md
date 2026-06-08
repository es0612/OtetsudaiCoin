# ホームビュー構成の整理 — 設計ドキュメント (#57)

- Issue: #57 「ホームビューで似た履歴/インサイト系ビューが3つあり整理したい」
- 作成日: 2026-06-07
- ステータス: 設計合意済み（brainstorming）→ writing-plans へ

## 1. 背景と問題

トップ（ホームタブ）に「子どもの頑張り・コイン・支払い」を扱う画面が断片化している。

- **ホーム統計カード**（`HomeView.childStatsView`、`HomeView.swift:172-214`）: 今月の実績 / 連続記録 / 今月のコイン / 今月のお手伝い の4枚グリッド。
- 子どもの名前の横に**ラベルなしの小さな SF Symbol アイコンが3つ**（`HomeView.swift:139-167`）並び、それぞれ別ビューを開く:
  - 📋 `list.clipboard` → `HelpHistoryView`（お手伝い履歴 / レコード単位リスト・編集削除）
  - 📅 `calendar.badge.clock` → `MonthlyHistoryView`（月別履歴 / 月ごとの合計・支払い、sheet）
  - ✨ `sparkles` → `MonthlyRetrospectiveView`（月の振り返り / 単月ビジュアル、sheet）

「回数 / コイン / 支払い」の情報がホーム統計＋3ビューに重複して登場し、入口も無地アイコンで分かりにくい。

## 2. ゴールと非ゴール

**主目的（ユーザー確定）**: 重複を減らして統合する（情報設計の整理）。

ゴール:
- 重複する「回数 / コイン / 支払い」表示を集約し、見る画面を減らす。
- 入口のごちゃつき（無地アイコン3つ）を、明確なラベル付き導線へ。
- ユーザーが気に入っている `RecordCalendarView`（単月＋月ナビ・緑ドット・クリーン）の見せ方を踏襲する。

非ゴール:
- 3つの**ジョブ自体は全部活かす**（支払い・振り返りビジュアル・1件編集削除 のいずれも価値あり、と確認済み）。機能削除はしない。
- アプリアイコン / スプラッシュのデザイン刷新（#18 / #16、別 issue）。
- 多通貨対応・英語ストア（#50 系、別 issue）。

## 3. 採用アプローチ — B: 見る/操作で2分割（3ビュー→2ビュー）

月単位で最も重複する **月別履歴 + 月の振り返り** を 1 つの『月のまとめ』へ統合し、性格の異なる **お手伝い履歴**（1件編集削除＝操作的 CRUD）は別ビューとして残す。ホーム統計はスリム化する。

検討した代替案:
- **A. 統合ハブ（3→1）**: 1入口の中をセグメント切替。重複は最小だが1画面が肥大化し、「祝う体験」と「編集操作」が同居して雑多。不採用。
- **C. ナビ整理のみ（3維持）**: アイコンをラベル化するだけ。主目的「統合」を満たさない。不採用。

## 4. 詳細設計

### 4.1 新しいホームタブ（エントリ構造）

`HomeView.childStatsView` を次のように変更:

- **統計カード: 4枚グリッド → 1行2項目に圧縮**。残すのは「今月のコイン」と「連続記録（日数）」。残り（実績回数 / お手伝い回数）は月のまとめへ集約。
  - 補足: 現状の「今月の実績」（`HomeView.swift:182`）と「今月のお手伝い」（同 `:209`）は**どちらも `viewModel.totalRecordsThisMonth` を表示しており、同じ値の二重表示**になっている。圧縮はこの重複解消も兼ねる。
- **無地アイコン3つ → ラベル付き導線2つ**:
  - `📊 月のまとめ ›`（新統合ビュー `MonthlySummaryView` へ）
  - `📋 お手伝い履歴 ›`（既存 `HelpHistoryView` へ）
- **支払い**: ホームの「今月のお小遣いを支払う」CTA（`HomeView.swift:216-291`）は撤去し、月のまとめへ集約。ホームには**未払い警告バナー**（`unpaidWarningBanner`）のみ残し、タップで該当月の月のまとめへ遷移させる。
- 子ども選択（`childrenListView`）はそのまま維持。

### 4.2 月のまとめ — `MonthlySummaryView`（統合の中心）

`MonthlyRetrospectiveView`（ビジュアル）を土台に、`MonthlyHistoryView` の「支払い」を取り込み、**単月＋月ナビ ‹ ›** 構成にする（旧月別履歴の「全月リスト」を月ナビでの行き来に置換）。

セクション構成（上から）:
1. **月ナビヘッダー** `‹ 2026年5月 ›` — `RecordCalendarView.header` と同じ操作感。未来月は `›` を無効化（`canGoNextMonth`）。
2. **ヒーローサマリ** — 回数 / 獲得コイン（旧 Retrospective `heroSection`）。
3. **ハイライトバッジ** — 連続 / 頑張った日 / ベスト（旧 Retrospective `highlightBadges`）。
4. **記録カレンダー** — 当月の記録がある日を緑ドット表示。`RecordCalendarView` を表示専用構成で再利用する（既存 `monthCalendarHeatmap` は置換）。
5. **お手伝い内訳チャート** — 旧 Retrospective `taskBreakdownChart`。
6. **支払いステータス + CTA** — 当月の支払い済み/未払い表示と「この月のお小遣いを支払う」（旧 MonthlyHistory の支払い導線）。過去月へナビすれば過去の未払い月もここで支払える。

これにより「全月一覧 + 各月の支払い」（旧月別履歴）は **月ナビ + 未払い警告バナー**で代替される。

### 4.3 お手伝い履歴 — `HelpHistoryView`（据え置き）

機能は現状維持（期間/子どもフィルタ、レコード一覧、編集/削除）。変更は**入口の明確化のみ**（ホームのラベル付き導線から遷移）。

### 4.4 支払いの集約

支払い操作は `MonthlySummaryView` に一本化。ホームは「気づき」のための未払い警告のみ。これにより現状3か所（ホーム / 月別 / 振り返り）に散っていた支払い導線が1か所になる。

## 5. コンポーネント / アーキテクチャ

- **新 ViewModel: `MonthlySummaryViewModel`**（既存 `MonthlyRetrospectiveViewModel` を発展）。責務:
  - `displayedMonth` 状態 + `goToPrevMonth()` / `goToNextMonth()` / `canGoNextMonth`（未来月ガード）。
  - 当月スナップショット（回数/コイン/ハイライト/内訳）= 既存 `RetrospectiveHighlightService` を流用。
  - `recordedDays`（カレンダー用）。
  - 支払い状態 + `payMonth()` = 既存 `AllowancePaymentRepository` を流用（旧 `MonthlyHistoryViewModel` の支払いロジックを移植）。
- **新 View: `MonthlySummaryView`**（`Presentation/Views/`）。`MonthlyRetrospectiveView` を発展させ、月ナビヘッダーと支払いセクションを追加。
- **カレンダー**: `RecordCalendarView`（`Presentation/Components/`）を表示専用（`onSelectDay` を no-op、未来日 disabled の既存挙動）で再利用。月ナビは View 上部のヘッダーに集約し、カレンダーは当該月を描画。
- **`reload trigger` は data-lifecycle の入口に集約**（CLAUDE.md「NotificationManager 発火と error message の干渉」/ #73）。月ナビ切替・支払い後の再ロードは `loadMonth` 末尾 / `displayedMonth` の `onChange` に置き、write 内で直接 reload しない。
- Xcode は `PBXFileSystemSynchronizedRootGroup` 採用のため、新規 `.swift` は所定ディレクトリに置くだけで認識（`project.pbxproj` 編集不要）。

## 6. テスト戦略

ViewInspector は NavigationStack + Material + `Image(systemName:)`（AccessibilityImageLabel blocker）+ iOS26 回帰で structural lookup に制約があるため、以下で多層に担保（CLAUDE.md「SwiftUI View テスト戦略」準拠）:

- **`MonthlySummaryViewModelTests`（ロジック網羅）**:
  - 月ナビ: prev/next で `displayedMonth` が前後し、未来月で `canGoNextMonth == false`。
  - **年境界ナビ（Dec→Jan / Jan→Dec）を必ず1件**（CLAUDE.md の date-math 反復弱点 #112/#114/#115 への予防線）。fixture は実行日非依存にするため当月内固定日（day 15）にピン留め。
  - 月ごとのスナップショット（回数/コイン/ハイライト）が当月の記録に一致。
  - `payMonth()` で当月の支払い状態が未払い→支払い済みへ遷移。
- **コンポーネントテスト**: `RecordCalendarView` の既存テストを流用（緑ドット = `findAll(ViewType.Shape.self)` + `fillShapeStyle` で `AccessibilityColors.successGreen` 定数比較、iOS26 #84/#118 準拠）。新規バッジ/ヒーローの表示文字列は `findAll(ViewType.Text.self)` で blocker 跨ぎ（#106）。未実証 traversal に依存する assertion は観測値を message に dump（#106）。
- **スモークテスト**: `MonthlySummaryView` / 改修後 `HomeView` の init crash なし。
- **i18n**: 新規ラベル（"月のまとめ" 等）を `.xcstrings` に追加（[[xcstrings-bulk-update]]）。

## 7. 移行 / 互換性（旧ビューの扱い）

- `MonthlyRetrospectiveView` / `MonthlyRetrospectiveViewModel` → `MonthlySummaryView` / `MonthlySummaryViewModel` へ発展（リネーム + 機能追加）。
- `MonthlyHistoryView` / `MonthlyHistoryViewModel` → 支払いロジックを `MonthlySummaryViewModel` へ移植後、**削除**。削除に伴い `HomeView` 内の sheet・呼び出し（`showingMonthlyHistory`、`prepareMonthlyHistoryViewModel`）を撤去。
- **削除系の verification**: 削除したシンボル/ラベルを app・Tests・UITests の3ターゲットで grep（CLAUDE.md「UI 要素を削除したら app と test の両ターゲットを grep」/ #92）。`ASCScreenshotUITests` 等がラベル参照していないか確認。
- `HelpHistoryView` は変更なし。

## 8. スコープ外

- アプリアイコン / スプラッシュ刷新（#18 / #16）。
- 多通貨対応・英語ストア掲載（#50 系）。
- ホームの未払い警告バナーのロジック自体の変更（遷移先のみ月のまとめへ差し替え）。

## 9. 確定した設計判断（decisions log）

| 項目 | 決定 |
|---|---|
| アプローチ | B: 3→2（月別+振り返り→月のまとめ、履歴は別） |
| 月のまとめ構造 | 単月 + 月ナビ ‹ ›（全月リストは置換） |
| ホーム統計 | 4枚 → 1行2項目（今月コイン + 連続記録） |
| 支払い配置 | 月のまとめへ集約、ホームは未払い警告のみ |
