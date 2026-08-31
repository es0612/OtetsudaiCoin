# #205 perf fix + #206 helper 配置整理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `HelpHistoryView.groupedRecords` の sort 内 O(n·k·log k) 回の `formatter.string()` 呼び出しを O(n) 回へ削減し (#205)、`timeString` / `timeFormatterCache` を `HelpHistoryView` static から独立 helper `TimeStringFormatter` へ移設して `HelpRecordRow` の名前空間依存を解消する (#206)。

**Architecture:** #205 は「pure static helper 抽出 → characterization テスト (green) → formatter 呼び出し回数のカウントテスト (旧ロジックで RED) → keyToDate マップ実装で GREEN」の pure-extraction パターン (#125 で確立)。#206 は `Utils/TimeStringFormatter.swift` への verbatim 移動 + 呼び出し側更新 (振る舞い変更なし、red 不可 → 移動後テスト + full suite を代替検証とする)。

**Tech Stack:** Swift / SwiftUI / XCTest。ViewInspector は不要 (static helper 直接検証)。

**Spec:** GitHub Issue #205・#206 本文 (fix 案・配置案が明記済み) が spec に相当。

## Global Constraints

- `xcodebuild test` は **FOREGROUND 実行必須** (background 禁止)。判定は `grep -E -A6 '\*\* TEST|Failing tests:'` で判定行を直接抽出する。
- テスト実行コマンド (unit 全体):
  `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:OtetsudaiCoinTests > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"`
  (destination は実行前に `xcrun simctl list devices available | grep iPhone` で実在確認し、無ければ実在名に差し替える)
- 日付 fixture は固定絶対日付 (2026-07-15 等の月中日) + 明示 locale で実行日非依存にする (#112/#114/#115 flake 対策)。
- strict concurrency `targeted` が有効 (PR #197)。static var cache には `@MainActor` を verbatim 維持する。
- `PBXFileSystemSynchronizedRootGroup` 採用のため新規 .swift はディレクトリ配置のみで自動認識。**pbxproj 編集ステップは不要**。
- commit prefix: `perf(#205)` / `refactor(#206)` (PR #204 のタイトル慣行に従う)。

---

### Task 1: #205 — groupRecordsByDay の pure 抽出 + characterization テスト

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:223-243` (groupedRecords)
- Test: `app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift` (追記)

**Interfaces:**
- Produces: `HelpHistoryView.groupRecordsByDay(_ records: [HelpRecordWithDetails], dayKey: (Date) -> String) -> [(key: String, value: [HelpRecordWithDetails])]` — nonisolated internal static。Task 2 がこの signature を前提に呼び出し回数テストを書く。
- `dayKey` は closure 注入 (advisor 推奨: DateFormatter subclass override より単純にカウント可能)。プロダクション側は `formatter.string(from:)` を包んで渡す。

- [ ] **Step 1: 旧ロジックを verbatim で pure static helper へ抽出する (振る舞い不変 refactor)**

`HelpHistoryView` 内 (`makeDayGroupFormatter` の直前あたり) に追加:

```swift
/// 履歴レコードを日付グループへまとめ、グループを日付降順で並べる (#205)。
/// `dayKey` は Date → グループ見出し文字列の変換 (プロダクションでは
/// makeDayGroupFormatter の string(from:) を渡す。テストではカウント用 closure を注入)。
nonisolated static func groupRecordsByDay(
    _ records: [HelpRecordWithDetails],
    dayKey: (Date) -> String
) -> [(key: String, value: [HelpRecordWithDetails])] {
    let grouped = Dictionary(grouping: records) { record in
        dayKey(record.helpRecord.recordedAt)
    }

    return grouped.sorted { lhs, rhs in
        let lhsDate = records.first { record in
            dayKey(record.helpRecord.recordedAt) == lhs.key
        }?.helpRecord.recordedAt ?? Date.distantPast

        let rhsDate = records.first { record in
            dayKey(record.helpRecord.recordedAt) == rhs.key
        }?.helpRecord.recordedAt ?? Date.distantPast

        return lhsDate > rhsDate
    }
}
```

`groupedRecords` computed var は抽出 helper 呼び出しへ置換:

```swift
private var groupedRecords: [(key: String, value: [HelpRecordWithDetails])] {
    // formatter 生成 (ICU 初期化) は安くないため 1 インスタンスを使い回す。
    let formatter = Self.makeDayGroupFormatter(locale: Locale.current)
    return Self.groupRecordsByDay(viewModel.helpRecords) { formatter.string(from: $0) }
}
```

- [ ] **Step 2: characterization テストを書く (旧ロジックのまま green を確認する)**

`HelpHistoryViewTests.swift` に追記。fixture は `HelpRecordRowTests.swift:23-32` の factory パターンを流用する (`HelpRecordWithDetails` の生成方法をそちらから copy)。**同一日内で配列順が日時順でない (unsorted) レコード**を含め、(a) グループが日付降順、(b) グループ内は入力配列順 (Dictionary(grouping:) の保証) を lock する:

```swift
// MARK: - groupRecordsByDay (#205)

/// 2026-07-{day} {hour}:00 の HelpRecordWithDetails を固定生成する
/// (HelpRecordRowTests.makeView の factory パターンを流用)。
private func makeRecord(day: Int, hour: Int) -> HelpRecordWithDetails {
    let date = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 7, day: day, hour: hour)
    )!
    let child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")
    let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100, sortOrder: 0, icon: nil)
    let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: date)
    return HelpRecordWithDetails(helpRecord: record, child: child, task: task)
}

/// グループは日付降順、グループ内は入力配列順を維持すること (characterization)。
func testGroupRecordsByDaySortsGroupsDescendingAndKeepsWithinGroupOrder() {
    // day15 の 2 件は「遅い時刻が先」の unsorted 配列順にして、
    // グループ代表値の取り方 (first vs min) の差が結果へ出ないことも lock する
    let records = [
        makeRecord(day: 15, hour: 18),
        makeRecord(day: 14, hour: 9),
        makeRecord(day: 15, hour: 8),
        makeRecord(day: 16, hour: 12),
    ]
    let groups = HelpHistoryView.groupRecordsByDay(records) { date in
        "day-\(Calendar(identifier: .gregorian).component(.day, from: date))"
    }
    XCTAssertEqual(groups.map(\.key), ["day-16", "day-15", "day-14"],
                   "rendered: \(groups.map(\.key))")
    XCTAssertEqual(groups[1].value.map(\.helpRecord.recordedAt),
                   [records[0], records[2]].map(\.helpRecord.recordedAt),
                   "グループ内の入力配列順が保たれていない")
}

/// 空配列で空結果 (crash しない) こと。
func testGroupRecordsByDayEmptyInputReturnsEmpty() {
    let groups = HelpHistoryView.groupRecordsByDay([]) { _ in "x" }
    XCTAssertTrue(groups.isEmpty)
}
```

- [ ] **Step 3: テスト実行 → 全 green を確認 (抽出は振る舞い不変なので characterization は旧ロジックで PASS するはず)**

Run (foreground): Global Constraints のコマンドで `-only-testing:OtetsudaiCoinTests/HelpHistoryViewTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit (抽出 + characterization)**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift
git commit -m "refactor(#205): groupedRecords の grouping/sort を pure static helper groupRecordsByDay へ抽出 (characterization テスト付き、振る舞い不変)"
```

### Task 2: #205 — dayKey 呼び出し回数テスト (RED) → keyToDate マップで GREEN

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift` (Task 1 の `groupRecordsByDay`)
- Test: `app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift` (追記)

**Interfaces:**
- Consumes: Task 1 の `groupRecordsByDay(_:dayKey:)`
- Produces: 同 signature のまま内部実装のみ O(n) 化 (呼び出し側変更なし)

- [ ] **Step 1: dayKey 呼び出し回数のテストを書く**

期待値は `records.count` 回ちょうど (grouping で各レコード 1 回、sort では 0 回)。旧ロジックは sort 比較のたびに線形探索で呼ぶため必ず超過し、RED/GREEN が明確に判別できる:

```swift
/// dayKey (formatter.string 相当) は各レコード 1 回 = 計 n 回しか呼ばれないこと (#205 perf)。
/// 旧実装は sort 比較内の線形探索で O(n·k·log k) 回呼んでいた。
func testGroupRecordsByDayCallsDayKeyOncePerRecord() {
    let records = [
        makeRecord(day: 15, hour: 18),
        makeRecord(day: 14, hour: 9),
        makeRecord(day: 15, hour: 8),
        makeRecord(day: 16, hour: 12),
        makeRecord(day: 13, hour: 7),
    ]
    var callCount = 0
    _ = HelpHistoryView.groupRecordsByDay(records) { date in
        callCount += 1
        return "day-\(Calendar(identifier: .gregorian).component(.day, from: date))"
    }
    XCTAssertEqual(callCount, records.count,
                   "dayKey が \(callCount) 回呼ばれた (期待: \(records.count) 回 = レコードあたり 1 回)")
}
```

- [ ] **Step 2: テスト実行 → RED を確認 (behavioral red なので必ず実行、skip 禁止)**

Run (foreground): `-only-testing:OtetsudaiCoinTests/HelpHistoryViewTests/testGroupRecordsByDayCallsDayKeyOncePerRecord`
Expected: FAIL — callCount が 5 を超過 (旧ロジックの sort 内線形探索が原因)

- [ ] **Step 3: keyToDate マップ実装で O(n) 化する**

`groupRecordsByDay` の body を置換 (issue #205 の bot 提案準拠。旧実装の「first (配列順) 代表」と bot 案の「min (最早日時) 代表」は、日グループが互いに素な日付区間なのでグループ降順の結果は同一 — Step 1 の characterization がこれを lock 済み):

```swift
nonisolated static func groupRecordsByDay(
    _ records: [HelpRecordWithDetails],
    dayKey: (Date) -> String
) -> [(key: String, value: [HelpRecordWithDetails])] {
    let grouped = Dictionary(grouping: records) { record in
        dayKey(record.helpRecord.recordedAt)
    }

    // sort 比較内で dayKey (formatter.string 相当) の線形探索を繰り返すと
    // O(n·k·log k) 回の呼び出しになるため、key → 代表日時のマップを 1 回だけ作る (#205)
    let keyToDate: [String: Date] = grouped.reduce(into: [:]) { dict, pair in
        dict[pair.key] = pair.value
            .min(by: { $0.helpRecord.recordedAt < $1.helpRecord.recordedAt })?
            .helpRecord.recordedAt
    }

    return grouped.sorted {
        keyToDate[$0.key, default: .distantPast] > keyToDate[$1.key, default: .distantPast]
    }
}
```

- [ ] **Step 4: テスト実行 → 呼び出し回数テスト + characterization がすべて GREEN**

Run (foreground): `-only-testing:OtetsudaiCoinTests/HelpHistoryViewTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift
git commit -m "perf(#205): groupRecordsByDay の sort を keyToDate マップ化し formatter 呼び出しを O(n·k·log k) → O(n) 回へ削減"
```

### Task 3: #206 — timeString 一族を Utils/TimeStringFormatter へ移設

**Files:**
- Create: `app/OtetsudaiCoin/Utils/TimeStringFormatter.swift`
- Create: `app/OtetsudaiCoinTests/Utils/TimeStringFormatterTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift` (263-292 行の timeFormatterCache / timeFormatter / timeString を削除、:381 の呼び出しを更新)
- Modify: `app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift` (time 系テスト 3 件を削除 — 新テストファイルへ移動)

**Interfaces:**
- Produces: `TimeStringFormatter.timeString(from: Date, locale: Locale) -> String` / `TimeStringFormatter.timeFormatter(locale: Locale) -> DateFormatter` (いずれも `@MainActor` static)。`HelpRecordRow` はこれを呼ぶ (HelpHistoryView への名前空間依存が消える)。
- Consumes: なし (Task 1/2 と独立。dayGroup 系 helper は HelpHistoryView 専用のため移動しない = issue #206 の最小スコープ)

- [ ] **Step 1: `Utils/TimeStringFormatter.swift` を新規作成 (実装は verbatim 移動、@MainActor 維持)**

```swift
import Foundation

/// 記録時刻の locale 対応フォーマット helper (#206)。
///
/// 旧実装は `HelpHistoryView` の static メンバーで、独立 struct の `HelpRecordRow` が
/// `HelpHistoryView.timeString(...)` を呼ぶ名前空間依存があった (PR #204 bot 指摘)。
/// `HelpRecordRow` を別画面で再利用しても View への依存を引き連れないよう独立させる。
enum TimeStringFormatter {

    /// 記録時刻 formatter の locale 別 cache (#201)。
    /// 旧実装は呼び出し (= HelpRecordRow の行 render) ごとに DateFormatter を生成しており、
    /// 長い履歴リストのスクロールで全可視行分の生成+設定コストが発生していた。
    /// View body (= MainActor) からしか呼ばれないため @MainActor で隔離し、
    /// 素の static var の data race を避ける。
    @MainActor
    private static var timeFormatterCache: [String: DateFormatter] = [:]

    /// locale に対応する時刻 formatter を返す (cache 済みなら再利用)。
    @MainActor
    static func timeFormatter(locale: Locale) -> DateFormatter {
        if let cached = timeFormatterCache[locale.identifier] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = locale
        timeFormatterCache[locale.identifier] = formatter
        return formatter
    }

    /// 記録時刻を locale に応じて生成する (#155 コメント報告の i18n 漏れ対応)。
    ///
    /// 旧実装は `HelpRecordRow` 内の private func で ja_JP 固定になっており、
    /// en ロケールでも 24 時間表記が強制されていた。`.short` スタイルは
    /// ja で「9:05」(現行と同一)、en で「9:05 AM」になる。
    @MainActor
    static func timeString(from date: Date, locale: Locale) -> String {
        timeFormatter(locale: locale).string(from: date)
    }
}
```

- [ ] **Step 2: 呼び出し側を更新する**

`HelpHistoryView.swift`:
- 263-292 行の `timeFormatterCache` / `timeFormatter` / `timeString` の 3 メンバーを削除
- :381 の `HelpHistoryView.timeString(from:locale:)` → `TimeStringFormatter.timeString(from: record.helpRecord.recordedAt, locale: Locale.current)`

- [ ] **Step 3: テストを新ファイルへ移動する**

`app/OtetsudaiCoinTests/Utils/TimeStringFormatterTests.swift` を新規作成し、`HelpHistoryViewTests` から time 系 3 テスト (`testTimeStringJapaneseLocaleKeepsCurrentStyle` / `testTimeStringEnglishLocaleUsesLocalizedStyle` / `testTimeFormatterIsCachedPerLocale`) と `fixedDate` fixture を移す。呼び先を `TimeStringFormatter.` へ変更する以外は verbatim:

```swift
import XCTest
@testable import OtetsudaiCoin

/// TimeStringFormatter (#206 で HelpHistoryView から移設) のテスト。
///
/// - 日付 fixture は固定絶対日付 (2026-07-15 = 月中日) を使い、実行日非依存にする (#112/#114/#115 の flake 対策)。
/// - locale は明示的に ja_JP / en_US を渡し、実行環境 locale に依存しない。
@MainActor
final class TimeStringFormatterTests: XCTestCase {

    /// 2026-07-15 (水) 09:05 を gregorian で固定生成する。
    private func fixedDate(hour: Int = 9, minute: Int = 5) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        components.hour = hour
        components.minute = minute
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)!
    }

    /// ja では現行の「9:05」と同一であること (非退行)。
    func testTimeStringJapaneseLocaleKeepsCurrentStyle() {
        let time = TimeStringFormatter.timeString(
            from: fixedDate(), locale: Locale(identifier: "ja_JP")
        )
        XCTAssertEqual(time, "9:05", "rendered: \(time)")
    }

    /// en では 12 時間表記 + AM/PM になること。
    /// AM 前の空白は ICU バージョンにより U+202F (narrow no-break space) になるため、
    /// 空白文字そのものは assert せず prefix + AM 含有で判定する。
    func testTimeStringEnglishLocaleUsesLocalizedStyle() {
        let time = TimeStringFormatter.timeString(
            from: fixedDate(), locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(time.hasPrefix("9:05"), "rendered: \(time)")
        XCTAssertTrue(time.contains("AM"), "rendered: \(time)")
    }

    /// 同一 locale では formatter instance が再利用されること (行 render ごとの生成コスト解消)。
    func testTimeFormatterIsCachedPerLocale() {
        let ja1 = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "ja_JP"))
        let ja2 = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "ja_JP"))
        XCTAssertTrue(ja1 === ja2, "同一 locale で formatter が再生成されている")

        let en = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertFalse(ja1 === en, "locale が異なるのに同一 formatter が返っている")
    }
}
```

`HelpHistoryViewTests.swift` からは上記 3 テストと `// MARK: - timeString (記録時刻)` / `// MARK: - timeFormatter cache (#201)` セクションを削除 (dayGroup 系テストと `fixedDate` は groupRecordsByDay テストが使うため残す)。

- [ ] **Step 4: 残存参照 grep で移動漏れゼロを確認する (test ターゲット含む)**

```bash
grep -rn "HelpHistoryView.timeString\|HelpHistoryView.timeFormatter" app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests
```

Expected: 0 件

- [ ] **Step 5: unit 全体をテスト実行 → 全 green (pure move なので red 不可 — 移動後テスト + full suite が代替検証。skip 理由は commit message に明記)**

Run (foreground): Global Constraints のコマンド (unit 全体)
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Utils/TimeStringFormatter.swift app/OtetsudaiCoinTests/Utils/TimeStringFormatterTests.swift app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift
git commit -m "refactor(#206): timeString / timeFormatterCache を TimeStringFormatter (Utils) へ移設し HelpRecordRow の HelpHistoryView 依存を解消

pure move (verbatim) のため TDD red は原理的に発生せず、移設後テスト + unit 全 suite green を代替検証とする"
```

### Task 4: 最終 whole-branch レビュー + PR 作成

**Files:**
- なし (レビューと PR 作成のみ)

- [ ] **Step 1: whole-branch レビュー (inline 実行でも省略しない — repo ルール)**

`git diff main...HEAD` を対象に superpowers:requesting-code-review でレビューを実施。観点: (a) perf 特性の diff 確認 (helper 抽出で旧実装のコスト特性が変わっていないか — #155 PR #191 learning)、(b) @MainActor の維持、(c) 参照の取り残し。

- [ ] **Step 2: レビュー指摘があれば修正して commit、なければ次へ**

- [ ] **Step 3: PR 作成**

`git status` で HEAD 確認 → `gh pr list --head feature/issue-205-206-history-formatting` で既存 PR 無しを確認 → push → PR 作成。タイトル: `perf(#205)/refactor(#206): groupedRecords sort の O(n) 化 + TimeStringFormatter 移設`。body に Closes #205 / Closes #206、テスト結果、Plan からの逸脱 (あれば) を記載。
