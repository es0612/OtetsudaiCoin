# #265 項目 3・5: AX の記録タブのカード幅をそろえ、撮影テストを整える Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AX サイズの記録タブで 1 列のタスクカードを列いっぱいの同じ幅にそろえ、撮影テストの小さな不整合 (型・コメント・待ち時間・ボタンの選び方) を直し、間欠的な失敗 2 件は再現を確かめてから扱う。

**Architecture:** `TaskCardView` にチュートリアル (#253 / PR #259) と同じ static pure helper `cardMaxWidth(isAccessibilitySize:)` を足し、`@Environment(\.dynamicTypeSize)` で配線する。判定は unit test、見た目は `capture-verification-screenshots.sh` の AX 最大 / 既定サイズの撮影で確かめる。項目 5 はアプリ 2 ファイルとテスト 1 ファイルの整理。

**Tech Stack:** SwiftUI, XCTest, XCUITest, ViewInspector 0.10.2, iPhone 17 Pro Max simulator (`110B1CD3-3A7D-4C40-A615-090A263067A2`)

**Spec:** issue #265 の項目 3・5 と、2026-10-24 の triage でオーナーが選んだ範囲 (このファイル末尾の「範囲」)

## Global Constraints

- 既定サイズ (AX でない) の見た目は変えない。既定サイズの撮影は main と pixel-identical (`compare-screenshots.sh` の既知ノイズ 00 / 03 / 05 / 06 / 07 / 08 / 09 を除く)
- AX 最大の記録タブで、1 列のタスクカードはすべて同じ幅 (いまは 230 / 280 / 329pt の 3 種類)
- xcodebuild は FOREGROUND で実行し、合否は `grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` の判定行で読む (exit code や tail で判定しない)
- simulator は `-destination id=110B1CD3-3A7D-4C40-A615-090A263067A2` (iPhone 17 Pro Max)
- 撮影の出力 (`docs/screenshots/verification/`) は gitignored。commit しない
- 間欠的な失敗には、再現と原因の確認なしに `sleep` / timeout を足さない (CLAUDE.md「対応案を鵜呑みにしない」)

## Review Focus

1. 既定サイズの 2 列は `cardMaxWidth == nil` のまま変わらないこと → Task 1 の unit test と既定サイズの pixel 比較
2. 一括モード (選択中の表示がある) のカードも AX で同じ幅になること → Task 1 Step 6 で `22-record-tasks-bulk` を目視
3. 選択中のカードの `scaleEffect(1.05)` で、列いっぱいのカードが画面の端からはみ出さないこと → Task 1 Step 6 で `21-record-tasks-*` の選択中のカードを目視 (はみ出したら STOP してオーナーに見せる)
4. チュートリアルの裏の記録タブにも「記録する」があり、ラベルの完全一致だと裏のボタンを掴むことがある → Task 2 の helper が hittable な要素だけを返す
5. `.id` を非 Optional にしても、AX の自動スクロール (verify-19 / 23 / 24 / 25) が今までどおり効くこと → Task 2 Step 4 で AX 最大の `testCaptureTutorialSteps` を流す

---

### Task 1: AX サイズで記録タブのタスクカードを列いっぱいにそろえる (項目 3)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift:3-33`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift`

**Interfaces:**
- Produces: `static func cardMaxWidth(isAccessibilitySize: Bool) -> CGFloat?` on `TaskCardView` (AX で `.infinity`、既定で `nil`。`TutorialTaskCardView.cardMaxWidth` と同じ値)

- [ ] **Step 0: 既定サイズの before を撮る (main と同じコード)**

```bash
/bin/bash scripts/capture-verification-screenshots.sh --appearance light
cp -R docs/screenshots/verification/light "$SCRATCH/before-default"
```

Expected: `** TEST SUCCEEDED **`。AX 最大の before は triage で撮影済み (`219dcfc`、21-record-tasks-p2 / p4 でカード幅 230 / 280 / 329pt)。

- [ ] **Step 1: 失敗するテストを書く**

`TaskCardViewTests` に追加する:

```swift
func test_cardWidth_followsContent_atDefaultSizes() {
    XCTAssertNil(TaskCardView.cardMaxWidth(isAccessibilitySize: false))
}

func test_cardWidth_fillsTheColumn_atAccessibilitySizes() {
    XCTAssertEqual(TaskCardView.cardMaxWidth(isAccessibilitySize: true), .infinity)
}
```

- [ ] **Step 2: 失敗を確かめる** — red はコンパイルエラー確定 (`cardMaxWidth` 未定義) なので実行を省略してよい。省略したら commit メッセージに理由を書く (CLAUDE.md の red skip 条件 (a))

- [ ] **Step 3: 実装する**

`TaskCardView` に `@Environment(\.dynamicTypeSize) private var dynamicTypeSize` と `static func cardMaxWidth(isAccessibilitySize: Bool) -> CGFloat?` を足し、`.padding()` と `.frame(minHeight: 150)` のあいだに `.frame(maxWidth: Self.cardMaxWidth(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize))` を入れる (`background` より前。順番は `RecordTutorialView.swift:587-592` と同じ)。helper のコメントは `RecordTutorialView.swift:507` に合わせ「#265: 1 列にすると幅が名前の長さでばらばらになるため、AX サイズでは列いっぱいにそろえる」。

- [ ] **Step 4: unit を流す**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination id=110B1CD3-3A7D-4C40-A615-090A263067A2 \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests -only-testing:OtetsudaiCoinTests/RecordViewTests \
  > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 既定サイズの after を撮って比べる**

```bash
/bin/bash scripts/capture-verification-screenshots.sh --appearance light
/bin/bash scripts/compare-screenshots.sh "$SCRATCH/before-default" docs/screenshots/verification/light
```

Expected: 既知ノイズ (00 / 03 / 05 / 06 / 07 / 08 / 09) 以外はすべて `identical` か `status-bar-only`。記録タブ (02 / 20 / 21 / 22) が `differs` なら Global Constraints 違反なので STOP。

- [ ] **Step 6: AX 最大の after を撮って測る**

```bash
/bin/bash scripts/capture-verification-screenshots.sh --appearance light --content-size accessibility-extra-extra-extra-large
```

`21-record-tasks-p*` と `22-record-tasks-bulk` を Read で目視し、カードの左右の端の x を測る。Expected: すべてのカードが同じ幅 (目安: 今いちばん広い 329pt 前後。**未実測の推定**)。選択中のカード (1.05 倍) が画面の端で切れていないこと (Review Focus 3)。切れていたら STOP し、撮影結果だけをオーナーに見せる (推奨は付けない)。

- [ ] **Step 7: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift
git commit -m "fix(#265): AX サイズで記録タブのタスクカードを列いっぱいの同じ幅にそろえる"
```

### Task 2: 撮影テストとスクロール先の小さな不整合を直す (項目 5 の 4 点)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:277-281`
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/TutorialStepContainer.swift:11-13`
- Modify: `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift:134-136, 485-550`

**Interfaces:**
- Consumes: `TutorialTaskCardView.recordActionScrollTarget(placement:selectedTaskID:) -> String?` (変更しない)
- Produces: `private func hittableRecordButton(in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement?` (テストクラス内)

- [ ] **Step 1: `.id` の型をそろえる** — `RecordTutorialView.swift:278` を `if showsRecordActionBelow(task), let target = recordActionScrollTarget { recordActionPanel.id(target) }` にし、`.id(String)` と `scrollTo(String)` の型を一致させる。`showsRecordActionBelow` が true なら target は必ず非 nil なので、表示条件は変わらない。

- [ ] **Step 2: コメントを絞る** — `TutorialStepContainer.swift:11-13` の「`.id(step)` で、ステップが変わるたびにスクロール位置を先頭へ戻す」を「本文が収まらず `ScrollView` が選ばれたときだけ、`.id(step)` でステップごとにスクロール位置を先頭へ戻す」に直す (`ViewThatFits` が VStack を選んだときはスクロールしないため)。

- [ ] **Step 3: UITest helper を整える**
  - `tapHittableButton` の最初の存在待ちを `waitForExistence(timeout: 10)` から `2` にする。理由をコメントで 1 行残す: 一番下のカードは LazyVGrid がスクロールするまで作らないので、10 秒待っても現れず、毎回スワイプの前に 10 秒を失う
  - `hittableRecordButton(in:timeout:)` を足す: `label == "記録する"` の buttons から `isHittable` のものを、timeout まで 0.5 秒ごとに探して返す (無ければ nil)。チュートリアルの裏の記録タブにも同じラベルのボタンがあるため
  - `:486-550` の `app.buttons["記録する"]` による 4 つの assert を `XCTAssertNotNil(hittableRecordButton(in: app), "... buttons=\(...)")` に置き換え、失敗時に `記録する` ラベルの全要素の `frame` / `isHittable` を dump する。verify-25 の前提 (`XCTAssertFalse(... maxY <= windowBottom)`) は「hittable な `記録する` があり、その maxY が windowBottom 以下」ではないこと、に書き換える。`shift` の計算に使う frame も hittable 要素から取り、取れなければ `XCTFail` で止める

- [ ] **Step 4: 既定サイズと AX 最大で `testCaptureTutorialSteps` を流す**

```bash
/bin/bash scripts/capture-verification-screenshots.sh --appearance light
/bin/bash scripts/capture-verification-screenshots.sh --appearance light --content-size accessibility-extra-extra-extra-large
```

Expected: どちらも `** TEST SUCCEEDED **`。AX 最大では verify-25 が skip されず走ったこと (xcresult に `skip verify-25` の activity が無いこと) を確かめる。

- [ ] **Step 5: helper の検出力を mutation で確かめる** — `TutorialStepContainer.swift:42` の `proxy.scrollTo(target, anchor: .bottom)` を一時的にコメントアウトし、AX 最大で `testCaptureTutorialSteps` が `記録する not on screen after selecting 自分の部屋の掃除` (verify-23。一番下のカードの帯は自動スクロールなしでは画面外) で FAIL することを確認 → revert して GREEN に戻す。`hittableRecordButton` が画面外のボタンを nil と判定できること = helper の差し替えで assert が甘くなっていないことの確認 (CLAUDE.md の mutation 検証)。verify-19 が先に落ちてもよい (どちらも同じ helper)

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift app/OtetsudaiCoin/Presentation/Views/Tutorial/TutorialStepContainer.swift app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift
git commit -m "chore(#265): スクロール先の型・コメント・撮影テストの待ち時間と「記録する」の選び方を整える"
```

### Task 3: 間欠的な失敗 2 件の再現を確かめる (項目 5 の残り)

**Files:** なし (再現したときだけ、STOP の後に決める)

- [ ] **Step 1: 既定サイズでクラスを 3 回通す**

```bash
for i in 1 2 3; do /bin/bash scripts/capture-verification-screenshots.sh --appearance light > "$SCRATCH/flake-default-$i.log" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$SCRATCH/flake-default-$i.log"; done
```

- [ ] **Step 2: AX 最大でクラスを 2 回通す** (`tapCardAboveRecordBar` の選択失敗の再現。Task 2 Step 4 の 1 回と合わせて 3 回)

- [ ] **Step 3: 判断**
  - 5 回とも通った → コードは変えない。「Task 2 後のブランチで既定 3 回 / AX 3 回、再現 0 回」を issue に記録する
  - 1 回でも失敗した → STOP。失敗したテスト名・xcresult の failure message・その時点の撮影をオーナーに見せ、`superpowers:systematic-debugging` で原因を確かめる提案をする (この plan の中で wait を足さない)

### Task 4: 記録と PR

- [ ] **Step 1:** 全 unit を流す (`-only-testing:OtetsudaiCoinTests`)。Expected: `** TEST SUCCEEDED **`
- [ ] **Step 2:** 最終 whole-branch レビュー (CLAUDE.md: inline 実行でも省略しない)
- [ ] **Step 3:** PR を作る。本文に「範囲」の表、カード幅の before / after の数値、既定サイズの比較結果、Task 3 の再現回数を書く。項目 4・6 の扱い (下の「範囲」) は PR merge 後に #265 へコメントし、#265 を close する

## 範囲 (2026-10-24 triage でオーナーが決定)

| 項目 | 扱い |
| --- | --- |
| 3 カード幅 | この plan の Task 1 |
| 4 2 人目の子どもカードのはみ出し | 判断済み (#264 の plan で「子どもカードは中身の幅」を選んだときのトレードオフ)。直さない。子ども 3 人以上の確認は未実施として記録 |
| 5 テストの整備 | Task 2・3 |
| 6 AX 最大で swipeUp が効かない | 調査しない。撮影テストはドラッグで回避済み、ほかに swipeUp を必要とする箇所なし。「原因は未調査」と記録 |
| リリース | 1.1.6 |
