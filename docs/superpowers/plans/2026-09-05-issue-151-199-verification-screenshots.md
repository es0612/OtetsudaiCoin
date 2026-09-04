# 検証専用スクショ基盤 (light/dark + scroll) と全画面ダーク棚卸し Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ASC 提出物とは分離した「検証専用」スクショ (ライト/ダーク × 14 シーン、fold 下の scroll 版を含む) を 1 コマンドで撮れる基盤を追加し、その出力で #151 提案1「ライト/ダーク全画面スクショ棚卸し」を実施して棚卸し表を issue コメントに残す。

**Architecture:** 新規 XCUITest クラス `VerificationScreenshotUITests` が 5 つのテストメソッド (cold launch 単位) で 14 シーンを `XCTAttachment` として添付する。新規 bash script `scripts/capture-verification-screenshots.sh` が simulator の udid を解決し、`xcrun simctl ui <udid> appearance {light,dark}` でシステム外観を切替えながらテストを 2 回走らせ、xcresult から PNG を `docs/screenshots/verification/{light,dark}/NN-name.png` (gitignored) へ配置する。app コードは一切変更しない (本物のシステムダークで撮る)。

**Tech Stack:** XCTest (XCUITest) / bash / `xcrun simctl` (`list devices -j`, `boot`, `bootstatus`, `ui appearance`) / `xcrun xcresulttool export attachments` / jq

**Spec:** GitHub Issue #199 (scroll 版検証ショットの正式追加、出力先を ASC artifact から分離) + Issue #151 コメント 2026-07-05「提案1: ライト/ダーク両方の全画面スクショ棚卸し」。設計判断は 2026-09-05 の AskUserQuestion で確定: (1) ダーク切替は `simctl ui appearance` (app コード変更なし) / (2) 対象は全画面 (light/dark × ja のみ、en は省略) / (3) 出力先は `docs/screenshots/verification/` + gitignore。

## Global Constraints

- **ASC 提出物 (`docs/screenshots/asc/`, `ASCScreenshotUITests`, `capture-asc-screenshots.sh`) は変更しない**。検証ショットは別クラス・別 script・別出力先。
- 出力先 `docs/screenshots/verification/` は `.gitignore` で除外し、PNG は commit しない (`docs/_config.yml` の `exclude: screenshots` で Pages 非公開も維持)。
- `xcodebuild` は **FOREGROUND 実行必須** (background 禁止)。結果判定は `grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` の判定行で行う (`tail` 頼みにしない)。
- scheme の UITest target は `parallelizable = "YES"` (`OtetsudaiCoin.xcscheme:46`) なので、`-parallel-testing-enabled NO` を必ず付ける。clone simulator に分散されると (a) `--uitesting` の seed が Tutorial 撮影の clone に存在しない、(b) `simctl ui appearance` を当てた device と別 clone で撮られる、の 2 点が壊れる。
- simulator destination は名前ではなく **udid** で指定する (`iPhone 17 Pro Max` が 7 台重複しているため、`simctl ui appearance` を当てる device と xcodebuild が使う device を一致させる)。
- bash script は本番と同じ `/bin/bash` shebang 経由で実行して検証する (zsh の `$match` 罠を避ける)。全モード (`light` / `dark` / `both` / `--help` / エラー) をローカルで網羅実行する。
- jq は asdf shim が壊れている前提で `resolve_jq` (`--version` ライブ実行) で解決する。
- 起動時 sample data は `--uitesting` でのみ seed される。Tutorial / Splash は `--uitesting` を付けずに `-hasLaunchedBefore NO` 等の UserDefaults launch args で表示する。
- 撮影は `XCUIScreen.main.screenshot()` (status bar 含む) に統一する。

---

## File Structure

| ファイル | 役割 |
|---|---|
| `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift` (新規) | 14 シーンの撮影シナリオ。1 メソッド = 1 cold launch。添付名 `verify-NN-name` を produce |
| `scripts/capture-verification-screenshots.sh` (新規) | udid 解決 → 外観切替 → テスト実行 → 添付抽出 → 配置。`--appearance light|dark|both` / `--device NAME` / `--help` |
| `.gitignore` (変更) | `docs/screenshots/verification/` を除外 |
| `CLAUDE.md` (変更) | 「Simulator 視覚検証の限界」節の一時 swipeUp 手順を新 script へ誘導 + 「ASC スクショ撮影」節に検証 script の存在を追記 |
| `docs/screenshots/verification/{light,dark}/NN-name.png` (生成物、非 commit) | 棚卸し用 PNG |

### シーン一覧 (添付名 → 出力ファイル名)

| 添付名 | 到達方法 | 担当メソッド |
|---|---|---|
| `verify-00-splash` | 非 `--uitesting` 起動直後 (Splash は 2.5 秒表示、`SplashScreenView.swift:124`) | `testCaptureTutorial` |
| `verify-01-home` | `--uitesting` 起動、`child_button` 出現待ち | `testCaptureTabs` |
| `verify-02-record` | tab index 1 | `testCaptureTabs` |
| `verify-03-record-scrolled` | + `app.swipeUp()` | `testCaptureTabs` |
| `verify-04-settings` | tab index 2 | `testCaptureTabs` |
| `verify-05-settings-scrolled` | + `app.swipeUp()` | `testCaptureTabs` |
| `verify-06-home-selected` | `child_button` firstMatch tap | `testCaptureChildDetail` |
| `verify-07-monthly-summary` | `home_monthly_summary_entry` tap | `testCaptureChildDetail` |
| `verify-08-help-history` | back → `home_help_history_entry` tap | `testCaptureChildDetail` |
| `verify-09-task-management` | Settings → 「お手伝いリストを編集」 (sheet) | `testCaptureSettingsSheets` |
| `verify-10-child-form` | 「閉じる」→ `add_child_button` (sheet) | `testCaptureSettingsSheets` |
| `verify-11-notification-settings` | Settings → 「通知設定」 (NavigationLink) | `testCaptureNotificationSettings` |
| `verify-12-tutorial-child` | 非 `--uitesting` + `-hasLaunchedBefore NO -hasCompletedChildTutorial NO` | `testCaptureTutorial` |
| `verify-13-tutorial-record` | 非 `--uitesting` + `-hasLaunchedBefore NO -hasCompletedChildTutorial YES -hasCompletedRecordTutorial NO` | `testCaptureTutorial` |

XCTest はメソッドをアルファベット順に実行する (`ChildDetail` → `NotificationSettings` → `SettingsSheets` → `Tabs` → `Tutorial`)。各メソッドは cold launch なので順序は正しさに影響しないが、`Tutorial` が最後に走るため Core Data に seed 済みの太郎/花子が Record tutorial の子ども選択に表示される (seed は `--uitesting` 起動で persist 済み)。

---

### Task 1: `VerificationScreenshotUITests` — 14 シーンの撮影シナリオ

**Files:**
- Create: `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift`
- Modify: `.gitignore` (末尾に追記)
- Test: 上記 UITest 自体を simulator で実行し、xcresult から 14 添付が export されることで検証する

**Interfaces:**
- Consumes: 既存 accessibilityIdentifier `child_button` / `home_monthly_summary_entry` / `home_help_history_entry` / `add_child_button` / `cancel_button` (いずれも `Presentation/Views/HomeView.swift`, `SettingsView.swift`, `ChildFormView.swift` に定義済み)、ボタン文言 「お手伝いリストを編集」 (`SettingsView.swift:109`)、「閉じる」 (`TaskManagementView.swift:63`)、「通知設定」 (`SettingsView.swift:129`)、「次へ」 (`ChildTutorialView.swift:222`, `RecordTutorialView.swift:403`)
- Produces: 添付名 `verify-NN-name` (regex `^verify-([0-9]{2})-([a-z-]+)$`) を 14 件。Task 2 の script がこの命名規約で PNG を配置する

- [ ] **Step 1: `.gitignore` に出力先を追加**

`.gitignore` の末尾 (`.claude/settings.local.json` の行の後) に追記:

```gitignore

# 検証専用スクショ (capture-verification-screenshots.sh の出力、ASC 非提出物)。
# 棚卸し結果は issue コメントに表として残し、PNG 自体は commit しない (Issue #199 / #151)
docs/screenshots/verification/
```

- [ ] **Step 2: UITest ファイルを作成**

```swift
//
//  VerificationScreenshotUITests.swift
//  OtetsudaiCoinUITests
//
//  検証専用スクショ (ASC 非提出物) を撮る。Issue #199 / #151 提案1。
//  scripts/capture-verification-screenshots.sh が
//  `xcrun simctl ui <udid> appearance {light,dark}` を切替えながらこのクラスを
//  2 回走らせ、添付名 `verify-NN-name` の PNG を
//  docs/screenshots/verification/{light,dark}/NN-name.png へ配置する (gitignored)。
//
//  ASC 提出用の ASCScreenshotUITests とは意図的に分離している:
//  - こちらは fold 下 (swipeUp 後) や sheet / NavigationLink 先 / Tutorial / Splash も撮る
//  - 出力は ASC artifact (docs/screenshots/asc/) に混ぜない
//
//  各テストメソッドは 1 cold launch。XCTest はアルファベット順に実行するため
//  testCaptureTutorial (非 --uitesting 起動) が最後に走り、それまでの --uitesting
//  起動で seed された太郎/花子が Core Data に残っている前提で Record tutorial を撮る。
//

import XCTest

final class VerificationScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    /// --uitesting 起動 (tutorial skip + 太郎/花子 seed + splash skip)。ja 固定。
    private func launchMainApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--hide-developer-tools",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        let firstChild = app.buttons.matching(identifier: "child_button").firstMatch
        XCTAssertTrue(
            firstChild.waitForExistence(timeout: 15),
            "Home content (child_button) did not load within 15s"
        )
        sleep(1) // card entrance animation settle
        return app
    }

    /// 非 --uitesting 起動で Splash → Tutorial を表示させる。
    /// `-key value` 形式の launch args は UserDefaults.standard を per-launch で上書きする
    /// (simulator の erase 不要)。CLAUDE.md「Tutorial / sheet など初回状態でしか出ない UI の視覚検証」参照。
    private func launchTutorialApp(childCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasLaunchedBefore", "NO",
            "-hasCompletedChildTutorial", childCompleted ? "YES" : "NO",
            "-hasCompletedRecordTutorial", "NO",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        return app
    }

    /// 文言ベースの行ボタン (HStack + SF Symbol) は symbol の accessibility label が
    /// button label に畳み込まれて exact match を外すことがあるため CONTAINS で探す。
    /// 見つからない場合は全 button label を XCTFail メッセージに載せて 1 回の red で原因を掴む
    /// (CLAUDE.md PR #183 の診断パターン)。
    private func buttonContaining(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        let element = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if !element.waitForExistence(timeout: timeout) {
            let labels = app.buttons.allElementsBoundByIndex.map(\.label)
            XCTFail("button containing '\(text)' not found. buttons=\(labels)")
        }
        return element
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Scenes

    /// 01-home / 02-record / 03-record-scrolled / 04-settings / 05-settings-scrolled
    func testCaptureTabs() throws {
        let app = launchMainApp()
        attach(name: "verify-01-home")

        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        attach(name: "verify-02-record")
        app.swipeUp()
        sleep(1)
        attach(name: "verify-03-record-scrolled")

        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        attach(name: "verify-04-settings")
        app.swipeUp()
        sleep(1)
        attach(name: "verify-05-settings-scrolled")
    }

    /// 06-home-selected / 07-monthly-summary / 08-help-history
    func testCaptureChildDetail() throws {
        let app = launchMainApp()
        app.buttons.matching(identifier: "child_button").firstMatch.tap()
        sleep(2)
        attach(name: "verify-06-home-selected")

        let summaryEntry = app.buttons["home_monthly_summary_entry"]
        XCTAssertTrue(summaryEntry.waitForExistence(timeout: 5), "monthly summary entry missing")
        if !summaryEntry.isHittable { app.swipeUp(); sleep(1) }
        summaryEntry.tap()
        sleep(2)
        attach(name: "verify-07-monthly-summary")

        app.navigationBars.buttons.element(boundBy: 0).tap() // back
        sleep(1)
        let historyEntry = app.buttons["home_help_history_entry"]
        XCTAssertTrue(historyEntry.waitForExistence(timeout: 5), "help history entry missing")
        if !historyEntry.isHittable { app.swipeUp(); sleep(1) }
        historyEntry.tap()
        sleep(2)
        attach(name: "verify-08-help-history")
    }

    /// 09-task-management (sheet) / 10-child-form (sheet)
    func testCaptureSettingsSheets() throws {
        let app = launchMainApp()
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)

        let taskEntry = buttonContaining("お手伝いリストを編集", in: app)
        taskEntry.tap()
        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "task management sheet did not open")
        sleep(1)
        attach(name: "verify-09-task-management")
        closeButton.tap()
        sleep(1)

        let addChild = app.buttons["add_child_button"]
        XCTAssertTrue(addChild.waitForExistence(timeout: 5), "add child button missing")
        addChild.tap()
        let cancelButton = app.buttons["cancel_button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "child form sheet did not open")
        sleep(1)
        attach(name: "verify-10-child-form")
        cancelButton.tap()
    }

    /// 11-notification-settings (NavigationLink)
    func testCaptureNotificationSettings() throws {
        let app = launchMainApp()
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        let entry = buttonContaining("通知設定", in: app)
        entry.tap()
        sleep(2)
        attach(name: "verify-11-notification-settings")
    }

    /// 00-splash / 12-tutorial-child / 13-tutorial-record
    func testCaptureTutorial() throws {
        // Child tutorial 経路: 起動直後は SplashScreenView (2.5 秒) が出ているので先に撮る (best-effort)
        let childApp = launchTutorialApp(childCompleted: false)
        attach(name: "verify-00-splash")
        let nextButton = childApp.buttons["次へ"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 20), "child tutorial did not appear")
        sleep(1)
        attach(name: "verify-12-tutorial-child")
        childApp.terminate()

        // Record tutorial 経路: child 完了済み扱いで起動すると shouldShowRecordTutorial が true になる
        // (TutorialService.swift:84-86)
        let recordApp = launchTutorialApp(childCompleted: true)
        let recordNext = recordApp.buttons["次へ"]
        XCTAssertTrue(recordNext.waitForExistence(timeout: 20), "record tutorial did not appear")
        sleep(1)
        attach(name: "verify-13-tutorial-record")
    }
}
```

- [ ] **Step 3: udid を解決して UITest を単独実行 (FOREGROUND)**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
JQ=/opt/homebrew/bin/jq
UDID=$(xcrun simctl list devices available -j | "$JQ" -r '.devices[][] | select(.name=="iPhone 17 Pro Max" and .isAvailable) | .udid' | head -1)
echo "UDID=$UDID"
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/436b0efa-7f38-4c4a-88c1-f4b47b4e011e/scratchpad
mkdir -p "$SCRATCH/t1"
LOG="$SCRATCH/t1/uitest.log"
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination "id=$UDID" \
  -only-testing:OtetsudaiCoinUITests/VerificationScreenshotUITests \
  -parallel-testing-enabled NO \
  -resultBundlePath "$SCRATCH/t1/result.xcresult" > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`。FAILED の場合は `xcrun xcresulttool get test-results tests --path "$SCRATCH/t1/result.xcresult"` で失敗メッセージ (どの XCTAssertTrue が落ちたか) を取り、要素の到達方法 (identifier / 文言 / isHittable) を修正する。

- [ ] **Step 4: 添付を export して 14 件あることを確認**

```bash
xcrun xcresulttool export attachments --path "$SCRATCH/t1/result.xcresult" --output-path "$SCRATCH/t1/extracted"
"$JQ" -r '.[].attachments[].suggestedHumanReadableName' "$SCRATCH/t1/extracted/manifest.json" | grep '^verify-' | sort
"$JQ" -r '.[].attachments[].suggestedHumanReadableName' "$SCRATCH/t1/extracted/manifest.json" | grep -c '^verify-'
```

Expected: `verify-00-splash` 〜 `verify-13-tutorial-record` の 14 行、count = 14。Splash が撮れず main 画面になっていた場合 (`verify-00-splash` が Home と同じ) は best-effort として PR description に記載する (ダークモード1 の判定は `SplashScreenView.swift:15-22` のコード読みで代替可能)。

- [ ] **Step 5: Commit**

```bash
git add .gitignore app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift
git commit -m "test(#199): 検証専用スクショ用 VerificationScreenshotUITests を追加 (14 シーン、fold 下 / sheet / tutorial / splash を含む)"
```

---

### Task 2: `capture-verification-screenshots.sh` — 外観切替つき撮影 script + CLAUDE.md 更新

**Files:**
- Create: `scripts/capture-verification-screenshots.sh` (実行ビット付き)
- Modify: `CLAUDE.md` 「Simulator 視覚検証の限界」節 (一時 swipeUp の bullet、現在 :127) と「ASC スクショ撮影」節 (:169 付近)
- Test: script を `/bin/bash` 経由で `--help` / 不正引数 / `--appearance light` / `--appearance dark` / 引数なし (both) の全モードで実行する

**Interfaces:**
- Consumes: Task 1 の添付名規約 `^verify-([0-9]{2})-([a-z-]+)$`、テストクラス `OtetsudaiCoinUITests/VerificationScreenshotUITests`
- Produces: `docs/screenshots/verification/{light,dark}/NN-name.png` (14 件 × 外観数)。Task 3 がこれを Read する

- [ ] **Step 1: script を作成**

```bash
#!/bin/bash
# Captures verification-only screenshots (NOT App Store Connect deliverables).
# Issue #199 (scrolled shots) + Issue #151 提案1 (light/dark inventory).
#
# Runs VerificationScreenshotUITests once per appearance, toggling the
# simulator's system appearance with `xcrun simctl ui <udid> appearance`,
# then exports the attachments from each xcresult into
#   docs/screenshots/verification/<appearance>/NN-name.png   (gitignored)
#
# Usage:
#   scripts/capture-verification-screenshots.sh [--appearance light|dark|both]
#                                               [--device "iPhone 17 Pro Max"]
#
# Requirements:
#   - Xcode 16+ (xcrun xcresulttool export attachments)
#   - jq (brew install jq)
#   - An available simulator matching --device (default: iPhone 17 Pro Max)
#
# The ASC deliverable pipeline (capture-asc-screenshots.sh / ASCScreenshotUITests)
# is intentionally untouched: verification shots never go under docs/screenshots/asc/.

set -euo pipefail

PROJECT="app/OtetsudaiCoin.xcodeproj"
SCHEME="OtetsudaiCoin"
TEST_CLASS="OtetsudaiCoinUITests/VerificationScreenshotUITests"
OUT_DIR="docs/screenshots/verification"
DEVICE_NAME="iPhone 17 Pro Max"
APPEARANCE_MODE="both"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appearance)
      [[ $# -ge 2 ]] || { echo "error: --appearance needs a value" >&2; exit 2; }
      APPEARANCE_MODE="$2"; shift 2 ;;
    --device)
      [[ $# -ge 2 ]] || { echo "error: --device needs a value" >&2; exit 2; }
      DEVICE_NAME="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$APPEARANCE_MODE" in
  light) APPEARANCES=(light) ;;
  dark)  APPEARANCES=(dark) ;;
  both)  APPEARANCES=(light dark) ;;
  *) echo "error: --appearance must be light|dark|both (got: $APPEARANCE_MODE)" >&2; exit 2 ;;
esac

# Same resolution strategy as capture-asc-screenshots.sh (kept in sync by hand):
# the asdf shim can be first in PATH but broken, so run --version to confirm.
resolve_jq() {
  local candidate
  for candidate in "${JQ:-}" /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    { [ -n "$candidate" ] && [ -x "$candidate" ]; } || continue
    if "$candidate" --version >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if command -v jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1; then
    command -v jq
    return 0
  fi
  return 1
}

JQ="$(resolve_jq)" || {
  echo "error: no working jq found. Install with: brew install jq" >&2
  exit 1
}
echo "==> Using jq: $JQ"

# Resolve ONE udid for the device name. Several simulators can share a name
# (this machine has 7× "iPhone 17 Pro Max"); `simctl ui appearance` must hit
# the same device xcodebuild uses, so we pass `-destination id=<udid>`.
# Prefer an already-booted one to skip boot time.
resolve_udid() {
  local name="$1"
  xcrun simctl list devices available -j \
    | "$JQ" -r --arg n "$name" '
        [.devices[][] | select(.name == $n and .isAvailable)]
        | sort_by(.state != "Booted")
        | .[0].udid // empty'
}

UDID="$(resolve_udid "$DEVICE_NAME")"
[[ -n "$UDID" ]] || {
  echo "error: no available simulator named '$DEVICE_NAME'. Available iPhones:" >&2
  xcrun simctl list devices available | grep iPhone >&2 || true
  exit 1
}
echo "==> Using simulator: $DEVICE_NAME ($UDID)"

# Always leave the simulator in light mode, even if a run fails midway.
restore_appearance() {
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true
}
trap restore_appearance EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true   # no-op if already booted
xcrun simctl bootstatus "$UDID" -b >/dev/null

TMP_ROOT="$(mktemp -d)"
echo "==> Scratch: $TMP_ROOT"

place_attachments() {
  local manifest="$1" extract_dir="$2" dest_dir="$3"
  mkdir -p "$dest_dir"
  local placed=0
  while IFS=$'\t' read -r human export; do
    if [[ "$human" =~ ^verify-([0-9]{2})-([a-z-]+)$ ]]; then
      local num="${BASH_REMATCH[1]}" name="${BASH_REMATCH[2]}"
      cp "$extract_dir/$export" "$dest_dir/${num}-${name}.png"
      echo "  $human → $dest_dir/${num}-${name}.png"
      placed=$((placed + 1))
    else
      echo "  (skip non-verification attachment: $human)"
    fi
  done < <("$JQ" -r '.[].attachments[] | "\(.suggestedHumanReadableName)\t\(.exportedFileName)"' "$manifest")
  echo "  placed $placed PNG(s) into $dest_dir"
}

for appearance in "${APPEARANCES[@]}"; do
  echo "==> [$appearance] Setting simulator appearance"
  xcrun simctl ui "$UDID" appearance "$appearance"

  result_bundle="$TMP_ROOT/$appearance.xcresult"
  log="$TMP_ROOT/$appearance.log"
  echo "==> [$appearance] Running $TEST_CLASS (log: $log)"
  set +e
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -only-testing:"$TEST_CLASS" \
    -parallel-testing-enabled NO \
    -resultBundlePath "$result_bundle" > "$log" 2>&1
  xcode_exit=$?
  set -e
  grep -E -A6 '\*\* TEST|Failing tests:' "$log" || true
  if [[ $xcode_exit -ne 0 ]] || ! grep -q '\*\* TEST SUCCEEDED \*\*' "$log"; then
    echo "error: [$appearance] xcodebuild test failed (exit=$xcode_exit). See $log" >&2
    echo "hint: xcrun xcresulttool get test-results tests --path \"$result_bundle\"" >&2
    exit 1
  fi

  extract_dir="$TMP_ROOT/$appearance-extracted"
  mkdir -p "$extract_dir"
  echo "==> [$appearance] Exporting attachments"
  xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$extract_dir"

  echo "==> [$appearance] Placing PNGs"
  place_attachments "$extract_dir/manifest.json" "$extract_dir" "$OUT_DIR/$appearance"
done

echo "==> Done. Output:"
for appearance in "${APPEARANCES[@]}"; do
  ls -la "$OUT_DIR/$appearance"
done
```

```bash
chmod +x scripts/capture-verification-screenshots.sh
```

- [ ] **Step 2: 静的チェックと引数分岐のオフライン検証 (xcodebuild を走らせない分岐)**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
bash -n scripts/capture-verification-screenshots.sh && echo "syntax ok"
bash scripts/capture-verification-screenshots.sh --help; echo "exit=$?"
bash scripts/capture-verification-screenshots.sh --appearance purple; echo "exit=$?"
bash scripts/capture-verification-screenshots.sh --bogus; echo "exit=$?"
bash scripts/capture-verification-screenshots.sh --device "iPhone 99"; echo "exit=$?"
```

Expected: `--help` は usage を表示して exit=0 / `--appearance purple` は `must be light|dark|both` で exit=2 / `--bogus` は `unknown option` で exit=2 / `--device "iPhone 99"` は `no available simulator` + iPhone 一覧で exit=1 (jq 解決ログの後)。

- [ ] **Step 3: `--appearance light` を実行 (FOREGROUND、約 3〜5 分)**

```bash
bash scripts/capture-verification-screenshots.sh --appearance light 2>&1 | tee "$SCRATCH/t2-light.log"
ls docs/screenshots/verification/light | wc -l
xcrun simctl ui "$UDID" appearance   # 後始末確認
```

Expected: `placed 14 PNG(s)`、`ls` = 14、最後の `simctl ui appearance` 出力が `light`。

- [ ] **Step 4: `--appearance dark` を実行**

```bash
bash scripts/capture-verification-screenshots.sh --appearance dark 2>&1 | tee "$SCRATCH/t2-dark.log"
ls docs/screenshots/verification/dark | wc -l
xcrun simctl ui "$UDID" appearance
```

Expected: `placed 14 PNG(s)`、`ls` = 14、外観は `light` に復帰 (trap)。`docs/screenshots/verification/dark/01-home.png` を Read して背景が黒系であること (本当にダークで撮れていること) を目視で確認する。

- [ ] **Step 5: 引数なし (both) を実行して 2 外観連続動作を確認**

```bash
rm -rf docs/screenshots/verification
bash scripts/capture-verification-screenshots.sh 2>&1 | tee "$SCRATCH/t2-both.log"
find docs/screenshots/verification -name '*.png' | wc -l
git status --short   # verification/ が untracked に出ないこと (gitignore 確認)
```

Expected: 28、`git status` に `docs/screenshots/verification` が出ない。この both 実行の出力を Task 3 の棚卸しにそのまま使う。

- [ ] **Step 6: CLAUDE.md を更新**

「Simulator 視覚検証の限界」節の以下の bullet (現在 :127、「02-record の initial view はカレンダーが fold を占有し…」で始まる行) の**末尾**の文 「fold 下 UI の変更が続くなら scroll 版の検証専用ショット (ASC 非提出) の script 正式追加を検討 (#177 に記載)。」 を次に置換する:

```markdown
**2026-09-05 #199 で正式 script 化済み**: `scripts/capture-verification-screenshots.sh [--appearance light|dark|both]` が `VerificationScreenshotUITests` (14 シーン: 3 tab initial + Record/Settings の swipeUp 後 + 子選択後 Home / 月のまとめ / 履歴 / タスク管理 sheet / 子ども追加 sheet / 通知設定 / Splash / Tutorial 子・記録) を `simctl ui <udid> appearance` で外観を切替えながら撮り、`docs/screenshots/verification/{light,dark}/NN-name.png` (gitignored、ASC 非提出) へ置く。fold 下や sheet の一次目視は一時 swipeUp ではなくこちらを使う。simulator は名前重複 (iPhone 17 Pro Max ×7) を避けるため udid 解決して `-destination id=` で渡す。
```

「ASC スクショ撮影」節の bullet 「再撮影だけなら repo 内 script を実行する。…」の直後に 1 bullet を追加:

```markdown
- **検証専用 (非 ASC) の light/dark + scroll ショットは `scripts/capture-verification-screenshots.sh`** (#199 / #151 提案1)。ASC script と同じ export/配置パイプラインだが、テストクラス (`VerificationScreenshotUITests`)・出力先 (`docs/screenshots/verification/`、gitignored)・外観切替 (`simctl ui appearance`) が異なる。ASC 提出物 (`docs/screenshots/asc/`) には一切書かない。
```

- [ ] **Step 7: Commit**

```bash
git add scripts/capture-verification-screenshots.sh CLAUDE.md
git commit -m "feat(#199): capture-verification-screenshots.sh を追加 (simctl ui appearance で light/dark 切替、udid 解決、検証専用出力先)"
```

---

### Task 3: #151 提案1 の棚卸し実施 — 全 28 枚の一次目視 → 表 → issue コメント

**Files:**
- Read: `docs/screenshots/verification/{light,dark}/*.png` (Task 2 Step 5 の出力 28 枚)
- Create (scratch): `$SCRATCH/inventory-151.md` (issue コメント本文)
- 外部: GitHub Issue #151 コメント (`gh issue comment`)

**Interfaces:**
- Consumes: Task 2 の PNG 28 枚
- Produces: #151 へのコメント (棚卸し表)。PR description からリンクする

- [ ] **Step 1: 28 枚を Read で一次目視し、シーンごとに所見をメモ**

`light/NN-name.png` と `dark/NN-name.png` を同じシーンで並べて Read し、以下の観点で記録する (assistant が全枚数を見る。user へ丸投げしない):

1. 背景・カードが適応色になっているか (ダークで白カードが浮いていないか)
2. 極薄塗り (`.gray.opacity(...)`) や固定 hex (`AccessibilityColors` の #0066CC 等、`brandSurfaceWarm` #FFF4E6) がダークで沈む/浮くか
3. テキストのコントラスト (固定 `.white` / `.black` 文字が背景と同化していないか)
4. 影・区切り線が消えていないか
5. ライトでの既知の見え方と比べて意図しない差 (regression) がないか

- [ ] **Step 2: 棚卸し表を書く**

```bash
cat > "$SCRATCH/inventory-151.md" <<'MD'
## 2026-09-05 提案1: ライト/ダーク全画面スクショ棚卸し (PR #NNN)

撮影: `scripts/capture-verification-screenshots.sh` (iPhone 17 Pro Max, ja, light/dark × 14 シーン = 28 枚)。PNG は gitignored のため添付せず、所見のみ記録。

| # | シーン | light | dark | 所見 | 対応先 |
|---|---|---|---|---|---|
| 00 | Splash | (所見) | (所見) | 固定オレンジ/黄グラデ + 白文字 (`SplashScreenView.swift:15-22`) | ダークモード1 |
| 01 | Home (未選択) | | | | |
| 02 | Record (initial) | | | | |
| 03 | Record (scrolled) | | | | |
| 04 | Settings (initial) | | | | |
| 05 | Settings (scrolled) | | | | |
| 06 | Home (子選択後) | | | | |
| 07 | 月のまとめ | | | | |
| 08 | お手伝い履歴 | | | | |
| 09 | タスク管理 sheet | | | | |
| 10 | 子ども追加 sheet | | | | |
| 11 | 通知設定 | | | | |
| 12 | Tutorial (子) | | | | |
| 13 | Tutorial (記録) | | | | |

### 集約

- 崩れ (要修正): (件数と一覧)
- 最適化余地 (デザイン判断待ち → ダークモード3 で扱う): (一覧)
- 問題なし: (一覧)

### 次のアクション

- ダークモード1 (Splash) / ダークモード3 (固定 hex の適応色化 + 橙の統一) の対象箇所を上表の所見で具体化した
- 提案3 (固定フォント → Dynamic Type) は本棚卸しの対象外 (別 PR)
MD
```

各行の `(所見)` を Step 1 の目視結果で埋める。「対応先」列は `ダークモード1` / `ダークモード3` / `提案3` / `なし` のいずれか。

- [ ] **Step 3: user に表を提示して確認 (AskUserQuestion、closed)**

表全体を返答に貼り、選択肢は「この内容で #151 にコメントする」「修正してから投稿する (Other で指摘)」の 2 択で聞く。

- [ ] **Step 4: 投稿は Task 4 Step 2 で PR 番号が確定した後に行う** (下記 Task 4 Step 3)。表の `PR #NNN` を実番号にしてから `gh issue comment 151 --body-file "$SCRATCH/inventory-151.md"` を実行し、コメント URL を PR description に追記する。

---

### Task 4: PR 作成と最終 whole-branch レビュー

**Files:**
- 全変更: `.gitignore` / `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift` / `scripts/capture-verification-screenshots.sh` / `CLAUDE.md`

- [ ] **Step 1: whole-branch レビュー (spec 準拠 + code quality)**

`git diff origin/main...HEAD` を対象に、(a) #199 の要件 (scroll 版の正式追加・出力先の分離) と #151 提案1 (light/dark 全画面) が満たされているか、(b) script の全モード検証ログ (Task 2 Step 2〜5) が揃っているか、(c) ASC 系ファイルに差分が無いか (`git diff origin/main...HEAD --stat -- docs/screenshots/asc app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift scripts/capture-asc-screenshots.sh` が空)、を確認する。

- [ ] **Step 2: push 前の確認と PR 作成**

```bash
git status --short --branch          # HEAD が feat/151-199-verification-screenshots であること
gh pr list --head feat/151-199-verification-screenshots   # 既存 PR なし
git push -u origin feat/151-199-verification-screenshots
```

PR description には以下を含める: 概要 / シーン一覧 / script の使い方 / 全モード検証ログの要約 / 棚卸しコメントへのリンク / `## Plan からの逸脱` (あれば) / `Closes #199` / `Refs #151` / 「Splash は best-effort」注記 / 末尾の生成フッター。

- [ ] **Step 3: 棚卸し表の `PR #NNN` を実番号に置換して #151 へコメント投稿し、返ってきた URL を PR description に追記する**

```bash
sed -i '' "s/PR #NNN/PR #<実番号>/" "$SCRATCH/inventory-151.md"
gh issue comment 151 --body-file "$SCRATCH/inventory-151.md"
```

- [ ] **Step 4: CI green 待ちの前に merge 可否を AskUserQuestion で確認** (CLAUDE.md 2026-08-31 ルール)
