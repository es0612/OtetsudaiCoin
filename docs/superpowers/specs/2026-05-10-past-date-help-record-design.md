# 過去日付指定でのお手伝い登録 — 設計書

**対象 Issue**: #20「過去の日付を指定してお手伝い登録したい。お手伝い後にすぐ登録できるわけではない。」

**作成日**: 2026-05-10

## 1. 背景

現状、お手伝い記録画面（`RecordView`）はタップした瞬間（`Date()`）で `HelpRecord.recordedAt` を保存している。一方で編集画面（`HelpRecordEditView`）には既に DatePicker が存在し、編集経由で過去日付に変更可能。

ユーザー（保護者）の実態は「お手伝いが行われた瞬間にすぐ記録できるとは限らず、後でまとめて入力したい」というケースが頻繁にある。「記録 → すぐ編集して日付を変える」操作は手数が多くストレスフル。

→ **登録時点で日付を指定できる**機能を追加することで、保護者がお手伝いをまとめて記録するユースケースを直接支援する。

## 2. 機能要件

| 項目 | 仕様 |
|---|---|
| 日付ピッカー表示 | 常時表示（トグルや展開なし） |
| 粒度 | **日付のみ**（時刻は自動で当日 12:00 にスナップ） |
| 範囲 | **未来禁止**（最大値 = 今日）、過去は無制限 |
| 初期値 | アプリ起動時 = 今日 |
| 連続入力時の振る舞い | ViewModel ライフサイクル内で **前回選んだ日付を保持**。アプリ完全終了 → 再起動で今日にリセット |
| UI 配置 | 子供選択の下、タスク選択の上（自然な「誰の・いつ・何を」フロー） |

## 3. 非機能要件・スコープ外

- **アプリバックグラウンド復帰時の挙動**: 厳密には ViewModel が `ContentView` の `@State` として維持されるため、バックグラウンド復帰でもリセットされない。「アプリ完全終了で再起動」のみリセットの対象。
- **永続化**: `recordedDate` を UserDefaults などに保存しない。揮発性の UI 状態として扱う（誤って古い日付で記録するリスク回避）。
- **編集画面（`HelpRecordEditView`）**: 触らない。既存の「日付＋時刻」DatePicker をそのまま温存（編集は微調整用、登録は素早く、と責務を分離）。

## 4. アーキテクチャ

```
┌─────────────────────────┐         ┌──────────────────────────┐
│      RecordView         │  ────▶  │     RecordViewModel      │
│  (新規 dateSection 追加) │ Binding │  (新規プロパティ          │
└─────────────────────────┘         │   recordedDate: Date)    │
                                     └────────────┬─────────────┘
                                                  │
                                                  ▼ recordHelp() で利用
                                     ┌──────────────────────────┐
                                     │   HelpRecordRepository    │
                                     │   (既存: 変更なし)        │
                                     └──────────────────────────┘
```

### 変更するファイル

| ファイル | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Presentation/ViewModels/RecordViewModel.swift` | `recordedDate: Date` プロパティ追加（デフォルト `Date()`）、`recordHelp()` で `recordedDate` を 12:00 にスナップして `recordedAt` に渡す |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | `dateSection` を新規追加、`childSelectionView` と `taskListView` の間に配置 |
| `app/OtetsudaiCoinTests/Presentation/ViewModels/RecordViewModelTests.swift` | 新規日付関連テスト 4 件追加 |

### 変更しないファイル

- `app/OtetsudaiCoin/Domain/Entities/HelpRecord.swift` — 既存構造のまま
- `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift` — 編集画面は温存
- `app/OtetsudaiCoin/Domain/Services/UnpaidAllowanceDetectorService.swift` — `recordedAt` の月単位判定が自動で過去月を集計

## 5. データフロー

### 通常フロー（今日の登録）

1. ViewModel 初期化 → `recordedDate = Date()`
2. ユーザー: 子供選択 → タスク選択 → 「記録する」
3. `recordHelp()`:
   - 日付を 12:00 にスナップ: `Calendar.current.startOfDay(for: recordedDate).addingTimeInterval(12 * 3600)`
   - `HelpRecord(recordedAt: snapped)` を作成・保存

### 過去日付フロー

1. ユーザー: 子供選択 → 日付ピッカーで過去日（例 4/30）に変更 → タスク選択 → 「記録する」
2. `recordHelp()` で `recordedAt = 2026-04-30 12:00:00` として保存
3. その月の集計（`MonthlyHistoryView` 等）に自動的に組み込まれる

### 連続入力フロー（同セッション）

```
[1 回目] 4/30 を選択 → 記録 → recordedDate = 4/30 のまま
[2 回目] そのまま記録 → 4/30 で保存（連続入力が楽） ✅
[アプリ完全終了 → 再起動] → ViewModel 再生成 → 今日にリセット ✅
```

## 6. 既存システムへの影響

| 既存機能 | 影響 | 設計判断 |
|---|---|---|
| `MonthlyHistoryView`、`HelpHistoryView` | 過去日付記録が該当月に集計される | **意図通り** ✅ |
| `UnpaidAllowanceDetectorService` | 過去月の記録増加で「未払い額」が増える可能性 | **意図通り**（実際の状態に正直）⚠️ |
| `PaymentReminderNotificationService` | 翌月 1 日の未払い通知に影響することがある | **意図通り**（次回 reschedule 時に反映） |

⚠️ 注意：もし保護者が「先月支払い済み」状態で先月分の記録を後追加すると、未払い扱いに戻る挙動になる。これは仕様上正しい。将来必要に応じて「過去月への記録時に注意喚起」を別 issue で検討。

## 7. UI 詳細

### `RecordView` への追加コード（案 A 配置）

```swift
private var dateSection: some View {
    HStack {
        Image(systemName: "calendar")
            .foregroundColor(.blue)
        Text("記録日")
            .appFont(.sectionHeader)
        Spacer()
        DatePicker(
            "",
            selection: $viewModel.recordedDate,
            in: ...Date(),                    // 未来禁止
            displayedComponents: .date          // 日付のみ
        )
        .labelsHidden()
        .datePickerStyle(.compact)              // タップで展開
        .accessibilityIdentifier("record_date_picker")
    }
    .padding(.horizontal)
}
```

配置: `childSelectionView` の下、`taskListView` の上。

### ローカライゼーション

`Localizable.xcstrings` に「記録日」キーを追加（en: "Record Date"）。

### アクセシビリティ

`accessibilityIdentifier("record_date_picker")` を付与し UI テスト容易性を確保。

## 8. テスト戦略

### 新規 ViewModel テスト（`RecordViewModelTests.swift`）

| テスト | 検証内容 |
|---|---|
| `testRecordedDateDefaultsToToday` | 初期値が今日と同日 |
| `testRecordHelpUsesSelectedDateAtNoon` | `recordedDate=4/30` で記録 → 保存された record の `recordedAt` が 2026-04-30 12:00 |
| `testRecordedDatePersistsAcrossMultipleRecords` | 4/30 設定 → 1 回目記録 → 2 回目も `recordedDate` が 4/30 のまま |
| `testRecordedDateResetsToTodayOnViewModelInit` | 新しい ViewModel インスタンスで今日にリセット（永続化なし） |

### 回帰防止

既存の `RecordViewModelTests` の record 関連テストが通り続けること。特に `recordedAt` を `Date()` ベースで検証しているテストは、新仕様に合わせた更新（または `recordedDate` を初期値で運用）が必要。

### 手動確認項目

1. ✅ 今日の日付で記録 → 当月集計に反映
2. ✅ 先月日付で記録 → `MonthlyHistoryView` で先月分カウント
3. ✅ 未来日付選択不可（DatePicker でグレーアウト）
4. ✅ 同セッション 2 連続記録 → 日付保持
5. ✅ アプリ完全終了 → 再起動 → 日付今日にリセット

## 9. リリース観点

- **互換性**: `HelpRecord` のスキーマ変更なし、既存データへの破壊的変更なし
- **マイグレーション不要**
- **ロールバック**: ViewModel/View の変更だけなので revert 容易
