# #308 PR 2 チュートリアルと子どもフォームの英語表示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 英語表示のチュートリアル（子ども・記録）と子どもフォームのプレビューで、日本語のまま出ている文言を英語にし、検証撮影でチュートリアルを en でも撮れるようにする。

**Architecture:** PR 1（#315）と同じ方針 (a)。`String` で受けて `Text(title)` と書いている 4 部品の引数を `LocalizedStringKey` にし、呼び出し側のリテラルはそのままで翻訳を引かせる。`ChildFormView` の三項演算子は枝ごとに `Text("…")` / `Text(verbatim:)` に分ける。撮影テストは、チュートリアルのボタンを日本語の文言ではなく、チュートリアル専用の accessibility identifier で探す。

**Tech Stack:** SwiftUI / ViewInspector / XCTest・XCUITest / String Catalog (`Localizable.xcstrings`)

**Spec:** issue #308 §1（`gh issue view 308`）と、PR 1 の設計 `docs/superpowers/specs/2026-11-22-issue-308-statistics-card-unpaid-banner-design.md`（方針 (a) はオーナー決定 2026-11-22）。この PR は PR 1 の spec で「PR 2」とした残り。

## Global Constraints

- 方針: 部品の引数を `LocalizedStringKey` にする（オーナー決定）。呼び出し側で `String(localized:)` を書く案は採らない
- ja の表示を変えない（アンチゴール）。既存の en 訳も変えない（例: 「お手伝いを選択」= "Select Help" の見直しは #155 と一緒に考える）
- 非ゴール: `Text(String変数)` を検出する lint（#306）／AX サイズで文字が切れる件（#151）／チュートリアル以外で `skipUnlessJapanese()` している撮影テスト 5 本の en 化
- xcstrings はキーを並べ直さず、既存の並びへ差し込む（グローバル skill `xcstrings-bulk-update` の 145・146 行）
- View テストは project skill `writing-swiftui-view-tests`、テストの実行・判定は `running-xcodebuild-tests-and-date-fixtures` に従う
- xcodebuild は FOREGROUND、合否は `** TEST SUCCEEDED **` の行で判定（exit code で判定しない）。simulator は `iPhone 17 Pro Max` を UDID で指定（`/bin/bash -c 'source scripts/lib/common.sh && JQ=$(resolve_jq) && resolve_udid "iPhone 17 Pro Max"'`）
- unit テストのコマンド（以下 `UNIT_CMD`）: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination "id=<udid>" -parallel-testing-enabled NO -only-testing:OtetsudaiCoinTests`（クラスを絞るときは `-only-testing:OtetsudaiCoinTests/<Class>` を重ねる）。main の時点で 623 件

## 決めたこと（Claude の判断。PR で示す）

1. catalog に無い 3 キーの en 訳（PR 1 と同じく「chore」で揃える）
   - `記録する子を選びます` → `Choose the child to record`
   - `がんばったタスクを選択` → `Pick the chore they did`
   - `コインを獲得！` → `Earn coins!`
2. 撮影テスト用の identifier（チュートリアル専用の名前にして、裏の記録タブ・ホームの同じラベルと取り違えない）

   | 要素 | 場所 | identifier |
   | --- | --- | --- |
   | 子どもチュートリアルの「戻る」 | `ChildTutorialView.swift:216` | `child_tutorial_back_button` |
   | 子どもチュートリアルの「次へ／完了」 | `ChildTutorialView.swift:226` | `child_tutorial_next_button` |
   | 記録チュートリアルの「戻る」 | `RecordTutorialView.swift:453` | `record_tutorial_back_button` |
   | 記録チュートリアルの「次へ／開始」 | `RecordTutorialView.swift:463` | `record_tutorial_next_button` |
   | 記録チュートリアルの「記録する」 | `RecordTutorialView.swift:319-327` の Button | `tutorial_record_button` |
   | お手伝いカード | `TutorialTaskCardView` の Button | `tutorial_task_card_\(task.name)`（表示名ではなく保存名。en でも同じ） |

## Review Focus

1. **子どもの名前が catalog のキーと同じ**（例: 名前「ホーム画面」）: en のフォームのプレビューでも名前はそのまま「ホーム画面」と出る（英訳されない）→ Task 2 のテスト
2. **ja の表示が変わらない**: 4 部品とフォームのプレビューを ja で描画すると、今までと同じ日本語 → Task 1・2 のテスト
3. **Preview や他の呼び出しのリテラルが、en 訳のないキーとして抜き出される**（PR 1 で最終レビューが見つけた罠）: ビルド後の `ChildTutorialView` / `RecordTutorialView` / `ChildFormView` の `.stringsdata` のキーが全部 catalog にあり en 訳を持つ（既存の `Loading...` 1 件は main からある差。増えないこと）→ Task 3 の Step
4. **identifier を付けたボタンを、ラベルで探している既存の機能 UI テスト**（`OtetsudaiCoinUITests.swift:31-33` が `app.buttons["開始"/"完了"/"次へ"]`）: identifier を付けた後も通る → Task 3 の Step
5. **AX サイズの再タップ経路（verify-25）**: 「戻る」の frame とカードの探し方を identifier に変えた後も、en・AX 最大で 25 まで撮れる → Task 3 の Step

---

### Task 1: チュートリアルの 4 部品を LocalizedStringKey にする

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift:248-300`（`FeatureRow` / `TutorialStep`）
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:613-660`（`RecordFeatureRow` / `CompletionFeature`）
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`
- Create: `app/OtetsudaiCoinTests/Presentation/Views/TutorialComponentsTests.swift`
- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`（PR 1 の `testStatisticsCardKeysHaveEnglishTranslation` の後ろ）

**Interfaces:**
- Produces: `FeatureRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey)`、`TutorialStep(number: String, title: LocalizedStringKey, description: LocalizedStringKey)`（`number` は String のまま `Text(verbatim: number)`）、`RecordFeatureRow` / `CompletionFeature` は `FeatureRow` と同じ形。呼び出し側（`ChildTutorialView.swift:98-100, 183-185`、`RecordTutorialView.swift:132-134, 418-420`）は変えない

- [ ] **Step 1: 失敗するテストを書く**

`TutorialComponentsTests`（`StatisticsCardTests` と同じ `renderedTexts(_:locale:)` の形。`findAll(ViewType.Text.self)` → `string(locale:)`）:

```swift
func test_featureRow_resolvesEnglish()       // FeatureRow("person.badge.plus", "お子様を登録", "名前や好きな色を設定") en → contains "Register Child", "Set name and favorite color"
func test_featureRow_keepsJapanese()         // 同じ部品を ja → contains "お子様を登録", "名前や好きな色を設定"
func test_tutorialStep_resolvesEnglish()     // TutorialStep("1", "記録タブを開く", "下部の「記録」ボタンをタップ") en → contains "1", "Open Record tab", "Tap the Record button at the bottom"
func test_recordFeatureRow_resolvesEnglish() // RecordFeatureRow("plus.circle", "記録ボタンをタップ", "コインを獲得！") en → contains "Tap the Record button", "Earn coins!"
func test_completionFeature_resolvesEnglish()// CompletionFeature("house.fill", "ホーム画面", "お子様の成績を確認") en → contains "Home Screen", "Check your child's progress"
```

`LocalizationStringCatalogTests.testTutorialKeysHaveEnglishTranslation()`: PR 1 の `testStatisticsCardKeysHaveEnglishTranslation` と同じ形（存在・stale でない・en が空でない・指定があれば完全一致）。対象は呼び出し側の 23 キー（`ChildTutorialView.swift:98-100, 183-185` と `RecordTutorialView.swift:132-134, 418-420` の title / description）。完全一致を指定するのは「決めたこと 1」の 3 キーだけ。

- [ ] **Step 2: RED を確かめる**

Run: `UNIT_CMD -only-testing:OtetsudaiCoinTests/TutorialComponentsTests -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: `** TEST FAILED **`。en のテストは日本語のまま描画されて FAIL（`test_featureRow_keepsJapanese` は通ってよい）、catalog のテストは「3 キーが無い・18 キーが stale」で FAIL（23 キーのうち `お子様を選択`・`お手伝いを選択` は他の画面でも使われていて stale でない）。コンパイルは通る（リテラルは String にも渡せる）ので、この RED は省略しない

- [ ] **Step 3: 4 部品の `title` / `description` を `LocalizedStringKey` にする**

`TutorialStep.number` は `Text(verbatim: number)` にする（数字にキー抽出をかけない）。`#Preview` は 4 部品を直接呼んでいないので変更不要（Task 3 の stringsdata 照合で確かめる）。

- [ ] **Step 4: catalog を直す**

`xcstrings-bulk-update` の手順で、3 キーを既存の並びへ差し込み（en は「決めたこと 1」）、18 キーの `"extractionState" : "stale"` を外す。並べ直さない。`git diff --stat` で xcstrings の差分が数十行に収まることを確かめる（数百行なら並べ直している）。

- [ ] **Step 5: GREEN を確かめる**

Run: Step 2 と同じ
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Presentation/Views/TutorialComponentsTests.swift app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "fix(#308): チュートリアルの部品の文言を英語表示で翻訳する"
```

本文に RED の内容（en の描画結果、無いキー 3・stale 18）を書く。

---

### Task 2: 子どもフォームのプレビューの「お名前未入力」

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/ChildFormView.swift:87`
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`（`お名前未入力` の stale を外す）
- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`（Task 1 の `testTutorialKeysHaveEnglishTranslation` の辞書に `"お名前未入力": nil` を足す。名前は `testTutorialAndChildFormKeysHaveEnglishTranslation` に変える）
- Create: `app/OtetsudaiCoinTests/Presentation/Views/ChildFormViewNameTextTests.swift`（`find . -name "ChildFormView*Tests.swift" -not -path "*build*"` で既存が無いことを先に確かめる。あればそこへ足す）

**Interfaces:**
- Produces: `static func previewNameText(for name: String) -> Text`（`ChildFormView` の中）。空なら `Text("お名前未入力")`、空でなければ `Text(verbatim: name)`。`:87` はこれを呼び、続く `.font(.headline)` / `.foregroundColor(...)` はそのまま

- [ ] **Step 1: 失敗するテストを書く**

```swift
func test_emptyName_resolvesEnglish()    // previewNameText(for: "") en → "Name not entered"
func test_emptyName_keepsJapanese()      // previewNameText(for: "") ja → "お名前未入力"
func test_name_isVerbatim_evenIfKey()    // previewNameText(for: "ホーム画面") en → "ホーム画面"（catalog の "Home Screen" にならない）
```

読み方: `try ChildFormView.previewNameText(for:).inspect().text().string(locale: Locale(identifier:))`

- [ ] **Step 2: RED を確かめる**

Run: `UNIT_CMD -only-testing:OtetsudaiCoinTests/ChildFormViewNameTextTests -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: `previewNameText` が無いので BUILD FAILED（CLAUDE.md の skip 条件 (a) に当たるが、Step 4 の後に mutation を 1 回行う: helper を `Text(name.isEmpty ? "お名前未入力" : name)` に戻すと `test_emptyName_resolvesEnglish` が FAIL、`Text(LocalizedStringKey(name))` 相当にすると `test_name_isVerbatim_evenIfKey` が FAIL することを確かめて戻す）

- [ ] **Step 3: `previewNameText(for:)` を足して `:87` から呼び、catalog の `お名前未入力` の stale を外す**

- [ ] **Step 4: GREEN を確かめ、Step 2 の mutation を行う**

Run: Step 2 と同じ
Expected: `** TEST SUCCEEDED **`。mutation 2 種でそれぞれ 1 件 FAIL → 戻して `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/ChildFormView.swift app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Presentation/Views/ChildFormViewNameTextTests.swift app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "fix(#308): 子どもフォームの「お名前未入力」を英語表示で翻訳し、名前はそのまま出す"
```

本文に「RED は BUILD FAILED のため mutation 検証で代替」と書く。

---

### Task 3: 撮影テストでチュートリアルを en でも撮る

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift:216, 226`
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:319-327, 453, 463` と `TutorialTaskCardView`（`:488` 以降の Button）
- Modify: `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift`（ヘッダーの説明 `:28-29`、`skipUnlessJapanese` のメッセージ `:64`、`tapHittableButton` `:165`、`hittableRecordButton` / `recordButtonCandidates` `:186-202`、`testCaptureTutorial` `:712-722`、`testCaptureTutorialSteps` `:734-829`）

**Interfaces:**
- Consumes: 「決めたこと 2」の identifier
- Produces: `tapHittableButton(matching predicate: NSPredicate, in:maxSwipes:)`（今の `containing text:` 版はこれを `label CONTAINS` で呼ぶ形に残す）

- [ ] **Step 1: 「決めたこと 2」の identifier を `.accessibilityIdentifier(...)` で付ける**

ラベルは変えない（Review Focus 4）。

- [ ] **Step 2: 撮影テストを identifier で探す形に変える**

- `testCaptureTutorial` / `testCaptureTutorialSteps` の `try skipUnlessJapanese()` を外す
- `"次へ"` / `"完了"` → 子どもは `child_tutorial_next_button`、記録は `record_tutorial_next_button`。`"戻る"`（`:801` の frame も）→ `record_tutorial_back_button`
- お手伝いカード（`お風呂を入れる` / `自分の部屋の掃除`。`:811` の再タップの探し方も）→ `identifier == "tutorial_task_card_<保存名>"`
- `hittableRecordButton` / `recordButtonCandidates` → `identifier == "tutorial_record_button"`。`isHittable` で選ぶ処理は残す
- `tapHittableButton(containing: "太郎")` はそのまま（子どもの名前は en でも「太郎」）
- assert メッセージの日本語はそのままでよい
- `skipUnlessJapanese` のメッセージから「#308 の 2 本目で en 化」を外し、「日本語の文言でボタンを探すため en では撮らない」にする。ヘッダー `:28-29` に「チュートリアル（00・12・14〜19・23〜25）も en で撮る」を足す

- [ ] **Step 3: en・ja・AX で撮って一次目視する**

Run（それぞれ FOREGROUND）:
1. `/bin/bash scripts/capture-verification-screenshots.sh --appearance light --locale both --content-size large`
2. `/bin/bash scripts/capture-verification-screenshots.sh --appearance light --locale en --content-size accessibility-extra-extra-extra-large`

Expected: どちらも `** TEST SUCCEEDED **`。1 の en で 00・12・14〜19・23・24 が撮れ、12・14〜19 に日本語の文言が 0 件（子どもの名前を除く）。1 の ja の 12・14〜19・23・24 は main で撮った before と見た目が同じ（status bar のみ。before は Task 1 の前に `git stash` か main の worktree で同じコマンドを流して取る）。2 で 25 まで撮れる（文字が切れていても #151 の範囲なので記録だけする）

- [ ] **Step 4: 機能 UI テストと stringsdata を確かめる**

1. Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination "id=<udid>" -parallel-testing-enabled NO -only-testing:OtetsudaiCoinUITests/OtetsudaiCoinUITests` → Expected: `** TEST SUCCEEDED **`（ラベルで「次へ」などを探すテストが identifier 追加後も通る）
2. ビルド後の `ChildTutorialView.stringsdata` / `RecordTutorialView.stringsdata` / `ChildFormView.stringsdata`（`find ~/Library/Developer/Xcode/DerivedData -name '<File>.stringsdata' -newer app/OtetsudaiCoin/Resources/Localizable.xcstrings`）の `.tables[][].key` を catalog と照合 → Expected: catalog に無いキーは `Loading...` だけ（main から既にある差）、en 訳の無いキー 0 件

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift
git commit -m "chore(#308): 検証撮影でチュートリアルを en でも撮れるようにする"
```

撮影した PNG は gitignored（`docs/screenshots/verification/`）なのでコミットしない。

---

### 最後に

- [ ] `UNIT_CMD`（全件）→ `** TEST SUCCEEDED **`、件数が 623 + 本 PR で足した数
- [ ] `git diff origin/main --stat` で xcstrings の差分が数十行に収まっている
- [ ] 最終 whole-branch レビュー（inline 実行でも省略しない）
- [ ] PR 本文は `Refs #308`（2 本目で #308 の §1 は全部 done になるが、close は en の画面確認の根拠をコメントに書いてから手で行う）
