# お手伝い記録の一括登録 — 設計書

Issue: #69
作成日: 2026-05-19

## 背景

1 日の終わりにまとめて記録したいとき、ユーザーは現状 `RecordView` で「子選択 → タスク選択 → 記録する → タスク選択リセット」のサイクルを N 回繰り返す必要がある。Issue #69 では「複数選択して登録できると楽」という UX 改善要望が出ている。

`RecordView` は現状、単一の `selectedTask: HelpTask?` をもとに `recordHelp()` で `HelpRecord` を 1 件だけ保存する flow。複数件を 1 タップで登録する flow は存在しない。

## ターゲット利用者の前提

利用シーンは「1 日の終わりに保護者が `RecordView` を開いて、その日その子がやったお手伝いを 2〜5 件まとめて記録する」というケース。1 件のみの利用も既存と同じ頻度で残るため、**1 件モードと一括モードは両立** する必要がある。

複数の HelpTask を一気に「同一の Child / 同一の記録日」で記録する範囲を扱う。「跨日記録」「同 task を同日に N 回」「複数の Child にまたがる一括」はスコープ外。

## 方針判断

**採用: Approach A（`RecordView` に "一括モード" Toggle を追加）**

UX 入り口は 3 案を検討:

| 案 | 概要 | 採否 | 理由 |
|---|---|---|---|
| A | RecordView 内に Toggle で mode 切替、既存 `taskListView` を checkbox 風に流用 | ✅ 採用 | 画面遷移なし。child/date 選択を再利用できて実装最小。発見性も高い |
| B | 長押しで select mode 起動 | ❌ 不採用 | iOS 標準だが「一括できる」発見性が低い |
| C | 専用 `BulkRecordView` を別画面 push | ❌ 不採用 | child/date/task grid を全コピーする必要があり重複が多い |

部分失敗時のセマンティクスは:

- **採用: 成功した分は保持、失敗を個別表示** — 5 件中 4 件成功なら 4 件は DB に残り、`selectedTaskIds` には失敗 1 件だけが残ってリトライ可能。データ一貫性より UX (やり直しの自然さ) を優先。
- 不採用: All-or-nothing rollback — SwiftData transaction + コインアニメ cancel 処理が複雑化し、ユーザー体感メリットが薄い。

## 設計

### 1. アーキテクチャ

`RecordView` 1 画面で 1 件モード / 一括モードをトグル切替。既存 `RecordViewModel` を拡張し、新規 ViewModel は作らない。

- `RecordViewModel` に `isBulkMode: Bool` と `selectedTaskIds: Set<UUID>` を追加
- 既存 `selectedTask: HelpTask?` は 1 件モード用、一括モード時は未使用
- mode 切替 (toggle on/off) / Child 切替 / 一括記録完了 のタイミングで両方の選択を reset

理由: 一括/単発の state は同じ画面のローカル関心事であり、`RecordView` ↔ `RecordViewModel` の境界以上に切り出す必要がない。BulkRecordViewModel 新設は view 間 state 同期コストが上回るため不採用。

### 2. 主要コンポーネント

| 部位 | 変更内容 |
|---|---|
| `RecordView` の `navigationTitle` 横 (`toolbar`) | `Toggle("一括モード", isOn: $viewModel.isBulkMode)` を追加 |
| `taskListView` 内の `TaskCardView` | `isBulkMode` で見た目分岐: 左上角にチェックボックスアイコン、選択時の色変化を流用 |
| `recordButtonView` | label と enable 条件を mode 別に切替 (下表参照) |
| 一括モード時のみ表示するサマリ | `"選択中 N 件 / 計 M コイン"` を `recordButtonView` の上に表示 |

`recordButtonView` の mode 別仕様:

| mode | label | enable 条件 | 動作 |
|---|---|---|---|
| 1 件 | `"記録する"` | `selectedTask != nil && selectedChild != nil` | `recordHelp()` (既存) |
| 一括 | `"N 件をまとめて記録する"` | `!selectedTaskIds.isEmpty && selectedChild != nil` | `recordBulkHelp()` (新設) |

### 3. データフロー (一括記録)

```text
toggle "一括モード" → isBulkMode = true、既存 selectedTask は nil 化
↓
TaskCard tap → selectedTaskIds に insert / remove
↓
"N 件をまとめて記録する" tap → recordBulkHelp()
  for each id in selectedTaskIds:
    HelpRecord 生成 → repository.save()
    success なら id を successIds に
    failure なら id を failureIds に
  ↓
  selectedTaskIds = failureIds (= 失敗のみ残してリトライ自然導線)
  ↓
  successIds.count 件 success message
  + failureIds.count 件 error message (もしあれば)
  ↓
  コインアニメ (lastRecordedCoinValue = 成功した task の coinRate 合計)
```

### 4. エラーハンドリング

| シナリオ | 挙動 |
|---|---|
| 全成功 | `setSuccess("N 件記録しました")` + コインアニメ (合計値) |
| 部分失敗 | `setSuccess("N 件記録しました")` + warning 表示 `"M 件失敗、もう一度タップしてください"` / 失敗 task は `selectedTaskIds` に残る |
| 全失敗 | `setError("記録に失敗しました")` / 選択そのまま |
| 0 件選択時の record タップ | ボタン disabled で発火しない |

`successMessage` と `errorMessage` の両方を同時に表示するため、既存の単一メッセージ表示 (line 19〜31 of `RecordView.swift`) に warning row を 1 行追加する。

### 5. テスト方針 (TDD)

`RecordViewModel` と `RecordView` のテストファイルは現状 **どちらも未作成**。本対応で新規追加する。

`RecordViewModelTests.swift` (**新規作成**):

- `test_toggleBulkMode_resetsSelections` — mode 切替で `selectedTask` / `selectedTaskIds` が両方 reset
- `test_recordBulkHelp_全件成功` — 3 件選択 → 3 件保存 → success メッセージ
- `test_recordBulkHelp_部分失敗_失敗のみ残る` — 3 件中 1 件 mock で fail → 残 1 件が `selectedTaskIds` に
- `test_recordBulkHelp_全件失敗` — error メッセージ + 選択そのまま
- `test_selectChild_resetsBulkSelection` — child 切替で `selectedTaskIds` empty に
- `test_bulkMode_coinAnimation_lastRecordedCoinValue_は合計`

`RecordViewTests.swift` (**新規作成**): UI 構造テスト 2 件

- `test_recordView_has_bulkModeToggle` — toolbar 内に `Toggle("一括モード")` 存在
- `test_recordView_bulkMode_recordButton_label` — `isBulkMode = true && selectedTaskIds.count = 2` で button label が `"2 件をまとめて記録する"`

既存 mock pattern は `HelpRecordEditViewModelTests.swift` / `BannerAdViewTests.swift` を参照して合わせる。`HelpRecordRepository` の partial failure 模擬は `MockHelpRecordRepository` を拡張するか、既存 mock があれば再利用する (writing-plans で確定)。

### 6. 設計上の決定 (default 確定)

- **同タスク重複チェック**: なし (現状 single record flow と整合、DB 制約も無い)
- **Child 切替時**: `selectedTask` / `selectedTaskIds` 両方 reset
- **跨日記録**: 不可。`recordedDate` 1 つを全 record で共有 (現状 single と整合)
- **コインアニメ**: 一括時は合計値を表示 (`lastRecordedCoinValue = Σ coinRate`)

### 7. Localization

xcstrings に新規キーを追加し en/ja 両対応 (xcstrings-bulk-update skill 適用)。

| key | ja | en |
|---|---|---|
| `bulk_mode_toggle` | `一括モード` | `Bulk Mode` |
| `bulk_record_button_label` | `%lld 件をまとめて記録する` | `Record %lld items` |
| `bulk_summary` | `選択中 %lld 件 / 計 %lld コイン` | `%lld selected / %lld coins` |
| `bulk_success_message` | `%lld 件記録しました！` | `Recorded %lld items!` |
| `bulk_partial_warning` | `%lld 件失敗、もう一度タップしてください` | `%lld failed, tap to retry` |
| `bulk_all_failed_error` | `記録に失敗しました` | `Failed to record` |

## 影響範囲

| ファイル | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` | `isBulkMode`, `selectedTaskIds`, `recordBulkHelp()`, `toggleBulkMode()` 追加。`selectChild()` 拡張 |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | toolbar に Toggle 追加、TaskCard 表示分岐、`recordButtonView` ラベル分岐、サマリ表示 |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 新規キー 6 件 (`xcstrings-bulk-update` skill 適用) |
| `app/OtetsudaiCoinTests/Presentation/ViewModels/RecordViewModelTests.swift` | **新規作成**、テスト 6 件 |
| `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` | **新規作成**、UI 構造テスト 2 件 |

`PBXFileSystemSynchronizedRootGroup` 採用のため、新規 `.swift` ファイル (上記 2 件) はディレクトリに置くだけで Xcode が自動認識し、`project.pbxproj` 編集は不要。

## 検討して採用しなかった案

- **BulkRecordViewModel 新設**: state を view 別 instance に分けると `Child` / `recordedDate` 切替時に 2 ViewModel 間で同期が必要になる。1 画面の関心事は 1 ViewModel に閉じる方が SwiftUI の `@Observable` と相性が良い
- **All-or-nothing rollback**: 部分成功時の rollback 実装複雑度が高く、ユーザーは結局「どこまで保存されたか」が分かりにくい。成功分保持 + 失敗のみ残す方が体感が自然
- **同タスク重複ブロック (checkbox disable)**: 「同日に 2 回掃除した」という正当ケースまで block してしまう。重複チェックを入れるなら別 issue で UX を含めて再検討
- **専用 BulkRecordView 画面**: 既存 RecordView の child/date 選択をコピーする必要があり、UI 重複・テスト重複が膨らむ
