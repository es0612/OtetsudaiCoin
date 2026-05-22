# #73 同日同タスクの重複記録チェック - Design

- **Issue**: [#73](https://github.com/es0612/OtetsudaiCoin/issues/73)
- **Date**: 2026-05-21
- **Status**: Design approved, awaiting plan
- **Related**: PR #72 (#69 一括記録機能), PR #77 (#74 RecordButtonBar 分離)

## 背景

PR #72 で「同タスクを同日に複数回登録できる」状態（重複チェックなし）を default 採用した。その判断は、`recordedDate` を `DatePicker` で過去日に切り替えて記録できる UX や、家事が 1 日に複数回起こりうる現実（ゴミ出し・食器洗い・洗濯物畳み等）と整合させた最小スコープの帰結である。

一括モード（複数 task を checkbox で選んで一気に記録）が PR #72 で追加されたことで、**「うっかり同じ task を 2 回登録する」リスクが顕在化** した。一方で「同日にゴミ出し 2 回」のような正当な重複もあるため、block ではなく **情報提示** で「うっかり」を catch する設計が要件。

## 採用案: B. 警告ラベルのみ（block しない）

3 案比較（A. block / B. 警告ラベルのみ / C. 検知なし）を経て、**B. 警告ラベルのみ** を採用した。

### 理由

1. **家事の現実** 1 日複数回タスクを機械的に block するのは UX 後退。issue 本文でも「同日にゴミ出し 2 回」が明示的に挙げられている。
2. **過去日編集ユース** `DatePicker` で過去日に切り替えて「忘れてた分を後から記録」する正規フローまで block すると修復不能。
3. **将来拡張余地** B 採用後に「設定で block 化も選べる」など段階拡張が可能。A から B への撤退より入りやすい。

### 対象モード

- **一括モードと単一モードの両方** で警告ラベルを表示する
- データ層は両モード共通であり、片方だけ無効化する正当な理由がない
- 単一モードでも「うっかり 2 回タップ」リスクは同じ

## アーキテクチャ

```text
RecordView
  ├─ childSelectionView (child 切替 → onChange)
  ├─ dateSection (DatePicker → onChange of recordedDate)
  └─ taskListView
      └─ ForEach availableTasks { task in
           TaskCardView(
             task: ...,
             isSelected: ...,
             isBulkMode: ...,
             existingCount: viewModel.existingRecordCount(for: task.id),  ← 新規 prop
             onTap: ...
           )
         }
                 ↑ existingCount を引く
RecordViewModel (新規 state + 派生 API)
  + var existingRecordCounts: [UUID: Int] = [:]
  + func existingRecordCount(for taskId: UUID) -> Int
  + func loadExistingCountsForCurrentDateAndChild()
    - selectedChild + recordedDate が両方ある時のみ実行
    - findByDateRange(startOfDay, endOfDay) で当日 record 取得
    - selectedChild に絞り込み (filter)
    - Dictionary(grouping:by:).mapValues { $0.count } で map 化
    - existingRecordCounts に代入
                 ↑ 既存 findByDateRange を活用、Repository API 追加なし
HelpRecordRepository (変更なし)
  findByDateRange(from:to:)
```

### 設計要点

- **Repository 層は無変更** — 既存 `findByDateRange` を活用し、protocol / 2 実装 (CoreData / Mock) を触らずに済む
- **新規 state は ViewModel に 1 つ** — `existingRecordCounts: [UUID: Int]`
- **trigger は次の経路に集約**
  1. `loadData()` 末尾（初回 + child 自動選択直後）
  2. `selectChild()` 末尾
  3. `recordedDate` の DatePicker `onChange` modifier
  4. `setupNotificationListeners` の `observeHelpRecordUpdates` 経路（save 完了の通知が observer 経由で再 load を回す）
- **TaskCardView は API 追加のみ** — `existingCount: Int = 0` の prop を 1 つ追加、`coinInfo` の下に conditional row

## Data Flow

### 起動〜初回表示

```
RecordView.onAppear
  └─ viewModel.loadData()
       ├─ findAll children
       ├─ findActive tasks
       ├─ selectedChild auto-select (first child) if nil
       └─ loadExistingCountsForCurrentDateAndChild()
            └─ findByDateRange(today-startOfDay, today-endOfDay)
               filter { $0.childId == selectedChild.id }
               grouping by helpTaskId
               → existingRecordCounts = [taskId: count]
```

`loadData` の末尾で auto-select child 直後に count load を chain する。これで初回表示時に既存 count がカードに反映済みになる。

### child 切替時

```
ChildCardView tap
  └─ viewModel.selectChild(child)
       ├─ isChangingChild → selectedTaskIds / selectedTask reset (既存)
       ├─ clearErrorMessage() (既存)
       └─ loadExistingCountsForCurrentDateAndChild()
```

別の子に切り替えたら count map は別の子のものに更新。前の子の count が残らない。

### 日付変更時

```
DatePicker onChange of recordedDate
  └─ viewModel.loadExistingCountsForCurrentDateAndChild()
```

`RecordView` の `dateSection` に `onChange(of: viewModel.recordedDate)` modifier を追加する。

### record 完了時（recordHelp / recordBulkHelp 共通）

```
Task save 完了
  ├─ successIds.isEmpty == false の時のみ NotificationManager.notifyHelpRecordUpdated()
  │   ↓
  │   observer 経由で他 ViewModel も再 load
  │   RecordViewModel 自身も observer で loadData() → loadExistingCountsForCurrentDateAndChild()
  └─ (recordHelp / recordBulkHelp 内では直接 reload を呼ばない、observer 経路に統一)
```

`recordHelp` / `recordBulkHelp` 内で直接 `loadExistingCountsForCurrentDateAndChild()` を呼ぶ二重発火は避け、**観測者経路 (loadData → 末尾 reload) に統一** する。これにより外部 (HelpHistoryView, HelpRecordEditView 等) の編集/削除からの反映も同じ経路で吸収される。

### キャンセル制御

`loadExistingCountsForCurrentDateAndChild` は内部 `Task` を持ち、連続呼び出し時は前回を cancel する。

```swift
private var loadCountsTask: Task<Void, Never>?

func loadExistingCountsForCurrentDateAndChild() {
    loadCountsTask?.cancel()
    guard let child = selectedChild else {
        existingRecordCounts = [:]
        return
    }
    loadCountsTask = Task {
        // findByDateRange + filter + grouping
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.existingRecordCounts = newMap
        }
    }
}
```

## UI 詳細

### TaskCardView API 拡張

```swift
struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    var existingCount: Int = 0        // 新規 prop (default 0 で既存呼び出し互換)
    let onTap: () -> Void
    // ...
}
```

### body 差分

`coinInfo` と `selectionIndicator` の間に `existingCountRow` を挿入：

```swift
var body: some View {
    Button(action: onTap) {
        VStack(spacing: 12) {
            taskIcon
            taskTitle
            coinInfo
            existingCountRow      // 新規 (count >= 1 のみ実体表示)
            selectionIndicator
        }
        .padding()
        .frame(height: 150)       // 140 → 150 に微調整 (1 行分)
        .background(cardBackground)
    }
}

@ViewBuilder
private var existingCountRow: some View {
    if existingCount >= 1 {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
            Text(existingCountText)
                .appFont(.captionText)
                .foregroundColor(.gray.opacity(0.7))
                .accessibilityIdentifier("existing_count_label")
        }
    } else {
        EmptyView()
    }
}

private var existingCountText: String {
    let count = existingCount
    return String(localized: "すでに \(count) 件記録済み")
}
```

### 配色・トーンの根拠

- **gray.opacity(0.7) (neutral)** — warningMessage のオレンジは「失敗」用に、blue は「選択中」用に予約しているため、neutral gray が最も自然
- **icon `checkmark.seal`** — 「既に確認/記録済み」を示す。`info.circle` や `clock.arrow.circlepath` も候補だったが `checkmark.seal` が「完了済み」の意図に最も近い
- **条件描画** — `if existingCount >= 1` で分岐、0 件は `EmptyView()`

### 高さ統一の根拠

`existingCount >= 1` のカードだけ +1 行ぶん背高くなると `LazyVGrid` の中で隣のカードと高さがズレてレイアウト崩れになる。**全カード共通で `frame(height: 150)` に固定** することでこれを吸収（0 件カードは余白が増えるだけで違和感は最小）。

### block ではないことの明示

- `onTap` は **常に発火**。`disabled` 等の制御は一切入れない
- `recordButtonDisabled` の判定（RecordButtonBar 側）も無変更
- カードの色・選択 indicator は無変更で、「既に登録済みでも普通に選択して追加登録できる」が視覚的にも伝わる

### Before / After 比較（1 件登録済みの場合）

```
Before                              After (existingCount=1)
┌─────────────────┐                ┌─────────────────┐
│   [Icon]        │                │   [Icon]        │
│   食器洗い      │                │   食器洗い      │
│   10コイン      │                │   10コイン      │
│                 │                │   ✓ すでに 1 件 │ ← 新規行
│   ☐ 選択        │                │   ☐ 選択        │
└─────────────────┘                └─────────────────┘
  height: 140                       height: 150
```

## i18n: xcstrings 新規 key

### key 構造（既存 plural variations pattern と一致）

```jsonc
"すでに %lld 件記録済み" : {
  "localizations" : {
    "en" : {
      "variations" : {
        "plural" : {
          "one" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Already recorded %lld time"
            }
          },
          "other" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "Already recorded %lld times"
            }
          }
        }
      }
    }
  }
}
```

- ja は key 自体が値（既存 pattern と同一、`%lld 件記録しました！` などと同じ）
- en は `variations.plural` の one / other を用意

### 呼び出し方

```swift
let count = existingCount
return String(localized: "すでに \(count) 件記録済み")
```

`String.LocalizationValue` の placeholder で plural variations を効かせる。`String(format: String(localized: "..."), count)` は variations を bypass する既知罠（CLAUDE.md 参照）。

### 表示結果

| count | ja | en |
|---|---|---|
| 1 | すでに 1 件記録済み | Already recorded 1 time |
| 2 | すでに 2 件記録済み | Already recorded 2 times |
| 5 | すでに 5 件記録済み | Already recorded 5 times |

### 編集方針

1 key のみの追加なので `Edit` tool で `Localizable.xcstrings` に手動挿入する（Python による書き換えは ` : ` 整形が崩れて diff 爆発の既知罠）。挿入位置は `"%lld 件記録しました！"` の隣（同系列をまとめる）。

## Testing 戦略

CLAUDE.md の SwiftUI View テスト戦略・i18n 罠・component 分離 path に準拠。

### Layer 1: RecordViewModelTests (5–6 件追加)

| # | Test | 検証内容 |
|---|---|---|
| 1 | `testExistingRecordCounts_initiallyEmpty` | init 直後 `existingRecordCounts == [:]` |
| 2 | `testLoadExistingCounts_noSelectedChild_clearsMap` | `selectedChild = nil` で load 呼び出し → map が空に |
| 3 | `testLoadExistingCounts_filtersBySelectedChildAndDate` | mock に異なる child / 異なる date の record を仕込み、selectedChild=A & date=today で A の today 分のみが count される |
| 4 | `testExistingRecordCount_returnsZeroForUnknownTask` | `existingRecordCount(for: 未登録 taskId) == 0` |
| 5 | `testSelectChild_triggersCountReload` | 別 child に切替後、count map が新 child のものに更新される |
| 6 | `testRecordHelpSuccess_updatesCountViaObserver` | recordHelp 成功 → notification 経由で count map が +1 される（observer chain の end-to-end 担保） |

**mock 補強** — `MockHelpRecordRepository` に `findByDateRange` が未実装なら追加。`stub: [HelpRecord]` を date filter & 返却するだけのシンプル実装。

### Layer 2: TaskCardViewTests (新規 component test, 3 件)

前準備として `TaskCardView` を `RecordView.swift` から `Presentation/Components/TaskCardView.swift` に切り出す（#74 で確立した component 分離 path）。

| # | Test | 検証内容 |
|---|---|---|
| 1 | `testExistingCountRow_hidden_whenCountIsZero` | `existingCount=0` で `existing_count_label` が存在しない |
| 2 | `testExistingCountRow_visible_whenCountIsOne` | `existingCount=1` で label が "すでに 1 件記録済み" を含む |
| 3 | `testExistingCountRow_visible_whenCountIsMany` | `existingCount=3` で label が "すでに 3 件" を含む（plural 表示） |

`TaskCardView` 自体は NavigationStack / BannerAdView / Material を持たないため、ViewInspector の既知 blocker は踏まない。`accessibilityIdentifier("existing_count_label")` で安全に特定。

### Layer 3: LocalizedMessageTests (1 件追加)

```swift
func testExistingCountLabel_singularContainsOne() {
    let message = String(localized: "すでに \(1) 件記録済み")
    XCTAssertTrue(message.contains("1"))
    XCTAssertTrue(message.contains("件記録済み") || message.contains("recorded"))
}
```

CLAUDE.md の「one バリアント regression を catch する最小担保」パターン準拠。

### Layer 4: RecordView / RecordButtonBar への structural test

**追加しない**。理由：

- 今回の UI 変更は `TaskCardView` 内の 1 行追加のみ
- `RecordView` 本体は変更なし（ForEach に existingCount 引数を渡すだけ）、`RecordButtonBar` は無変更
- CLAUDE.md ルール: BannerAdView / NavigationStack blocker のため RecordView の structural test は省略、ViewModel + component test で担保

### Simulator 視覚確認（PR 直前）

- `ios-simulator-app-verification` skill で build & launch
- ⚠️ TabView の record タブ切替が simctl 不可（CLAUDE.md 既知問題）のため、Record タブ内の TaskCard 描画は CLI からは触れない
- PR description で「Record タブの既存 count 表示は reviewer 手動確認推奨」と明示する

### test 件数サマリ

| Layer | 新規 test 数 | 場所 |
|---|---|---|
| ViewModel | 5–6 件 | `RecordViewModelTests.swift` 追加 |
| Component | 3 件 | `TaskCardViewTests.swift` 新規 |
| i18n | 1 件 | `LocalizedMessageTests.swift` 追加 |
| View (structural) | 0 件 | 既存 blocker のため対象外 |

### 前準備 refactor

`TaskCardView` を `RecordView.swift` から `Presentation/Components/TaskCardView.swift` に切り出す。writing-plans の phase 1 として扱う。

## スコープ外 / 将来検討

- **block 化オプション** — 設定で「同日同タスクを block する」モードを選べるようにする拡張は将来 issue。今回 B 採用の方針として B のみ実装する
- **count query 専用 API** — Repository に `countByDate(childId:date:) -> [UUID: Int]` を追加する最適化は YAGNI。record 数が増えて`findByDateRange` の filter コストが問題化したら検討
- **複数日にまたぐ警告** — 「過去 7 日間で N 件」のような表示は対象外（現在の `recordedDate` の日にちのみが対象）
