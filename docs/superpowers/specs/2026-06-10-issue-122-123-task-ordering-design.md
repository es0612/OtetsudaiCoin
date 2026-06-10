# タスク並び順設計（#122 手動並べ替え + #123 よく使う順）

- 日付: 2026-06-10
- 対象 issue: [#122](https://github.com/es0612/OtetsudaiCoin/issues/122)（表示順を自由に並べ替えたい）/ [#123](https://github.com/es0612/OtetsudaiCoin/issues/123)（よく使うタスクを上に表示したい）
- ステータス: 設計承認済み（brainstorming セッションで確定）

## 背景と現状

- `CDHelpTask` に並び順フィールドはなく、`findAll()` / `findActive()` に sort descriptor もない。記録画面のタスク一覧は **Core Data の返却順そのまま（不定順）**。
- タスク管理画面（設定内）は `TaskManagementViewModel` が名前順（`sorted { $0.name < $1.name }`）でソートしている。
- 使用頻度は `HelpRecord`（`recordedAt` + `helpTaskId`）から導出可能で、スキーマ変更なしで集計できる。
- `NotificationManager.notifyTasksUpdated()` / `observeTasksUpdates()` は存在するが、呼び出し側・購読側ともゼロの dead API。RecordView は `onAppear` で `loadData()` するため、設定でのタスク変更はタブ切替時に反映される（既存の追加/削除と同経路）。

## 決定事項（ユーザー確認済み）

| 論点 | 決定 |
| --- | --- |
| 手動順と頻度順の関係 | **手動順を正とする**。タスク管理で並べ替えた順番が全画面の表示順になる |
| #123 の満たし方 | タスク管理画面に**「よく使う順に並べ替え」ボタン**を置き、押すと頻度順が手動順として保存される（その後手で微調整可） |
| 頻度の定義 | **直近90日の記録件数**（全子ども合算）。同件数は名前順でタイブレーク |
| 永続化方式 | **Core Data に `sortOrder` 属性追加**（lightweight migration） |
| 並び順モード設定 | 持たない（手動順一本、YAGNI） |

## 設計

### 1. データモデルと migration

- `OtetsudaiCoin.xcdatamodeld` に新 model version（`OtetsudaiCoin 2.xcdatamodel`）を追加し current version に設定する。
- `CDHelpTask` に `sortOrder: Integer 32`（default 0、usesScalarValueType）を追加。
- `NSPersistentContainer` はデフォルトで automatic lightweight migration（`shouldMigrateStoreAutomatically` + `shouldInferMappingModelAutomatically`）が有効のため、**migration コードは書かない**。属性追加 + default 値は lightweight migration の標準パターン。
- **backfill は行わない**。読み取り時のソートキーを `(sortOrder asc, name asc)` にすることで、既存ユーザーの全タスク（全件 `sortOrder = 0`）は従来のタスク管理画面と同じ名前順で表示される。最初に並べ替え操作（手動 move または「よく使う順」ボタン）をした時点で全タスクに 0..n-1 を採番して保存し、自然に移行する。
- 新規タスク作成時は `max(sortOrder) + 1` を割り当てて末尾に追加する。

### 2. Domain 層

- `HelpTask` entity に `sortOrder: Int` を追加（`init` の default 引数 0、既存呼び出し箇所はコンパイル互換）。
- `activate()` / `deactivate()` / `updateCoinRate()` は `sortOrder` を保持する。
- `Equatable` は引き続き `id` ベース（変更なし）。

### 3. Repository 層

- `CoreDataHelpTaskRepository.findAll()` / `findActive()` に `NSSortDescriptor`（`sortOrder` 昇順 → `name` 昇順）を追加。
- `HelpTaskRepository` protocol に一括更新 API を追加:

```swift
/// orderedIds の並び順で sortOrder を 0..n-1 に採番して一括保存する
func updateSortOrders(_ orderedIds: [UUID]) async throws
```

- 実装は background context で一括更新（1件ずつ `save` を回さない）。

### 4. ViewModel / UI

#### TaskManagementViewModel

- `loadTasks()` の `sorted { $0.name < $1.name }` を削除し、repository のソート済み返却に依存する。
- 追加メソッド:
  - `moveTasks(from: IndexSet, to: Int)` — 配列を `move` で並べ替え → 並び替え後の配列順をそのまま `updateSortOrders` で保存。並べ替え判定はテスト可能な pure なロジックとして保つ（gesture closure に判定を埋め込まない）。
  - `sortByFrequency(now: Date = Date())` — `now` から遡って90日分の `HelpRecord` を取得し、`helpTaskId` で件数集計（全子ども合算）→ 件数降順・同件数は名前順 → その順で `updateSortOrders` に保存。`now` を引数注入してテストの実行日非依存を担保する。
- 保存失敗時は既存パターン通り `setError(...)`。成功時のみ `tasks` を更新（reload）。

#### TaskManagementView

- `List` の `ForEach` に `.onMove` を追加し、toolbar に `EditButton` を置く。
- toolbar（またはリスト上部）に「よく使う順に並べ替え」アクションを追加。
- `.onMove` の plumbing（DragGesture 相当）は untested で許容し、採番ロジックは ViewModel テストで担保する。

#### RecordView / RecordViewModel

- **変更なし**。`findActive()` がソート済みを返すことで記録画面のタスク一覧に自動反映される。
- 通知配線（`notifyTasksUpdated`）は追加しない。既存の `onAppear` reload 経路で十分（YAGNI）。dead API は本 PR では触らない。

### 5. エラー処理

- `updateSortOrders` の失敗は `setError(...)` でユーザー向けメッセージ表示、`tasks` 配列はロールバック（reload で DB 状態に揃える）。
- 頻度集計の `HelpRecord` 取得失敗も同様に `setError(...)`（並べ替えは実行しない）。

### 6. i18n

- 新ラベル「よく使う順に並べ替え」（en: "Sort by Most Used"）を xcstrings へ ja/en 追加。`EditButton` はシステム標準ラベル（Edit/編集）なので追加不要。
- `LocalizationStringCatalogTests` が英訳漏れの gate になる。

### 7. テスト戦略

| 対象 | テスト内容 |
| --- | --- |
| `HelpTask` entity | `sortOrder` が `activate()` / `deactivate()` / `updateCoinRate()` で保持される |
| `CoreDataHelpTaskRepository` | `sortOrder` round-trip / `(sortOrder, name)` ソート / `updateSortOrders` の採番（in-memory store） |
| `TaskManagementViewModel` | move 後の配列順と保存呼び出し / `sortByFrequency` の集計・90日窓の境界・名前順タイブレーク / 保存失敗時の `setError` |
| 日付 fixture | **固定日にピン留め**（`now` 注入 + 固定 fixture 日付）。相対日付（`now ± N日`）による月初 flake を避ける（CLAUDE.md ルール準拠） |
| View | ViewInspector 制約（iOS 26 で identifier 解決不可）に従い `findAll` ベースの軽い structural + smoke test。`.onMove` plumbing は untested |

## スコープ外

- 子ども別の並び順（並び順は全子ども共通の1本）
- 並び順モードの設定項目（手動順/頻度順の切替設定）
- `notifyTasksUpdated` の配線・削除
- 記録画面側の UI 変更
