# #309 検証撮影で en と未払いバナーを撮る Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `scripts/capture-verification-screenshots.sh --locale en` で英語表示の検証スクショを撮れるようにし、未払いバナー（1 人・2 人）と履歴の空状態を一時変更なしで撮れるようにする。

**Architecture:** script が `TEST_RUNNER_VERIFY_LOCALE` を付けて `VerificationScreenshotUITests` を流し、UITest は環境変数で起動引数の言語を切り替える。未払いの記録は DEBUG 限定の起動引数 `--seed-unpaid-records 1|2`（`--in-memory-store` のときだけ）で `ContentView.setupInitialData()` が入れる。記録の中身は純粋関数で作り、ユニットテストで固定する。

**Tech Stack:** Swift / SwiftUI / XCTest / XCUITest / bash（`/bin/bash`）

**Spec:** `docs/superpowers/specs/2026-11-22-issue-309-verification-locale-unpaid-design.md`

## Global Constraints

- 既定（ja・引数なし）の出力パス `docs/screenshots/verification/<appearance>/` とファイル名は変えない。en は `docs/screenshots/verification/en/<appearance>/`
- ASC 用の `capture-asc-screenshots.sh` / `ASCScreenshotUITests` は触らない
- 未払いの投入は `#if DEBUG` 限定で、`--in-memory-store` が無いときは何もしない
- en で撮るのは `testCaptureTabs`（01〜05）・`testCaptureChildDetail`（06〜08）・新しい 31〜33 だけ。ほかのテストは en のとき `XCTSkip`
- xcodebuild は FOREGROUND で流し、合否は `** TEST SUCCEEDED **` の行で判定する（exit code だけで判定しない）
- simulator は `xcrun simctl list devices available | grep 'iPhone 17 Pro Max'` で実在を確かめ、`-destination id=<udid>` で渡す（名前が 5 台重複している）。`-parallel-testing-enabled NO`
- bash script の検証は `/bin/bash` で流す（Bash tool は zsh。glob はクォートする）

## Review Focus

1. **年をまたぐ月**: 1 月に撮ると、先月・2 か月前は前年の 12 月・11 月になる。記録が前年の月に入り、今月（1 月）に 1 件も入らないこと → Task 1 の `test_records_crossesYearBoundary`
2. **永続ストアを汚さない**: `--seed-unpaid-records 2` だけ（`--in-memory-store` なし）で起動したら何も入れない。値が 1・2 以外や欠けているときも何もしない → Task 1 の `test_childCount_*`
3. **既定の出力が変わらない**: `--locale` なし（ja）のとき、出力ファイル名の集合が main の撮影テストの `verify-NN-name` と同じで、増えるのは 31〜33 だけ → Task 3 Step 4
4. **ja と en の取り違え**: `compare-screenshots.sh` に ja の light と en の light を渡したら、条件の違い（`locale`）で止まる（exit 3） → Task 3 Step 5
5. **投入とホームの描画の競合**: 投入は非同期なので、ホームが先に描画されるとバナーが出ない。投入の後に `notifyHelpRecordUpdated()` を呼び、UITest は `home_unpaid_summary_link` を 15 秒まで待つ → Task 1 Step 5 と Task 2 Step 3

---

### Task 1: 未払いの記録を入れる（DEBUG 限定）

**Files:**
- Create: `app/OtetsudaiCoin/Utils/UnpaidRecordsSeeder.swift`（ファイル全体を `#if DEBUG`）
- Modify: `app/OtetsudaiCoin/ContentView.swift`（`setupInitialData()` のデフォルトタスク作成 `if existingTasks.isEmpty { … }` の直後）
- Test: `app/OtetsudaiCoinTests/Utils/UnpaidRecordsSeederTests.swift`（ファイル全体を `#if DEBUG`。既存の置き場所に合わせてよい）

**Interfaces:**
- Produces:
  - `enum UnpaidRecordsSeeder`
  - `static func childCount(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int?` — `--in-memory-store` があり、`--seed-unpaid-records` の次の引数が `"1"` か `"2"` のときだけその数。ほかは `nil`
  - `static func records(childIds: [UUID], helpTaskId: UUID, now: Date, calendar: Calendar) -> [HelpRecord]` — 子どもごとに、`now` の 1 か月前と 2 か月前の月の 10 日の 9 時・12 時・15 時に 1 件ずつ（子ども 1 人あたり 6 件）

- [ ] **Step 1: 失敗するテストを書く**

```swift
func test_childCount_requiresInMemoryStore() {
    XCTAssertNil(UnpaidRecordsSeeder.childCount(arguments: ["app", "--seed-unpaid-records", "2"]))
}
func test_childCount_acceptsOneAndTwo() {
    XCTAssertEqual(UnpaidRecordsSeeder.childCount(arguments: ["app", "--in-memory-store", "--seed-unpaid-records", "1"]), 1)
    XCTAssertEqual(UnpaidRecordsSeeder.childCount(arguments: ["app", "--seed-unpaid-records", "2", "--in-memory-store"]), 2)
}
func test_childCount_rejectsOtherValues() {
    for tail in [["--seed-unpaid-records"], ["--seed-unpaid-records", "3"], ["--seed-unpaid-records", "x"], []] {
        XCTAssertNil(UnpaidRecordsSeeder.childCount(arguments: ["app", "--in-memory-store"] + tail), "\(tail)")
    }
}
func test_records_twoPastMonthsThreeEach() {
    // now = 2026-11-22 12:00 (Asia/Tokyo の gregorian calendar を明示)
    let records = UnpaidRecordsSeeder.records(childIds: [a, b], helpTaskId: task, now: now, calendar: cal)
    XCTAssertEqual(records.count, 12)
    // 子どもごとに 2026-10 が 3 件・2026-09 が 3 件、2026-11 は 0 件
    // helpTaskId はすべて task
}
func test_records_crossesYearBoundary() {
    // now = 2026-01-15 → 2025-12 が 3 件・2025-11 が 3 件、2026-01 は 0 件
}
```

- [ ] **Step 2: テストを流して失敗を確かめる** — 型が無いので `BUILD FAILED` が確定する。red は skip してよい（CLAUDE.md の skip 条件 (a)）。skip した旨を commit メッセージに書く

- [ ] **Step 3: `UnpaidRecordsSeeder` を実装する** — 月は `calendar.date(byAdding: .month, value: -n, to: now)` から year/month を取り、`DateComponents(year:month:day: 10, hour:)` で作る

- [ ] **Step 4: テストを流して通ることを確かめる**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination "id=<udid>" -parallel-testing-enabled NO -only-testing:OtetsudaiCoinTests/UnpaidRecordsSeederTests`
Expected: `** TEST SUCCEEDED **`、5 件 pass

- [ ] **Step 5: `setupInitialData()` に配線する** — デフォルトタスク作成の直後に `#if DEBUG` で、`UnpaidRecordsSeeder.childCount()` が値を返したら、`childRepository.findAll()` の先頭 `count` 人と `helpTaskRepository.findAll()` の先頭の id で `records(…, now: Date(), calendar: .current)` を作って `helpRecordRepository.save` し、最後に `NotificationManager.shared.notifyHelpRecordUpdated()` を 1 回呼ぶ（`helpRecordRepository` は月末リセットで作ったものを使う）

- [ ] **Step 6: ユニットテスト全体を流す**

Run: Step 4 のコマンドを `-only-testing:OtetsudaiCoinTests` で
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add app/OtetsudaiCoin/Utils/UnpaidRecordsSeeder.swift app/OtetsudaiCoin/ContentView.swift app/OtetsudaiCoinTests/Utils/UnpaidRecordsSeederTests.swift
git commit -m "feat(#309): 検証撮影用に未払いの記録を入れる起動引数を足す（DEBUG・in-memory 限定）"
```

### Task 2: UITest の言語切り替えと 31〜33 のシーン

**Files:**
- Modify: `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift`（起動ヘルパー 3 つ・各テストの先頭・新しいテスト 2 本・ファイル先頭のコメント）
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:85-90`（期間の `Picker` に `.accessibilityIdentifier("history_period_picker")`）

**Interfaces:**
- Consumes: Task 1 の `--seed-unpaid-records 1|2`（`--in-memory-store` と一緒に渡す）
- Produces: 環境変数 `VERIFY_LOCALE`（`ja` / `en`。無ければ ja）。script は `TEST_RUNNER_VERIFY_LOCALE` で渡す（Task 3）

- [ ] **Step 1: 言語の helper を足す** — `private var languageArguments: [String]`。`VERIFY_LOCALE == "en"` なら `["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]`、無いか `"ja"` なら今の ja の 4 つ、それ以外は `XCTFail` してから ja。3 つの起動ヘルパーの直書きをこれに置き換える

- [ ] **Step 2: en で動かないテストを skip する** — `private func skipUnlessJapanese() throws`（en のとき `throw XCTSkip("日本語の文言でボタンを探すため en では撮らない（#308 の 2 本目で en 化）")`）。`testCaptureTabs` / `testCaptureChildDetail` / 新しい 2 本以外の全テストの先頭で呼ぶ

- [ ] **Step 3: 新しいシーンを足す**（どちらも `launchMainApp(extraArguments: ["--in-memory-store", "--seed-unpaid-records", "<n>"])`）
  - `testCaptureHomeUnpaidOne`: `home_unpaid_summary_link` を 15 秒まで待つ → `verify-31-home-unpaid-one`。最初の `child_button` → `home_help_history_entry`（`revealButton` で）→ `app.segmentedControls["history_period_picker"].buttons.element(boundBy: 0)`（今週）をタップ → `verify-33-history-empty-week`。picker が見つからなければ `app.segmentedControls` の一覧を `XCTFail` に載せる
  - `testCaptureHomeUnpaidTwo`: 同じく待って `verify-32-home-unpaid-two`
  - 名前は `testCaptureHome…` にして、チュートリアルのテストより先に走る並び（アルファベット順）を保つ

- [ ] **Step 4: ja と en で新しいテストを流す**

Run: `TEST_RUNNER_VERIFY_LOCALE=en xcodebuild test … -only-testing:OtetsudaiCoinUITests/VerificationScreenshotUITests/testCaptureHomeUnpaidOne -only-testing:OtetsudaiCoinUITests/VerificationScreenshotUITests/testCaptureHomeUnpaidTwo -only-testing:OtetsudaiCoinUITests/VerificationScreenshotUITests/testCaptureRecordTasks -resultBundlePath <scratchpad>/t2-en.xcresult`（環境変数なしでも同じように流す）
Expected: どちらも `** TEST SUCCEEDED **`。en では `testCaptureRecordTasks` が skipped。添付を `xcrun xcresulttool export attachments` で取り出し、31〜33 の画像を Read で目視する（en でバナーの見出しが日本語のままなのは #308 の対象なので、ここでは直さない）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift
git commit -m "test(#309): 検証撮影を VERIFY_LOCALE で en に切り替え、未払いバナーと履歴の空状態を撮る"
```

### Task 3: script の `--locale`

**Files:**
- Modify: `scripts/capture-verification-screenshots.sh`（ヘッダーの Usage・引数の解析・appearance のループの内側に locale のループ）
- Modify: `scripts/lib/common.sh:136`（`CAPTURE_CONDITION_KEYS` に `locale`）と `:215-234`（`write_capture_meta` に 4 つ目の引数 `locale` → `locale=<ja|en>` の行）

**Interfaces:**
- Consumes: Task 2 の `VERIFY_LOCALE`
- Produces: `--locale ja|en|both`（既定 `ja`）。出力先 ja → `$OUT_DIR/$appearance`、en → `$OUT_DIR/en/$appearance`

- [ ] **Step 1: 引数と出力先を実装する** — 不正値は `error: --locale must be ja|en|both` で exit 2。各 run の xcodebuild の前に `TEST_RUNNER_VERIFY_LOCALE="$locale"` を付ける。result bundle・log・watch log・extract のパスに locale を含める。`FAILED_APPEARANCES` の要素は `<appearance>/<locale>`。最後の一覧も locale ごとに出す。`common.sh` の `CAPTURE_CONDITION_KEYS` の末尾に `locale` を足し、`write_capture_meta "$dest" "$UDID" "$DEVICE_NAME" "$locale"` で `locale=` の行を書く（古いフォルダに `locale` が無いときは compare が warn だけで比べる、既存の挙動のまま）

- [ ] **Step 2: 引数の分岐を流す**

Run: `/bin/bash scripts/capture-verification-screenshots.sh --help`、`… --locale fr`、`… --locale`
Expected: help に `--locale` が出る / exit 2 と `--locale must be ja|en|both` / exit 2 と `--locale needs a value`

- [ ] **Step 3: 実際に撮る**

Run: `/bin/bash scripts/capture-verification-screenshots.sh --appearance light --locale both`
Expected: 2 回とも `** TEST SUCCEEDED **`、exit 0。`docs/screenshots/verification/light/` と `docs/screenshots/verification/en/light/` に `capture-meta.txt`（`locale=ja` / `locale=en`）

- [ ] **Step 4: 既定の出力が変わらないことを確かめる**

Run: `git show origin/main:app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift | grep -o -E 'verify-[0-9]{2}-[a-z0-9-]+' | sort -u` の集合（`verify-21-record-tasks-p` の補間分は実ファイルで照合）と `ls docs/screenshots/verification/light/*.png` を比べる
Expected: 差分は `31-home-unpaid-one` / `32-home-unpaid-two` / `33-history-empty-week` の追加だけ。en/light は 01〜08 と 31〜33 だけ

- [ ] **Step 5: ja と en の取り違えで止まることを確かめる**

Run: `/bin/bash scripts/compare-screenshots.sh docs/screenshots/verification/light docs/screenshots/verification/en/light; echo "exit=$?"`
Expected: `locale: before=ja after=en` が出て exit 3

- [ ] **Step 6: Commit**

```bash
git add scripts/capture-verification-screenshots.sh scripts/lib/common.sh
git commit -m "chore(#309): 検証撮影 script に --locale ja|en|both を足す"
```
