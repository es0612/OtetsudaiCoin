# デフォルトお手伝い名のデータ層 i18n（表示時ルックアップ）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** デフォルトお手伝い名 10 件を en ロケで英訳表示し（DB 変更・migration なし）、あわせて `TaskCardView` の「選択」en キー欠落を解消する。

**Architecture:** ドメインエンティティ `HelpTask` に表示専用 `displayName` を追加。固定デフォルト 10 件の ja 名をキーにした `LocalizedStringResource` マップで表示時に翻訳読み替え（既知デフォルトのみ翻訳、ユーザー作成タスクは verbatim）。保存値 `name` は不変。表示 8 面を `task.name` → `task.displayName` に差し替える。

**Tech Stack:** Swift / SwiftUI / Xcode 16+（`PBXFileSystemSynchronizedRootGroup` のため新規 `.swift` 配置でも `project.pbxproj` 編集不要）/ String Catalog（`.xcstrings`）/ XCTest。

**Spec:** `docs/superpowers/specs/2026-06-01-issue-107-default-task-name-i18n-design.md`

---

## File Structure

| ファイル | 役割 | 操作 |
| --- | --- | --- |
| `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift` | `defaultTaskNames` 単一定義・`defaultNameLocalizations`・`displayName` | Modify |
| `app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift` | passthrough / membership 契約テスト | Modify |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | デフォルト 10 件 + 「選択」の en 翻訳 | Modify |
| `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift` | 追加 11 キーの en 存在検証 | Modify |
| 表示 8 ファイル（Task 3 に列挙） | `task.name` → `displayName` | Modify |

## English 翻訳 draft（#50: 在外日本人/バイリンガル家庭向け。spot review 対象）

| ja（catalog キー） | en（draft） |
| --- | --- |
| 下の子の面倒を見る | Look after younger sibling |
| お風呂を入れる | Run the bath |
| 食器を出す | Set out the dishes |
| 食器を片付ける | Clear the dishes |
| お片付けする | Tidy up |
| 玄関の靴を並べる | Line up shoes at the door |
| ゴミ出しのお手伝い | Help take out the trash |
| 洗濯物を運ぶ | Carry the laundry |
| テーブルを拭く | Wipe the table |
| 自分の部屋の掃除 | Clean my room |
| 選択 | Select |

---

## Task 1: `HelpTask.displayName` と単一 source 化

**Files:**

- Modify: `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift`
- Test: `app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift`

- [ ] **Step 1: 失敗するテストを書く（locale 非依存の契約）**

`HelpTaskTests.swift` の `testDefaultHelpTasks()` の直後に追記する。

```swift
func testDisplayNamePassesThroughUserCreatedTask() {
    // ユーザー作成タスク（free text）は翻訳せず verbatim
    let task = HelpTask(id: UUID(), name: "ユーザー独自タスク", isActive: true)
    XCTAssertEqual(task.displayName, "ユーザー独自タスク")
}

func testEveryDefaultNameHasLocalizationEntry() {
    // 既知デフォルト名はすべて翻訳マップに登録されている（locale 非依存）
    XCTAssertTrue(
        HelpTask.defaultTaskNames.allSatisfy { HelpTask.defaultNameLocalizations[$0] != nil },
        "defaultTaskNames の全件が defaultNameLocalizations にエントリを持つべき"
    )
    XCTAssertEqual(HelpTask.defaultTaskNames.count, 10)
}
```

- [ ] **Step 2: テストを実行して fail（コンパイルエラー）を確認**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/HelpTaskTests 2>&1 | grep -E "error:|BUILD FAILED|TEST FAILED" | head
```

Expected: `BUILD FAILED`（`displayName` / `defaultTaskNames` / `defaultNameLocalizations` 未定義）。CLAUDE.md「TDD red skip 条件 (a) コンパイルエラー確定」に該当するため、ここはコンパイル fail の確認のみで可。

- [ ] **Step 3: 最小実装（`defaultTasks()` を単一 source に refactor）**

`HelpTask.swift` の `defaultTasks()` を以下に置き換え、`displayName` を追加する。

```swift
static let defaultTaskNames: [String] = [
    "下の子の面倒を見る",
    "お風呂を入れる",
    "食器を出す",
    "食器を片付ける",
    "お片付けする",
    "玄関の靴を並べる",
    "ゴミ出しのお手伝い",
    "洗濯物を運ぶ",
    "テーブルを拭く",
    "自分の部屋の掃除"
]

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

static func defaultTasks() -> [HelpTask] {
    return defaultTaskNames.map { name in
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10)
    }
}

var displayName: String {
    guard let resource = HelpTask.defaultNameLocalizations[name] else {
        return name // ユーザー作成・改名済みデフォルトは verbatim
    }
    return String(localized: resource) // en→翻訳 / ja→no-op
}
```

`var displayName` は `struct HelpTask` 本体内（`updateCoinRate` の後あたり）に置く。`defaultTaskNames` / `defaultNameLocalizations` / `defaultTasks()` は `static` メンバとして本体内に置く。

- [ ] **Step 4: テストを実行して pass を確認**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/HelpTaskTests 2>&1 | tee /tmp/t1.log | grep -E "Test Suite .* (passed|failed)|\*\* TEST"
grep -E "^\*\* TEST (SUCCEEDED|FAILED)" /tmp/t1.log
```

Expected: `** TEST SUCCEEDED **`（`testDefaultHelpTasks` 含め全 PASS。`defaultTasks()` の名前・順序は不変なので既存テストも green）。

> 注: background 実行時は CLAUDE.md「background test exit code 罠」に従い、log 末尾の `** TEST SUCCEEDED/FAILED **` を `grep` で必ず確認する。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/HelpTask.swift app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift
git commit -m "feat(#107): HelpTask.displayName で固定デフォルト名を表示時 i18n

defaultTaskNames を単一 source 化し、defaultNameLocalizations
(ja原文キー→LocalizedStringResource) で表示時に翻訳読み替え。
ユーザー作成タスクは verbatim。DB・migration には触れない。"
```

---

## Task 2: xcstrings に 11 キー追加 + catalog テスト

**Files:**

- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`

> 既存 catalog テストは特定キー群のみ検証し「全キー en 網羅」チェックは無いため、追加 11 キー専用の en 存在テストを新設する（red→green アンカー）。テストは catalog JSON を直接読むため locale 非依存（CLAUDE.md「`String(localized:)` 再計算トラップ」を回避）。

- [ ] **Step 1: 失敗するテストを書く**

`LocalizationStringCatalogTests.swift` の末尾メソッド群に追記する。`strings`（既存の解析済みプロパティ）を利用する。

```swift
func testDefaultHelpTaskNamesHaveEnglishTranslation() {
    // Given: 翻訳対象（デフォルト10件 + bulk選択ラベル）
    let requiredKeys = HelpTask.defaultTaskNames + ["選択"]

    // Then: 各キーが en の translated 値を持つこと
    for key in requiredKeys {
        let en = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
        let enUnit = (en?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
        let value = enUnit?["value"] as? String
        XCTAssertNotNil(value, "キー '\(key)' に en 翻訳が必要")
        XCTAssertFalse((value ?? "").isEmpty, "キー '\(key)' の en 翻訳が空であってはならない")
    }
}
```

> `strings` の具体的な型（`[String: Any]` か独自 struct か）は `LocalizationStringCatalogTests.swift` 冒頭の定義に合わせる。既存テスト（`testViewModelErrorMessageKeysExist` 等）の `strings[...]` アクセス方法を mirror すること。

- [ ] **Step 2: テストを実行して fail を確認**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests/testDefaultHelpTaskNamesHaveEnglishTranslation 2>&1 | tee /tmp/t2.log
grep -E "^\*\* TEST (SUCCEEDED|FAILED)" /tmp/t2.log
```

Expected: `** TEST FAILED **`（11 キーが catalog 未登録のため `XCTAssertNotNil` で fail）。これは behavioral fail なので **必ず実行**して red を確認する。

- [ ] **Step 3: xcstrings に 11 キーを追加**

REQUIRED SUB-SKILL: `xcstrings-bulk-update` を使う（Python `json.dump` は Xcode の `" : "` 整形を壊し diff を膨張させるため使わない）。`sourceLanguage` は `ja` なので **en localization のみ**追加する（既存「選択中」と同形式）。追加する 11 エントリ（キー→en value）は本 plan 冒頭「English 翻訳 draft」表のとおり。各エントリの形:

```json
"選択": {
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Select" } }
  }
}
```

追加後、JSON が valid か確認:

```bash
python3 -c "import json; json.load(open('app/OtetsudaiCoin/Resources/Localizable.xcstrings')); print('valid JSON')"
```

- [ ] **Step 4: テストを実行して pass を確認**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests 2>&1 | tee /tmp/t2b.log
grep -E "^\*\* TEST (SUCCEEDED|FAILED)" /tmp/t2b.log
```

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "feat(#107): デフォルトお手伝い名10件 + 「選択」の en 翻訳を追加

String Catalog に en localization を追加し、追加キーの en 存在を
LocalizationStringCatalogTests で担保。「選択」は TaskCardView の
bulk 選択ラベルの en 欠落修正（UI層・データ層機構とは独立）。"
```

---

## Task 3: 表示 8 面を `task.name` → `displayName` に差し替え

**Files（すべて Modify）:**

- `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift:65`
- `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift:171`
- `app/OtetsudaiCoin/Presentation/Components/RecordButtonBar.swift:39`
- `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:83, 115, 214`
- `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:51, 317`
- `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:446`
- `app/OtetsudaiCoin/Presentation/ViewModels/MonthlyRetrospectiveViewModel.swift:134`

> TDD からの逸脱（理由明記）: これらは表示専用の差し替えで、テスト既定 locale（ja）では `displayName == name`（no-op）のため観測可能な振る舞い差が出ず、意味のある unit red を書けない。logic（`displayName` 自体）は Task 1 で担保済み。本 Task はビルド成功・既存テスト green・grep 網羅確認・Task 4 の en 視覚検証で担保する。`record.task` は `HelpRecordWithDetails.task`（= `HelpTask`）なので `displayName` が到達する。

- [ ] **Step 1: 各サイトを編集（old → new）**

```text
TaskCardView.swift:65        Text(task.name)                       → Text(task.displayName)
HelpRecordEditView.swift:171 Text(task.name)                       → Text(task.displayName)
RecordButtonBar.swift:39     「\(selectedTask.name)」              → 「\(selectedTask.displayName)」
TaskManagementView.swift:83  \(taskToDelete?.name ?? "")          → \(taskToDelete?.displayName ?? "")
TaskManagementView.swift:115 Text(task.name)                       → Text(task.displayName)
TaskManagementView.swift:214 taskName = task.name                  → taskName = task.displayName
HelpHistoryView.swift:51     「\(record.task.name)」              → 「\(record.task.displayName)」
HelpHistoryView.swift:317    Text(record.task.name)                → Text(record.task.displayName)
RecordTutorialView.swift:446 Text(task.name)                       → Text(task.displayName)
MonthlyRetrospectiveViewModel.swift:134  name: task.name          → name: task.displayName
```

`TaskManagementViewModel.swift` の sort(32) / dup-check(59) / save(103) と DebugLogger 呼び出し（`HelpRecordEditViewModel` 84/86/143）は **変更しない**（logic / ログは raw `name`）。

- [ ] **Step 2: ビルド + 全テスト実行**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tee /tmp/t3.log
grep -E "^\*\* TEST (SUCCEEDED|FAILED)" /tmp/t3.log
```

Expected: `** TEST SUCCEEDED **`（既存 View テスト含め全 green）。

- [ ] **Step 3: 差し替え漏れの grep 検証**

Run:

```bash
grep -rn "task\.name\|selectedTask\.name\|record\.task\.name" \
  app/OtetsudaiCoin/Presentation --include="*.swift" \
  | grep -v "displayName" | grep -E "Text\(|「|name:.*task" 
```

Expected: 出力なし（表示系の `task.name` が残っていない）。`TaskManagementViewModel` の logic 系（`$0.name` / `name: task.name` の save）は対象外なのでヒットしてもよいが、`Text(...)` / 表示モデル構築の残存が無いことを目視する。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoin/Presentation
git commit -m "feat(#107): 表示8面を task.name → displayName に差し替え

list/記録/履歴/振り返り/チュートリアル/削除確認/編集欄で
displayName を表示。logic(sort/dedup/save) と DebugLogger は
raw name のまま据え置き。"
```

---

## Task 3.5: 編集欄の無変更保存で元 ja 名を保護（コードレビュー由来の第3案）

> 経緯: Task 3 のコード品質レビューが「編集欄 en 表示 → 無変更保存で ja 名が en 文字列に黙って上書き・cross-locale で英語表示」を Important 指摘。user 判断で「表示 en・無変更は保護」（第3案）を採用。spec § 編集欄の挙動を参照。

**Files:**

- Modify: `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift`（`resolvePersistedName` 追加）
- Test: `app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift`（`updateTask()` の `name:` を helper 経由に）

- [ ] **Step 1: 失敗するテストを書く（locale 非依存）**

```swift
func testResolvePersistedNameUsesEditedTextWhenChanged() {
    let original = HelpTask(id: UUID(), name: "下の子の面倒を見る", isActive: true)
    XCTAssertEqual(HelpTask.resolvePersistedName(editedText: "新しいタスク名", original: original), "新しいタスク名")
}

func testResolvePersistedNameKeepsOriginalWhenUnchanged() {
    // 表示値(displayName)のまま無変更保存 → 元の保存名(name)を維持
    let original = HelpTask(id: UUID(), name: "テーブルを拭く", isActive: true)
    XCTAssertEqual(HelpTask.resolvePersistedName(editedText: original.displayName, original: original), "テーブルを拭く")
}

func testResolvePersistedNameTrimsWhitespace() {
    let original = HelpTask(id: UUID(), name: "お片付けする", isActive: true)
    XCTAssertEqual(HelpTask.resolvePersistedName(editedText: "  片付け  ", original: original), "片付け")
}
```

- [ ] **Step 2: red 確認**（`resolvePersistedName` 未定義 → BUILD FAILED。コンパイルエラー確定のため確認のみで可）

- [ ] **Step 3: 実装**

`HelpTask.swift` に追加:

```swift
/// 編集フォームの保存名を解決する。表示値(displayName)のまま無変更で保存された場合は
/// 元の保存名(name)を維持し、デフォルト名のロケール追従(翻訳)を壊さない。
static func resolvePersistedName(editedText: String, original: HelpTask) -> String {
    let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed == original.displayName ? original.name : trimmed
}
```

`TaskManagementView.swift` の `updateTask()`（~236）:

```swift
// before: name: taskName.trimmingCharacters(in: .whitespacesAndNewlines),
name: HelpTask.resolvePersistedName(editedText: taskName, original: editingTask),
```

`addTask()`（新規作成、~224）は `editingTask` が無いので変更しない（free text のまま）。

- [ ] **Step 4: green 確認**（HelpTaskTests + 全スイート。既知の date flake `testFilterRecordsForChildInCurrentMonth` を除き green）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/HelpTask.swift app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift
git commit -m "feat(#107): 編集欄の無変更保存で元 ja 名を保護

displayName のまま無変更保存された場合は元の name(ja)を維持し、
デフォルト名のロケール追従を壊さない。コード品質レビュー指摘
(無変更保存で ja→en 上書き) への対応 (第3案)。"
```

## Task 4: en ロケ視覚検証

**Files:** 検証のみ（コード変更なし。スクショ更新分は任意 commit）

- [ ] **Step 1: ASC スクショ撮影で en 表示を確認**

Run:

```bash
./scripts/capture-asc-screenshots.sh
```

- [ ] **Step 2: en/02-record.png を目視確認**

`docs/screenshots/asc/v1.1.x/en/02-record.png` の Today's Help カードがデフォルトタスク名 en（"Run the bath" 等）で表示されることを Read で確認。ja/02-record.png は従来どおり ja 表示（regression なし）。

- [ ] **Step 3: 更新スクショを任意 commit**

en スクショが改善したら ASC 提出物更新として commit する（#50 の en ストア品質向上に寄与）。

```bash
git add docs/screenshots/asc/v1.1.x
git commit -m "docs(#107): デフォルトタスク名 en 化後の ASC en スクショ更新"
```

---

## Task 5: PR 作成

- [ ] **Step 1: push + PR 作成**

CLAUDE.md ルール: push 直前に `git status` で HEAD ブランチ（`feat/issue-107-default-task-name-i18n`）再確認、`gh pr list --head <branch>` で既存 PR 重複確認。

```bash
git status -sb
gh pr list --head feat/issue-107-default-task-name-i18n
git push -u origin feat/issue-107-default-task-name-i18n
```

- [ ] **Step 2: PR description に以下を含める**

- 案A（表示時ルックアップ、DB・migration なし）採用理由
- en 翻訳 11 件（spot review 依頼。本 plan の draft 表を貼る）
- **スコープ外**: `SampleDataService` の ja サンプル名（preview/UIテスト専用、別観点）
- **既知の軽微な帰結**: dup-check / sort は raw ja のまま（cosmetic・低確率の重複行）
- **Plan からの逸脱**: Task 3 の TDD red skip 理由（表示専用 no-op swap）
- `Closes #107`

---

## Self-Review

- **Spec coverage**: 案A `displayName`（Task 1）/ xcstrings 翻訳（Task 2）/ 表示 8 面差し替え（Task 3）/ 編集欄 en 表示（Task 3 Step1 の :214）/「選択」同梱（Task 2）/ SampleData スコープ外（Task 5）/ locale 非依存テスト（Task 1, 2）/ 視覚検証（Task 4）→ 全 spec 項目に対応タスクあり。
- **Spec 訂正**: spec § テスト戦略の「既存網羅テストで自動担保」は不正確（網羅チェック不在）。Task 2 で専用テスト新設に変更。spec 側も同趣旨に修正する。
- **Placeholder scan**: 各 code step に実コードあり。`strings` の型のみ実装時に既存定義へ合わせる注記（既存 mirror で解決可）。
- **Type consistency**: `displayName` / `defaultTaskNames` / `defaultNameLocalizations` は Task 1 定義と Task 2・3 参照で名称一致。
