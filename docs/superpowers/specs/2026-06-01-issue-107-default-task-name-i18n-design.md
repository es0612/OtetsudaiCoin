# Issue #107: デフォルトお手伝い名のデータ層 i18n（表示時ルックアップ）

- 対象 Issue: #107（親 epic #89 の sub-item #1 から切り出し）
- 作成日: 2026-06-01
- ステータス: 設計承認済み（実装計画は writing-plans で作成）

## 背景

`HelpTask.defaultTasks()`（`Domain/Entities/HelpTask.swift`）が 10 個のデフォルトお手伝い名を **ja 文字列で生成**し、初回起動時（`ContentView.setupInitialData()`、`existingTasks.isEmpty` のときのみ）に Core Data へ save する。save 値は ja のまま persist されるため、**en ロケで起動してもデフォルトタスク名が日本語表示**される。

証拠: `docs/screenshots/asc/v1.1.x/en/02-record.png` の Today's Help カードが ja のまま。これは ASC の英語ストア掲載スクショとして「未翻訳」の印象を与える。ターゲット（在外日本人/バイリンガル家庭、#50 で確定）にとって en 初回体験・ストア品質の劣化要因。

## 製品判断（確定）

- デフォルト 10 件は **en ロケで英訳表示する**（#50 の en ストア戦略と整合）。
- ユーザー作成タスクは free text なので **翻訳せず verbatim 表示**（翻訳すべきでない）。

## 方式（確定: 案A 表示時ルックアップ）

翻訳対象は「固定 10 件の閉じた集合」かつユーザータスクは free text。この性質を使い、**DB 変更・migration を一切せず**、表示の瞬間にだけ ja 名 → 翻訳に読み替える。

### なぜ migration 方式（案B）を採らないか

案B（DB を key 化し起動時 migration）は、既存ユーザー DB の書き換えリスク・改名済みデフォルトの誤変換 idempotency 罠を抱えた上で、**結局表示箇所の差し替えは案A と同量**必要になる。案A は migration ぶんのリスクと手間を払わずに既存+新規を同一コードで救えるため、案B を strictly dominate する。

### seed 時翻訳を採らない理由

seed の瞬間の locale で英訳して DB 保存すると、(a) 既存ユーザーを救えず、(b) 後でロケール切替しても DB が固定され追従しない。CLAUDE.md「データ層 i18n の落とし穴（Core Data 保存値）」のアンチパターンそのもの。

## 設計

### コンポーネント

ドメインエンティティ `HelpTask` に **表示専用の `displayName`** を追加する。保存値 `name` は変更しない。

```swift
extension HelpTask {
    // 翻訳対象＝固定デフォルト 10 件の閉じた集合。
    // ja 原文をキーに、value はリテラル LocalizedStringResource にして
    // xcstrings 抽出と解決を確実化する（動的キー String(localized:変数) を避ける）。
    static let defaultNameLocalizations: [String: LocalizedStringResource] = [
        "下の子の面倒を見る": "下の子の面倒を見る",
        "お風呂を入れる": "お風呂を入れる",
        "食器を出す": "食器を出す",
        "食器を片付ける": "食器を片付ける",
        "お片付けする": "お片付けする",
        "玄関の靴を並べる": "玄関の靴を並べる",
        "ゴミ出しのお手伝い": "ゴミ出しのお手伝い",
        "洗濯物を運ぶ": "洗濯物を運ぶ",
        "テーブルを拭く": "テーブルを拭く",
        "自分の部屋の掃除": "自分の部屋の掃除"
    ]

    var displayName: String {
        guard let resource = HelpTask.defaultNameLocalizations[name] else {
            return name // ユーザー作成タスク・改名済みデフォルトは verbatim
        }
        return String(localized: resource) // en→翻訳 / ja→no-op
    }
}
```

実装メモ: `defaultTasks()` が持つ 10 個の ja 配列と `defaultNameLocalizations` のキーは同一集合。実装時に **単一の source of truth**（例: `static let defaultTaskNames`）から両者を導出して二重管理を避けることを検討する（writing-plans で詳細化）。

### データフロー

- **seed**: `ContentView.setupInitialData()` は変更しない（ja 名のまま save）。
- **display**: 各画面が `task.name` の代わりに `task.displayName` を読む。
- **波及確認済み**: `HelpRecord` は `helpTaskId: UUID` 参照のみで **タスク名を denormalize 保存していない**（`record.task.name` は live な関連参照）。よって履歴・振り返り画面にも `displayName` が自動波及する。
- **logic は据え置き**: 重複チェック・ソート・保存・DebugLogger は raw `name` のまま（翻訳不要）。

### 差し替え対象（display のみ）

| ファイル | 行 | 対応 |
| --- | --- | --- |
| `TaskCardView` | 65 | `task.name` → `displayName` |
| `HelpRecordEditView` | 171 | `task.name` → `displayName` |
| `RecordButtonBar` | 39 | `selectedTask.name` → `displayName` |
| `TaskManagementView` | 115 / 83（削除確認） | `displayName` |
| `TaskManagementView` | 214（編集欄） | `task.displayName`（編集欄も en 訳表示の決定を反映） |
| `HelpHistoryView` | 317 / 51（削除確認） | `record.task.name` → `displayName` |
| `RecordTutorialView` | 446 | `displayName` |
| `MonthlyRetrospectiveViewModel` | 134 | 表示モデル構築箇所。実装時に display か検証の上 `displayName` |

raw `name` のまま残す箇所（変更しない）:

- DebugLogger 呼び出し（`HelpRecordEditViewModel` 84 / 86 / 143）— ログ用
- `TaskManagementViewModel` 32（sort）/ 59（dup-check）/ 103（save）— ロジック用

### 編集欄の挙動（確定）

en ロケでデフォルトタスクを編集するとき、編集欄（`TaskManagementView:214`）には **en 訳（`displayName`）を表示**する。list と見た目が一致して直感的。トレードオフとして、無変更保存でも ja → en 上書きとなり以降ロケール非追従になるが、「一度ユーザーが編集したらユーザーのタスク扱い」として許容する。

### 同梱する軽微 finding ＋ スコープ境界

- **同梱（UI 層・独立）**: `TaskCardView` の `Text("選択")`（bulk 選択インジケータ）が en キー未登録で en ロケでも ja「選択」表示。xcstrings に「選択」→ "Select" を追加する。既存の `"選択中"→"Selected"` の対。データ層機構とは独立だが同一 i18n テーマなので同梱。
- **スコープ外**: `SampleDataService` の ja サンプル名（preview/UI テスト専用、出荷ユーザーデータでない）。今回触らず、PR description に「別観点・今回外」と明記する。

### 既知の軽微な帰結（設計として明示・許容）

- **重複チェック**: en ユーザーが既存デフォルトの en 訳を手入力しても raw ja と不一致で dup-check をすり抜け、視覚的に似た 2 行ができうる。低確率・データ破損ではない。
- **ソート**: en ロケでも raw ja 文字列順。cosmetic。

### エラー処理

未知の `name` は verbatim fallback（`guard ... else { return name }`）。エラー状態は持たない。

## テスト戦略

CLAUDE.md「`String(localized:)` を test 側で再計算すると test-bundle/locale に過結合」のトラップを避け、**locale 非依存の契約**をアサートする。

- **passthrough**: `HelpTask(name: "ユーザー独自タスク").displayName == "ユーザー独自タスク"`（free text は verbatim）。
- **membership**: `HelpTask.defaultNameLocalizations["下の子の面倒を見る"] != nil`（既知デフォルトが翻訳対象として登録されている。ロケール非依存）。
- **「選択」キー**: 既存の String Catalog 網羅テスト（全キーに en 翻訳が存在することを検証）がキー追加で自動担保。
- **採用しない**: en 訳の exact string 一致アサート（locale 過結合のため）。

## 受け入れ条件

- en ロケでデフォルトタスク 10 件が英訳表示される（list / 記録 / 履歴 / 振り返り / チュートリアル）。
- ja ロケは表示が変わらない（no-op、regression なし）。
- ユーザー作成タスクは両ロケで verbatim 表示。
- `TaskCardView` の「選択」が en ロケで "Select" 表示。
- 既存の単体テスト・String Catalog 網羅テストが green。

## 関連

- 親 epic: #89
- en ストア戦略: #50
- CLAUDE.md「データ層 i18n の落とし穴（Core Data 保存値）」
- skill: `xcstrings-bulk-update`（10 キー + 「選択」追加）
