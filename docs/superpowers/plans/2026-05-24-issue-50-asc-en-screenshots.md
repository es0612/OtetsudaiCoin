# Issue #50 Phase 1 § 1.5 — ASC 英語ロケーション用スクショ撮影 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ASC 英語ロケーション用スクリーンショット 3 枚 (ja 3 枚も同時取得) を XCUITest で自動撮影し、repo 内 `docs/screenshots/asc/v1.1.x/` に配置して `RELEASE_v1.1.1_ASC_EN.md` § 7 deferred を解除する。

**Architecture:** XCUITest の 2 test method (ja / en) で同一 capture sequence を実行。launch args で locale 切替 (`-AppleLanguages '(ja|en)' -AppleLocale ja_JP|en_US`)、tab 切替は `app.tabBars.buttons.element(boundBy: index)` で language-agnostic に。各画面で `XCUIScreen.main.screenshot()` → `XCTAttachment` (`lifetime = .keepAlways`)。`scripts/capture-asc-screenshots.sh` が xcodebuild test → `xcresulttool export attachments` → `manifest.json` を jq parse → リネーム配置までを一気通貫で実行。

**Tech Stack:** XCUITest / XCTAttachment / xcrun xcresulttool (Xcode 16 標準) / jq / bash

**Spec:** `docs/superpowers/specs/2026-05-24-issue-50-asc-en-screenshots-design.md`

## Spec deviation (verify 結果)

| Spec 記述 | Verify 結果 | Plan での扱い |
| --- | --- | --- |
| § 3 "TutorialService.swift 等 (必要なら) `--uitesting` で `checkFirstLaunch()` を no-op 化" | `TutorialService.swift:25-30` で**既に対応済み** (`if ProcessInfo.processInfo.arguments.contains("--uitesting") { ... return }`) | **本 plan から除外**。PR description「## Plan からの逸脱」節に明示 |
| § 5 Commit plan 3. "(必要なら) TutorialService の `--uitesting` skip 対応" | 同上 | commit plan からも除外 |

## File Structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift` | Create | locale × tab loop で 6 attachment 撮影する XCUITest class |
| `scripts/capture-asc-screenshots.sh` | Create | xcodebuild test 実行 + xcresult から PNG 抽出 + リネーム配置までの ワンショット script |
| `docs/screenshots/asc/v1.1.x/ja/{01-home,02-record,03-settings}.png` | Create | ja 撮影結果 (reference 保存用) |
| `docs/screenshots/asc/v1.1.x/en/{01-home,02-record,03-settings}.png` | Create | en 撮影結果 (ASC アップロード対象) |
| `RELEASE_v1.1.1_ASC_EN.md` | Modify (§ 7) | deferred checkbox 解除 + image link 追記 |

---

### Task 1: ASCScreenshotUITests.swift 作成

**Files:**
- Create: `app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift`

- [ ] **Step 1: ファイル作成**

`app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift` を新規作成:

```swift
//
//  ASCScreenshotUITests.swift
//  OtetsudaiCoinUITests
//
//  Captures ASC localization screenshots (ja + en) for Issue #50 Phase 1 § 1.5.
//

import XCTest

final class ASCScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreenshots_ja() throws {
        captureScreenshots(language: "ja", locale: "ja_JP")
    }

    func testCaptureScreenshots_en() throws {
        captureScreenshots(language: "en", locale: "en_US")
    }

    private func captureScreenshots(language: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()

        // SplashScreenView は 2.5 秒 + フェードアウト 0.5 秒 で消える (SplashScreenView.swift:124)
        // 余裕を持って 4 秒待機し、tab bar 出現も待つ
        sleep(4)
        let firstTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(
            firstTab.waitForExistence(timeout: 10),
            "Home tab did not appear within 10 seconds for locale=\(locale)"
        )

        // Home tab (index 0) — 既に選択済み
        sleep(1)
        attach(name: "\(language)-01-home")

        // Record tab (index 1)
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        attach(name: "\(language)-02-record")

        // Settings tab (index 2)
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        attach(name: "\(language)-03-settings")
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: ja test を単独実行して PASS することを確認**

```bash
xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinUITests/ASCScreenshotUITests/testCaptureScreenshots_ja \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` and `Test Suite 'ASCScreenshotUITests' passed`.

失敗時:
- `Home tab did not appear within 10 seconds` → splash sleep 不足。sleep(4) → sleep(6) に増やして再試行
- tab タップ失敗 → element(boundBy: x) が見つからない。app.tabBars.buttons.count を log 出力して確認

- [ ] **Step 3: en test を単独実行して PASS することを確認**

```bash
xcodebuild test \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinUITests/ASCScreenshotUITests/testCaptureScreenshots_en \
  2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`.

ここで失敗するパターン: locale launch args が無視されている (skill SKILL.md の common mistakes 参照: `'(en)'` literal parens 必須、terminate 前提)。XCUITest は毎回 fresh launch なので terminate は不要だが、launch args の literal parens (`(en)`) が崩れていないか確認。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift
git commit -m "$(cat <<'EOF'
test(#50): ASC スクショ撮影用 XCUITest 追加

XCUITest で locale (ja/en) × tab (home/record/settings) loop し、
XCTAttachment (lifetime = .keepAlways) で 6 スクリーンショットを取得する
test class を追加。--uitesting で TutorialService が既に skip 済みなので
app コード側の修正は不要。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: capture-asc-screenshots.sh 作成 + 動作確認

**Files:**
- Create: `scripts/capture-asc-screenshots.sh`

- [ ] **Step 1: scripts/ ディレクトリの存在確認、無ければ作成**

```bash
mkdir -p scripts
```

- [ ] **Step 2: スクリプト作成**

`scripts/capture-asc-screenshots.sh`:

```bash
#!/bin/bash
# Captures ASC localization screenshots for Issue #50 Phase 1 § 1.5.
#
# Runs ASCScreenshotUITests, exports attachments from the xcresult bundle,
# and places renamed PNGs into docs/screenshots/asc/v1.1.x/{ja,en}/.
#
# Requirements:
#   - Xcode 16+ (xcrun xcresulttool export attachments)
#   - jq (brew install jq)
#   - An available iPhone 17 Pro Max simulator (6.7-inch, ASC max-size device)

set -euo pipefail

SCHEME="OtetsudaiCoin"
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro Max'
TEST_CLASS="OtetsudaiCoinUITests/ASCScreenshotUITests"
OUT_DIR="docs/screenshots/asc/v1.1.x"

TMP_ROOT="$(mktemp -d)"
RESULT_BUNDLE="$TMP_ROOT/result.xcresult"
EXTRACT_DIR="$TMP_ROOT/extracted"

echo "==> Running ASCScreenshotUITests"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_CLASS" \
  -resultBundlePath "$RESULT_BUNDLE" \
  | tail -20

echo "==> Exporting attachments from xcresult"
mkdir -p "$EXTRACT_DIR"
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$EXTRACT_DIR"

echo "==> Renaming and placing PNGs into $OUT_DIR"
mkdir -p "$OUT_DIR/ja" "$OUT_DIR/en"

# manifest.json schema:
#   [ { "testIdentifier": "...", "attachments": [
#     { "exportedFileName": "...", "suggestedHumanReadableName": "ja-01-home", ... }
#   ] } ]
jq -r '.[].attachments[] | "\(.suggestedHumanReadableName)\t\(.exportedFileName)"' \
   "$EXTRACT_DIR/manifest.json" \
  | while IFS=$'\t' read -r human export; do
      if [[ "$human" =~ ^(ja|en)-([0-9]{2})-([a-z]+) ]]; then
        lang="${BASH_REMATCH[1]}"
        num="${BASH_REMATCH[2]}"
        name="${BASH_REMATCH[3]}"
        dest="$OUT_DIR/$lang/${num}-${name}.png"
        cp "$EXTRACT_DIR/$export" "$dest"
        echo "  $human → $dest"
      else
        echo "  (skip non-screenshot attachment: $human)"
      fi
    done

echo "==> Done. Output:"
ls -la "$OUT_DIR/ja" "$OUT_DIR/en"
```

- [ ] **Step 3: 実行権限付与**

```bash
chmod +x scripts/capture-asc-screenshots.sh
```

- [ ] **Step 4: jq の存在確認**

```bash
which jq || echo "MISSING: brew install jq"
```

`jq` が無ければ `brew install jq` を実行 (executor 環境に依存)。

- [ ] **Step 5: スクリプト実行 + 6 PNG 生成確認**

```bash
./scripts/capture-asc-screenshots.sh
```

Expected (末尾):

```
==> Done. Output:
docs/screenshots/asc/v1.1.x/ja:
01-home.png  02-record.png  03-settings.png
docs/screenshots/asc/v1.1.x/en:
01-home.png  02-record.png  03-settings.png
```

失敗パターン:
- `xcrun xcresulttool: error: command requires --legacy` → Xcode のバージョンが古い (16 未満)。エラー文に従い --legacy フラグ追加 (但し export attachments は legacy mode で動作が異なる可能性、Xcode upgrade 推奨)
- `jq: parse error` → manifest.json の schema が想定と違う。`cat "$EXTRACT_DIR/manifest.json" | head -50` で実構造を確認、jq クエリを調整
- PNG が 6 枚揃わない → XCUITest 内 attachment.name の命名 (ja-01-home 等) と script の regex 一致確認

- [ ] **Step 6: Commit (script のみ、PNG は Task 3 で commit)**

```bash
git add scripts/capture-asc-screenshots.sh
git commit -m "$(cat <<'EOF'
chore(#50): ASC スクショ撮影スクリプト追加

scripts/capture-asc-screenshots.sh: xcodebuild test で ASCScreenshotUITests を
実行し、xcresulttool export attachments + jq で manifest.json を parse して
docs/screenshots/asc/v1.1.x/{ja,en}/ にリネーム配置するワンショット script。
将来 ja スクショ更新時にも再利用可能。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 撮影スクショの目視確認 + commit

**Files:**
- Add: `docs/screenshots/asc/v1.1.x/ja/{01-home,02-record,03-settings}.png`
- Add: `docs/screenshots/asc/v1.1.x/en/{01-home,02-record,03-settings}.png`

- [ ] **Step 1: 6 ファイルの存在 + サイズ確認**

```bash
ls -la docs/screenshots/asc/v1.1.x/ja docs/screenshots/asc/v1.1.x/en
# Expected: 6 PNG ファイル、各 ~1-3 MB
```

各 PNG のサイズが 100 KB 未満 (空の画面 / splash 残存) でないこと、5 MB 超 (異常) でないことを確認。

- [ ] **Step 2: en/01-home.png の tab label を目視確認**

```bash
# Claude (Plan executor) の場合: SendUserFile で en/01-home.png をユーザーに表示
# 確認ポイント: tab bar に "Home" "Record" "Settings" の英語表示が見えること
```

人間レビュー前提。tab label が日本語 (ホーム/記録/設定) のままだったら locale 切替が効いていない → Task 1 step 3 の失敗診断に戻る。

- [ ] **Step 3: en/02-record.png, en/03-settings.png でも英語 UI が反映されていることを目視確認**

`02-record.png`: 画面タイトル / セクション見出し / button label が英語
`03-settings.png`: セクション見出し ("General" 等) と各設定項目が英語

- [ ] **Step 4: ja スクショも問題ないことを目視確認**

`ja/01-home.png`: 「ホーム」「記録」「設定」、子供名「太郎」「花子」が表示
`ja/02-record.png`: 「お手伝い記録」タイトル
`ja/03-settings.png`: 「設定」セクション

- [ ] **Step 5: PNG 6 枚を commit**

```bash
git add docs/screenshots/asc/v1.1.x
git commit -m "$(cat <<'EOF'
docs(#50): ASC 英語ロケーション用スクショ 6 枚追加

iPhone 17 Pro Max (6.7-inch) で ja + en × 3 tab (Home/Record/Settings) を
撮影。en 3 枚は ASC 英語ロケーション (#50 § 1.5) アップロード対象、
ja 3 枚は将来 ja スクショ更新時の reference として保存。

撮影方法: ./scripts/capture-asc-screenshots.sh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: RELEASE_v1.1.1_ASC_EN.md § 7 更新

**Files:**
- Modify: `RELEASE_v1.1.1_ASC_EN.md` § 7 (line ~155-163)

- [ ] **Step 1: § 7 の deferred checkbox を編集**

`RELEASE_v1.1.1_ASC_EN.md` の § 7 内の以下の行:

```markdown
- [ ] (Deferred) Capture English-locale screenshots and upload — track in a v1.1.x follow-up using [[ios-simulator-locale-testing]]
```

を以下に置換:

```markdown
- [ ] Capture English-locale screenshots and upload to ASC
  - Source PNGs (撮影済み、Issue #50 Phase 1 § 1.5): 
    - [`docs/screenshots/asc/v1.1.x/en/01-home.png`](./docs/screenshots/asc/v1.1.x/en/01-home.png)
    - [`docs/screenshots/asc/v1.1.x/en/02-record.png`](./docs/screenshots/asc/v1.1.x/en/02-record.png)
    - [`docs/screenshots/asc/v1.1.x/en/03-settings.png`](./docs/screenshots/asc/v1.1.x/en/03-settings.png)
  - Reference (ja 同条件撮影): `docs/screenshots/asc/v1.1.x/ja/` 配下 3 枚
  - 撮影手順: `./scripts/capture-asc-screenshots.sh` (再撮影時)
```

- [ ] **Step 2: § 8 Related の Future integration 部分も更新**

§ 8 末尾の以下を:

```markdown
- Future integration: Phase 2 of #50 — incorporate the English What's New draft step into `RELEASE_v1.1.2.md` and subsequent release docs.
```

そのまま維持 (RELEASE_v1.1.2.md § 2.5 で実装済みのため変更不要)。

- [ ] **Step 3: Commit**

```bash
git add RELEASE_v1.1.1_ASC_EN.md
git commit -m "$(cat <<'EOF'
docs(#50): RELEASE_v1.1.1_ASC_EN.md § 7 deferred 解除 + image link 追記

§ 1.5 (English-locale screenshots) が完了したので checklist の (Deferred)
表記を外し、docs/screenshots/asc/v1.1.x/en/ 配下 3 PNG への relative link
を追加。再撮影スクリプトへの参照も併記。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: PR 作成

**Files:** なし (gh CLI 操作)

- [ ] **Step 1: branch の状態確認**

```bash
git status
git log --oneline main..HEAD
```

Expected commits (順序):
1. `docs(spec): #50 Phase 1 § 1.5 ASC 英語ロケーション用スクショ撮影 design`
2. `test(#50): ASC スクショ撮影用 XCUITest 追加`
3. `chore(#50): ASC スクショ撮影スクリプト追加`
4. `docs(#50): ASC 英語ロケーション用スクショ 6 枚追加`
5. `docs(#50): RELEASE_v1.1.1_ASC_EN.md § 7 deferred 解除 + image link 追記`

(plan 自体の commit も加わる場合 6 件)

- [ ] **Step 2: 並列で作業中の同名 branch が無いことを確認**

```bash
gh pr list --head docs/issue-50-asc-en-localization-phase1 --state all
```

Expected: 該当 PR 無し (空 array) — 別 session が先に PR 作成していないこと。

- [ ] **Step 3: push**

```bash
git push -u origin docs/issue-50-asc-en-localization-phase1
```

- [ ] **Step 4: PR 作成**

```bash
gh pr create --title "docs(#50): ASC 英語ロケーション用スクショ撮影 (Phase 1.5)" --body "$(cat <<'EOF'
## Summary

- Issue #50 Phase 1 § 1.5 (英語ロケール用スクショ撮影) を完了。XCUITest + locale launch args で ja + en × 3 tab = 6 枚を 1 回の test run で自動撮影。
- 撮影スクリプト `scripts/capture-asc-screenshots.sh` を新設、将来 ja 更新時にも再利用可。
- 撮影スクショは `docs/screenshots/asc/v1.1.x/{ja,en}/` に commit (en 3 枚が ASC アップロード対象、ja 3 枚は reference)。
- `RELEASE_v1.1.1_ASC_EN.md` § 7 の deferred checkbox を解除、image link を追記。

これで #50 Phase 1 の全 deliverable (1.1〜1.7) が揃い、残作業は user の ASC UI 操作 (locale 追加 + paste + 保存) のみ。

## Spec / Plan

- Spec: `docs/superpowers/specs/2026-05-24-issue-50-asc-en-screenshots-design.md`
- Plan: `docs/superpowers/plans/2026-05-24-issue-50-asc-en-screenshots.md`

## Plan からの逸脱

| 項目 | Spec / Plan の記述 | Verify 結果 | 対応 |
| --- | --- | --- | --- |
| TutorialService の `--uitesting` skip 対応 | Spec § 3 / § 5 で「(必要なら) 1〜2 行修正」と保留 | `TutorialService.swift:25-30` で**既に対応済み** (`if --uitesting { ... return }`) | 修正不要を確定、本 PR では一切触らず |

## Verification

撮影スクショ 6 枚を目視確認:
- ja 3 枚: tab label = ホーム / 記録 / 設定、子供名 = 太郎 / 花子
- en 3 枚: tab label = Home / Record / Settings、UI 全体が英訳済み

`scripts/capture-asc-screenshots.sh` の green 完走を確認。

### ja Home (reference)

![ja-01-home](docs/screenshots/asc/v1.1.x/ja/01-home.png)

### en Home (ASC upload target)

![en-01-home](docs/screenshots/asc/v1.1.x/en/01-home.png)

## Test plan

- [x] `xcodebuild test -only-testing:OtetsudaiCoinUITests/ASCScreenshotUITests` が green
- [x] 6 PNG が `docs/screenshots/asc/v1.1.x/{ja,en}/` に配置
- [x] en の tab label が英語表示になっていることを目視
- [x] `RELEASE_v1.1.1_ASC_EN.md` § 7 から image link が valid
- [ ] (PR merge 後、user 手動) ASC で英語ロケーション追加 → § 1〜6 draft paste → en スクショ 3 枚 upload → 保存

## Related

- Issue: #50 (Phase 1 § 1.5)
- Sibling work: 一括モード ON / 重複警告ラベルのスクショ更新は別 issue で対応予定
- Future: ContentView.selectedTab @AppStorage 化 (UX 改善) も別 issue
EOF
)"
```

- [ ] **Step 5: PR URL をユーザーに返す**

`gh pr create` の出力から URL を抽出し、ユーザーに通知。

---

## Self-Review

**1. Spec coverage check:**

| Spec 要求 | Plan task |
| --- | --- |
| § 2 Included: en 3 + ja 3 = 6 枚撮影 | Task 1 (撮影 logic) + Task 2 (実行) + Task 3 (commit) |
| § 2 Included: 画像保存場所 `docs/screenshots/asc/v1.1.x/{ja,en}/` 新設 | Task 3 step 5 (commit 時に dir 作成) |
| § 2 Included: `RELEASE_v1.1.1_ASC_EN.md` § 7 deferred 解除 + image link | Task 4 |
| § 3 Files to add: 全 4 種 | Task 1 (swift) / Task 2 (sh) / Task 3 (PNG) を分担 |
| § 3 Files to modify: RELEASE_v1.1.1_ASC_EN.md | Task 4 |
| § 3 Files to modify: TutorialService.swift (必要なら) | **Verify 結果不要、Plan deviation 節に明示** |
| § 3 Key implementation notes: TutorialService skip 確認 | Verify 済み (不要) |
| § 3 Key implementation notes: `element(boundBy:)` 使用 | Task 1 step 1 コード内に反映 |
| § 3 Key implementation notes: iPhone 17 Pro Max | Task 1 step 2, Task 2 step 2 で指定 |
| § 3 Key implementation notes: splash sleep | Task 1 step 1 で `sleep(4)` |
| § 3 Image extraction: xcresulttool + jq | Task 2 step 2 内で実装 |
| § 4 Success criteria 1: script 完走 | Task 2 step 5 |
| § 4 Success criteria 2: 6 PNG 配置 | Task 3 step 1 |
| § 4 Success criteria 3: en tab label 英語 | Task 3 step 2-3 |
| § 4 Success criteria 4: § 7 image link | Task 4 step 1 |
| § 4 Success criteria 5: PR に スクショ inline | Task 5 step 4 body 内 |
| § 5 PR title / branch / commit plan | Task 1〜5 で順次 |
| § 7 Risks: manifest.json フォーマット | Task 2 step 5 失敗パターンに明記 |
| § 7 Risks: TutorialView skip | Verify 済み (上記参照) |
| § 7 Risks: locale 反映されない | Task 1 step 3 失敗診断、Task 2 step 5 失敗パターン |
| § 7 Risks: flake | (CLAUDE.md 「iOS テスト flake 切り分け」 ルール継承、特別な task 化不要) |

**Coverage: 全 spec 要求が task に mapping されている (TutorialService 除外は plan deviation で明示)。**

**2. Placeholder scan:** TBD / TODO / "implement later" / "appropriate" 系語句なし。失敗パターンは具体的な原因と対処を明記。

**3. Type consistency:**
- `attachment.name = name`、`name` 引数は `\(language)-01-home` 形式で統一 (Task 1 step 1) → Task 2 step 2 の jq regex `^(ja|en)-([0-9]{2})-([a-z]+)` と一致
- `XCUIApplication`, `XCUIScreen.main.screenshot()`, `XCTAttachment` 等 Apple API の signature は確定値
- `OtetsudaiCoinUITests/ASCScreenshotUITests` の test target / class 名は Task 1, 2, 5 全部で一致
