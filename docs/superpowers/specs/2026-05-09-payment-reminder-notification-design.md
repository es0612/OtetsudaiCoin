# 支払いリマインド通知 設計書

- **対応イシュー**: [#15 支払いのプッシュ通知リマインドもしたい](https://github.com/es0612/OtetsudaiCoin/issues/15)
- **作成日**: 2026-05-09
- **状態**: ドラフト → ユーザーレビュー待ち

## 1. 背景と目的

OtetsudaiCoin では子供のお手伝い実績からお小遣い額を計算し、月次で支払い記録を残す。実際の運用では **支払いを忘れて月をまたいでしまう**ケースが起こり得る。既にホーム画面の未払いバナー（イシュー#9で改善済）と毎日のお手伝い記入リマインド（イシュー#13）はあるが、**「先月の支払い忘れに対して能動的に気づかせる」プッシュ通知**は未実装である。本機能はその欠落を埋める。

## 2. 要件

### 2.1 機能要件

| 項目 | 仕様 |
|---|---|
| 通知タイミング | 毎月1日のユーザー指定時刻（デフォルト 09:00） |
| 通知条件 | 「先月以前」の未払いが1件以上ある場合のみ。0件なら何もしない |
| 通知内容 | 子供名・該当月・金額を具体的に表示。複数の未払いは**1通知に集約** |
| ON/OFF | 設定画面でユーザーがトグル可能 |
| 時刻設定 | 設定画面のDatePickerで時刻のみカスタマイズ可能（日付は1日固定） |
| タップ時遷移 | ホーム画面（未払いバナーが表示されている画面）へ |

### 2.2 通知メッセージ仕様

- **タイトル**: `お小遣いの未払いがあります 💰`
- **本文（例）**:
  - 単一: `さくらちゃんの3月分 ¥1,500 が未払いです`
  - 複数: `さくらちゃん3月分(¥1,500)、たろうくん3月分(¥1,000) が未払いです（合計 ¥2,500）`

### 2.3 非機能要件

- 通知許可（UNAuthorization）の取得は既存の日次リマインダーと同様のフロー
- ローカル通知のみ（リモートプッシュは対象外）
- 既存の `ReminderNotificationService`（日次リマインダー）には影響を与えない

## 3. アーキテクチャ

### 3.1 コンポーネント構成

```
[Domain Layer]
  PaymentReminderNotificationService (新規)
    - protocol: PaymentReminderNotificationServiceProtocol
    - 依存:
        NotificationCenterProtocol（既存）
        UserDefaults（既存パターン）
        UnpaidAllowanceDetectorService（既存）
        ChildRepository（既存）
        HelpRecordRepository（既存）
        AllowancePaymentRepository（既存）
        HelpTaskRepository（既存）

[Presentation Layer]
  PaymentReminderNotificationSettingsViewModel (新規)
    - 既存の NotificationSettingsViewModel と並列に配置
    - on/off, 時刻設定, scheduleError ハンドリング

  NotificationSettingsView (拡張)
    - 既存に「支払いリマインド」Section を追加
    - 2 つの ViewModel を @Bindable で受け取る
```

### 3.2 通知識別子

- `payment-reminder` の単一識別子を使用（集約方針のため）
- `cancelAll()` 時もこの識別子のみを対象とする（日次リマインダーには影響しない）

### 3.3 永続化（UserDefaults キー）

| キー | 型 | デフォルト |
|---|---|---|
| `paymentReminderNotificationEnabled` | Bool | false |
| `paymentReminderNotificationHour` | Int | 9 |
| `paymentReminderNotificationMinute` | Int | 0 |

既存の `reminderNotification*` 系キーとは独立。

## 4. データフロー

### 4.1 再スケジュールのトリガー

未払い状況は動的に変わるため、以下のタイミングで `service.reschedule()` を呼ぶ：

| トリガー | 呼び出し元 | 理由 |
|---|---|---|
| アプリ起動時 | `OtetsudaiCoinApp` または `AppDelegate.didFinishLaunching` | 月をまたいだ場合の翌月分予約 |
| 通知設定変更時 | `PaymentReminderNotificationSettingsViewModel` | ON切替・時刻変更を反映 |
| お小遣い記録追加・編集・削除時 | `HomeViewModel` 等 | 未払い金額が変わるため |
| 支払い登録・取り消し時 | `AllowancePaymentViewModel` 等 | 未払いが解消する/復活するため |

### 4.2 reschedule() の処理ステップ

```
1. cancelAll()  // 既存の payment-reminder 通知を削除
2. isEnabled == false なら return
3. UNUserNotificationCenter.notificationSettings() を確認し、authorizationStatus == .authorized でなければ return
4. 全子供を ChildRepository から取得
5. 各子供ごとに UnpaidAllowanceDetectorService.detectUnpaidPeriods() を呼び、未払いを集約
6. 集約結果が空なら return（通知不要）
7. 翌月1日の指定時刻 (hour, minute) を Calendar.date(byAdding: .month, value: 1, to: thisMonthFirstDay) で生成
8. UNCalendarNotificationTrigger(dateMatching: components, repeats: false) でリクエスト作成
9. 集約結果からタイトル・本文を組み立て（本文が極端に長い場合は子供数の上限などで省略表記する判断は実装プランで）
10. notificationCenter.addNotificationRequest(request)
```

`repeats: false` を採用する理由: 通知内容が動的（月ごとに金額・子供が変わる）なので、繰り返し通知ではなく毎月再スケジュールする方式を採る。

## 5. UI 詳細

### 5.1 NotificationSettingsView（拡張後）

```swift
Form {
    Section("リマインド通知") {  // 既存
        Toggle(...)
        if viewModel.isEnabled { DatePicker(...) }
    }
    Section("支払いリマインド") {  // 新規
        Toggle("通知を有効にする", ...)
        if paymentViewModel.isEnabled {
            DatePicker("通知時間", ...)
        }
    }
}
```

### 5.2 タップ時遷移

既存の `Notification.Name.navigateToRecord`（記録画面遷移）と同様のパターンで、`AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` 内でリクエスト識別子を判定する：
- `daily-reminder` → 既存通り `navigateToRecord`
- `payment-reminder` → ホーム画面（未払いバナーが表示されている画面）への遷移シグナルを post

具体的な `Notification.Name` 値・遷移ハンドラの設置場所（`HomeView` か `ContentView` か）は実装プラン段階で既存ルーティング構造を確認のうえ決定する。

## 6. エラーハンドリング

| エラーケース | 挙動 |
|---|---|
| 通知許可拒否 | トグル自動 OFF、`isEnabled = false` を永続化 |
| `addNotificationRequest` 失敗 | `scheduleError` を ViewModel に保存、UI で軽くエラー表示。`isEnabled = false` に戻す |
| リポジトリ取得失敗 | 通知をキャンセルしてログ出力のみ。アプリは継続動作 |

既存の `NotificationSettingsViewModel.toggleNotification` のパターンを踏襲する。

## 7. テスト戦略

### 7.1 PaymentReminderNotificationServiceTests

- 未払いなし → 通知が追加されない（モックの `addNotificationRequest` が呼ばれない）
- 単一子供の単一月未払い → タイトル・本文・トリガーの DateComponents を検証
- 複数子供×複数月 → 1通知に集約され、合計金額が正しい
- `reschedule()` で `removePendingNotificationRequests` → `addNotificationRequest` の順序を検証
- `isEnabled = false` のとき何もしない
- 認可拒否時は通知スケジュールされない
- 翌月1日の判定（年をまたぐ12月→1月のケースを含む）

### 7.2 PaymentReminderNotificationSettingsViewModelTests

- トグル ON 時、許可取得 → schedule の流れ
- トグル OFF 時、cancelAll が呼ばれる
- 時刻変更時、reschedule が呼ばれる
- スケジュール失敗時、scheduleError がセットされ isEnabled が戻る

合計 ~12 ケース想定。既存の `ReminderNotificationServiceTests` (277行) / `NotificationSettingsViewModelTests` (257行) と同等のカバレッジを目指す。

## 8. 設計上の留意点

- **既存ロジックを変えない**: `UnpaidAllowanceDetectorService.detectUnpaidPeriods()` は当月を除外する仕様（過去月のみ返す）。これは月初通知（先月分のリマインド）の用途と完全に合致するため、ロジック変更不要 ✅
- **再スケジュールの呼び忘れリスク**: 4箇所のトリガーから呼ぶ必要があるため、ヘルパー（例: `PaymentReminderRescheduler` ファサード、または DI 経由で各 ViewModel に注入）を用意して呼び忘れを防ぐ。あるいは `NotificationCenter` の `Notification.Name`（例: `.didModifyRecords` など）を使った観察パターンも検討可。実装プラン段階で具体策を決める。
- **年またぎ**: 12月実行時に翌月1日 = 翌年1月1日となるよう、`Calendar.date(byAdding: .month, value: 1, to: ...)` を使う。直接 `month + 1` の文字列計算は避ける。
- **タイムゾーン**: `Calendar.current` を使用し、ユーザーのローカルタイムゾーンに合わせる（既存実装と同様）。

## 9. スコープ外

以下は本機能のスコープ外とし、必要に応じて別イシューで扱う：

- リモートプッシュ通知（FCM/APNs）対応
- 通知のリッチコンテンツ（画像・アクションボタン等）
- 月初以外のタイミング（月末リマインド等）
- ATT 対応（広告 #22 と統合検討）
- バックグラウンドフェッチ（`BGTaskScheduler`）による通知再スケジュール

## 10. 参考

- 既存実装: `app/OtetsudaiCoin/Domain/Services/ReminderNotificationService.swift`
- 既存実装: `app/OtetsudaiCoin/Domain/Services/UnpaidAllowanceDetectorService.swift`
- 既存実装: `app/OtetsudaiCoin/Domain/Entities/UnpaidPeriod.swift`
- 既存実装: `app/OtetsudaiCoin/Presentation/ViewModels/NotificationSettingsViewModel.swift`
- 既存実装: `app/OtetsudaiCoin/Presentation/Views/NotificationSettingsView.swift`
- 既存テスト: `app/OtetsudaiCoinTests/Domain/Services/ReminderNotificationServiceTests.swift`
