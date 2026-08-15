# Issue #177 残件 (項目5: 絵文字展開 + 項目7: Shape fill AND 化) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** #148 で確立した `displayIcon` 絵文字カードのデザインを残り 3 画面 (履歴行 / 記録編集のタスク選択行 / タスク管理行) へ展開し (#177 項目5)、あわせて `testSelectedCardUsesBrandPrimaryShapes` の Shape fill 判定を OR → AND へ強化する (#177 項目7)。

**Architecture:** 3 箇所の `Image(systemName: "hands.sparkles")` を `Text(task.displayIcon)` へ置換する表示層のみの変更。DB / Domain 層は触らない (`displayIcon` は表示時フォールバック済み、HelpTask.swift:96)。テストは CLAUDE.md「SwiftUI View テスト戦略」の findAll ベース (iOS 26 + ViewInspector 0.10.2 で accessibilityIdentifier 解決不能のため)。

**Tech Stack:** SwiftUI / XCTest + ViewInspector 0.10.2 / iOS 26 SDK simulator (iPhone 17)

**Spec:** Issue #177 本文 項目5・項目7 + 2026-08-13 triage コメント (スプラッシュ除外指示)。個別 spec ドキュメントなし (issue が spec を兼ねる小粒 follow-up)。

## Global Constraints

- **`SplashScreenView.swift:62` の hands.sparkles は触らない** (#151 ダークモード track のスコープ。#177 の 2026-08-13 triage コメントが「スプラッシュは別トラック」と明示)
- 絵文字 Text には必ず `.accessibilityHidden(true)` を付ける (意味はタスク名 Text が担う、#84 パターン。全 3 箇所共通)
- 新規 View テストは `findAll(ViewType.Text.self)` / `findAll(ViewType.Shape.self)` ベースで書く (`find(viewWithAccessibilityIdentifier:)` は iOS 26 で systematic に効かない)
- 未実証の traversal に PASS が依存する assert は失敗メッセージに観測値を dump する (#106 ルール)
- テスト実行は **FOREGROUND 必須**。判定は `grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` で行う
- xcodebuild 共通形: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17'` (destination は 2026-08-15 に `simctl list devices available` で実在確認済み)
- commit メッセージ末尾: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01TSYwUBT1cV78odStK2Hot5`

## 視覚検証の境界 (plan 段階で確定)

3 箇所とも navigation / sheet の奥にあり simctl から到達不可、ASC スクショ (01-home / 02-record / 03-settings) にも写らない。グリフ置換のために使い捨て UITest は作らず、**component テスト + PR description に「手動確認推奨」明記**を検証境界とする (PR #192 の前例)。ASC スクショ churn なし・再撮影不要。

---

### Task 1: HelpRecordRow (履歴行) の絵文字化

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:339-343` (HelpRecordRow 内の overlay)
- Test: `app/OtetsudaiCoinTests/Presentation/Components/HelpRecordRowTests.swift`

**Interfaces:**

- Consumes: `HelpTask.displayIcon` (明示 icon → 辞書 → ✨ フォールバック、実装済み)
- Produces: なし (表示のみ)

- [ ] **Step 1: 失敗するテストを書く**

`HelpRecordRowTests.swift` の `makeView` に `icon` / `taskName` パラメータを追加し、絵文字レンダリングテスト 2 件を追加する:

```swift
    private func makeView(
        taskName: String = "皿洗い",
        taskIcon: String? = nil,
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) -> HelpRecordRow {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")
        let task = HelpTask(id: UUID(), name: taskName, isActive: true, coinRate: 100, sortOrder: 0, icon: taskIcon)
        let record = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: task.id,
            recordedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        )
        return HelpRecordRow(
            record: HelpRecordWithDetails(helpRecord: record, child: child, task: task),
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    /// #177 項目5: 行頭アイコンはタスクの displayIcon 絵文字を表示する (#148 の展開)。
    func test_rowIcon_rendersExplicitIconEmoji() throws {
        let view = makeView(taskIcon: "🧹")
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする (displayIcon の既定挙動が row に配線されていること)。
    func test_rowIcon_fallsBackToSparkleForUnknownName() throws {
        let view = makeView(taskName: "辞書に無い独自タスク")
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }
```

既存 `makeView` 呼び出し (引数なし / onEdit / onDelete のみ) はデフォルト引数で互換なので変更不要。

- [ ] **Step 2: RED を確認する**

```bash
LOG=/tmp/t1-red.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/HelpRecordRowTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST FAILED **`、新テスト 2 件が fail (現状は SF Symbol Image で絵文字 Text が無い)。behavioral RED なので skip 不可。

- [ ] **Step 3: 実装する**

`HelpHistoryView.swift` の HelpRecordRow overlay (現 :339-343) を置換:

```swift
                .overlay(
                    // #177 項目5: displayIcon 絵文字 (#148 のカードデザイン展開)。
                    // 絵文字は装飾。行の意味は displayName の Text が担うため VoiceOver から隠す (#84 パターン)
                    Text(record.task.displayIcon)
                        .font(.title3)
                        .accessibilityHidden(true)
                )
```

テーマカラーのグラデ Circle (44pt) はそのまま維持する。

- [ ] **Step 4: GREEN を確認する**

Step 2 と同じコマンド (LOG=/tmp/t1-green.log)。Expected: `** TEST SUCCEEDED **` (既存の tap-target / callback テスト含む全件 PASS)。

- [ ] **Step 5: stale コメントを更新する**

`HelpRecordRowTests.swift:55` 付近の「frame を持たない兄弟 Image (行頭の hands.sparkles) は compactMap で落ちる。」を実態に合わせる:

```swift
        // タップ領域は Button ではなく label 側の Image に付けている
        // (contentShape と組で当たり判定を frame 全体へ広げるため)。
        // Image は AccessibilityImageLabel blocker になるが、findAll なら列挙できる。
        // frame を持たない兄弟 Image (star.fill) は compactMap で落ちる。
        // 行頭アイコンは #177 で Text 絵文字になったため Image 列挙に現れない。
```

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/HelpRecordRowTests.swift
git commit -m "feat(#177): 履歴行のアイコンを displayIcon 絵文字へ置換 (項目5 1/3)"
```

---

### Task 2: TaskSelectionRow (記録編集のタスク選択行) の絵文字化

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift:158-167` (TaskSelectionRow 内のアイコン)
- Test: `app/OtetsudaiCoinTests/Presentation/Views/HelpRecordEditViewTests.swift`

**Interfaces:**

- Consumes: `HelpTask.displayIcon`
- Produces: なし

**設計逸脱 (PR description の `## Plan からの逸脱` ではなく計画済み逸脱として本文に記載):** 現行の「白 SF Symbol on 青丸 (選択時) / 青 SF Symbol on 薄青丸 (非選択時)」は絵文字では意味を失う (絵文字は自前の色を持つ) ため、円の塗りは TaskCardView:61 と同型の `isSelected ? brandPrimary.opacity(0.15) : Color.gray.opacity(0.1)` へ揃える。残存 `.blue` の排除は PR #196 (SF Symbol blue → brandPrimary) の方向性とも整合。選択状態の表現は既存の brandPrimary チェックマーク (:185-189) が担っており失われない。

- [ ] **Step 1: 失敗するテストを書く**

`HelpRecordEditViewTests.swift` の TaskSelectionRow テスト群の末尾に追加:

```swift
    /// #177 項目5: タスク選択行のアイコンは displayIcon 絵文字を表示する (#148 の展開)。
    @MainActor
    func testTaskSelectionRowRendersDisplayIconEmoji() throws {
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true, coinRate: 10, sortOrder: 0, icon: "🧽")
        let row = TaskSelectionRow(task: task, isSelected: false, onSelect: {})
        let texts = try row.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("🧽"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする。
    @MainActor
    func testTaskSelectionRowFallsBackToSparkle() throws {
        let task = HelpTask(id: UUID(), name: "辞書に無い独自タスク", isActive: true)
        let row = TaskSelectionRow(task: task, isSelected: false, onSelect: {})
        let texts = try row.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }
```

- [ ] **Step 2: RED を確認する**

```bash
LOG=/tmp/t2-red.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/HelpRecordEditViewTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST FAILED **`、新テスト 2 件が fail。

- [ ] **Step 3: 実装する**

`HelpRecordEditView.swift` の TaskSelectionRow アイコン部 (現 :158-167) を置換:

```swift
                // タスクアイコン
                // #177 項目5: displayIcon 絵文字 (#148 のカードデザイン展開)。
                // 円の塗りは TaskCardView と同型 (絵文字の上に青塗りは意味を失うため、
                // 白/青 SF Symbol デザインから brandPrimary 0.15 / gray 0.1 へ揃える)。
                // 絵文字は装飾。行の意味は displayName の Text が担うため VoiceOver から隠す (#84 パターン)
                Text(task.displayIcon)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.15) : Color.gray.opacity(0.1))
                    )
                    .accessibilityHidden(true)
```

- [ ] **Step 4: GREEN を確認する**

Step 2 と同じコマンド (LOG=/tmp/t2-green.log)。Expected: `** TEST SUCCEEDED **` (既存の find(text:) 系テストは影響なしで PASS)。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift \
        app/OtetsudaiCoinTests/Presentation/Views/HelpRecordEditViewTests.swift
git commit -m "feat(#177): 記録編集タスク選択行のアイコンを displayIcon 絵文字へ置換 (項目5 2/3)"
```

---

### Task 3: TaskRowView (タスク管理行) の絵文字化 + 新規テストファイル

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:119-121` (TaskRowView 内のアイコン)
- Create: `app/OtetsudaiCoinTests/Presentation/Components/TaskRowViewTests.swift`

**Interfaces:**

- Consumes: `HelpTask.displayIcon`
- Produces: なし

**配置根拠:** TaskRowView は `TaskManagementView.swift` 内宣言のトップレベル struct。同型の HelpRecordRow (HelpHistoryView.swift 内宣言) のテストが `Components/HelpRecordRowTests.swift` にある前例に従い `Components/` へ置く。ファイルは `PBXFileSystemSynchronizedRootGroup` で自動認識、pbxproj 編集不要。

**ミュート表現の確定 (plan 段階で決定):** 無効タスクは `.opacity(task.isActive ? 1.0 : 0.4)`。有効/無効の意味は既存の「有効/無効」Text が担うため、絵文字の彩度までは落とさない。opacity 値の ViewInspector 読み取りは iOS 26 で未実証のため **assert しない** (絵文字 presence の両状態テストのみ。#106 ルールの「未実証 lookup に PASS を依存させない」判断)。

- [ ] **Step 1: 失敗するテストファイルを作る**

`app/OtetsudaiCoinTests/Presentation/Components/TaskRowViewTests.swift` を新規作成:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// `TaskRowView` (TaskManagementView.swift 内宣言) のコンポーネントテスト。
///
/// 親の `TaskManagementView` は NavigationStack + List の組み合わせで
/// ViewInspector が traverse できないが、`TaskRowView` はトップレベル struct
/// なので単独で検証できる (HelpRecordRowTests と同じ Component 分離パターン)。
///
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かないため findAll ベースで検証する (CLAUDE.md「SwiftUI View テスト戦略」)。
@MainActor
final class TaskRowViewTests: XCTestCase {

    private func makeView(
        name: String = "皿洗い",
        icon: String? = nil,
        isActive: Bool = true
    ) -> TaskRowView {
        let task = HelpTask(id: UUID(), name: name, isActive: isActive, coinRate: 10, sortOrder: 0, icon: icon)
        return TaskRowView(task: task, onEdit: {}, onToggle: {}, onDelete: {})
    }

    private func renderedTexts(_ view: TaskRowView) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    /// #177 項目5: 行頭アイコンはタスクの displayIcon 絵文字を表示する (#148 の展開)。
    func test_activeRow_rendersExplicitIconEmoji() throws {
        let texts = try renderedTexts(makeView(icon: "🧹", isActive: true))
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// 無効タスクでも絵文字自体は表示される (ミュートは opacity で表現、有効/無効の意味は状態 Text が担う)。
    func test_inactiveRow_stillRendersEmoji() throws {
        let texts = try renderedTexts(makeView(icon: "🧹", isActive: false))
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする。
    func test_unknownName_fallsBackToSparkle() throws {
        let texts = try renderedTexts(makeView(name: "辞書に無い独自タスク"))
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }
}
```

- [ ] **Step 2: RED を確認する**

```bash
LOG=/tmp/t3-red.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/TaskRowViewTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST FAILED **`、3 件全 fail (現状は SF Symbol Image)。

- [ ] **Step 3: 実装する**

`TaskManagementView.swift` の TaskRowView アイコン部 (現 :119-121) を置換:

```swift
            // #177 項目5: displayIcon 絵文字 (#148 のカードデザイン展開)。
            // 無効タスクは opacity でミュート (有効/無効の意味は下の状態 Text が担う)。
            // 絵文字は装飾。行の意味は displayName の Text が担うため VoiceOver から隠す (#84 パターン)
            Text(task.displayIcon)
                .font(.title3)
                .frame(width: 30)
                .opacity(task.isActive ? 1.0 : 0.4)
                .accessibilityHidden(true)
```

- [ ] **Step 4: GREEN を確認する**

Step 2 と同じコマンド (LOG=/tmp/t3-green.log)。Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TaskRowViewTests.swift
git commit -m "feat(#177): タスク管理行のアイコンを displayIcon 絵文字へ置換 (項目5 3/3)"
```

---

### Task 4: 項目7 — testSelectedCardUsesBrandPrimaryShapes の AND 化

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift:114-124`
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift:41-51`

**Interfaces:**

- Consumes: `AccessibilityColors.brandPrimary` (アイコン円 0.15 / カード背景 0.1、TaskCardView.swift:61,115 / RecordTutorialView.swift:438,473 で確認済み)
- Produces: なし (テスト強化のみ)

**前提と分岐 (issue の「実証が先に必要」を plan に組み込む):** 現行 OR 版の PASS は「どちらか一方の fill に到達できた」ことしか証明しない。`.background` 内 RoundedRectangle が traverse 不能な可能性が残る。AND 版を実行し:
- **GREEN** → findAll(Shape) が ZStack 内 Circle と .background 内 RoundedRectangle の両方へ到達できた実証。mutation 検証 (Step 3) へ進む。
- **RED (dump に 0.15 のみ)** → `.background` fill は到達不能という finding。**OR 版へ戻して** テストコメントに到達不能の実証結果を記録し、issue #177 へのコメントで項目7 を「実証の結果、AND 化不可 (background fill 到達不能)」として close する。この場合 Step 3 は skip。

**TDD red skip の扱い:** これは正実装に対するテスト強化なので通常 RED は存在しない。検出力の実証は Step 3 の mutation 検証 (一時的に片方の fill を壊し FAIL を確認 → revert) で代替する (#177 項目3 / PR #180 の前例)。commit メッセージに mutation 検証結果を明記する。

- [ ] **Step 1: 両テストを AND 版へ書き換える**

`TaskCardViewTests.swift` (:114-124):

```swift
    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let shapes = try view.inspect().findAll(ViewType.Shape.self)
        let fills = shapes.compactMap { try? $0.fillShapeStyle(Color.self) }
        // #177 項目7: アイコン円 (0.15) とカード背景 (0.1) の両方を個別に assert する (AND)。
        // OR だと片方だけの色 regression を検出できない。findAll(Shape) が
        // .background 内 RoundedRectangle にも到達できることは本テストの GREEN + mutation 検証で実証済み。
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.15)),
            "アイコン円の brandPrimary 0.15 が無い / observed fills: \(fills)"
        )
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.1)),
            "カード背景の brandPrimary 0.1 が無い / observed fills: \(fills)"
        )
    }
```

`TutorialTaskCardViewTests.swift` (:41-51) も同一構造で書き換える (view の生成だけ `TutorialTaskCardView(task: makeTask(), isSelected: true, onTap: {})`、assert 部は上と同一)。

- [ ] **Step 2: 実行して分岐を判定する**

```bash
LOG=/tmp/t4-and.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests \
  -only-testing:OtetsudaiCoinTests/TutorialTaskCardViewTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

- `** TEST SUCCEEDED **` → Step 3 へ。
- FAILED で dump が 0.15 のみ → 上記分岐どおり OR 版へ revert + 到達不能 finding をテストコメントへ記録し、Step 3 を skip して Step 4 (commit、メッセージは「項目7: AND 化不可の実証を記録」) へ。

- [ ] **Step 3: mutation 検証 (検出力の実証)**

(a) `TaskCardView.swift:61` の `AccessibilityColors.brandPrimary.opacity(0.15)` を一時的に `Color.gray` へ変更 → Step 2 のコマンドを再実行 → TaskCardViewTests 側が FAIL することを確認 → **revert** (`git checkout -- app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift`)。

(b) `RecordTutorialView.swift:473` のカード背景 `AccessibilityColors.brandPrimary.opacity(0.1)` を一時的に `Color.gray.opacity(0.1)` へ変更 → 再実行 → TutorialTaskCardViewTests 側が FAIL することを確認 → **revert** (`git checkout -- app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift`)。

(a) でアイコン円側、(b) で背景側を壊すことで AND の両辺の検出力を 2 回の mutation で実証する。revert 後に Step 2 のコマンドで GREEN 復帰を確認する。

- [ ] **Step 4: Commit**

```bash
git status  # プロダクトコードの mutation が revert 済み (テスト 2 ファイルのみ変更) を確認
git add app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift
git commit -m "test(#177): Shape fill 判定を OR から AND へ強化、mutation 検証で両辺の検出力を実証 (項目7)"
```

---

### Task 5: 全体検証 + PR 作成

**Files:** 変更なし (検証と PR のみ)

- [ ] **Step 1: hands.sparkles の残存確認**

```bash
grep -rn "hands.sparkles" app/
```

Expected: `SplashScreenView.swift:62` の 1 箇所のみ (意図的除外)。他が出たら置換漏れ。
(HelpRecordRowTests の旧コメント参照は Task 1 Step 5 で更新済みのはず — 出たら見直す)

- [ ] **Step 2: unit 全体を FOREGROUND で実行**

```bash
LOG=/tmp/unit-all.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`。fail が出たら `-only-testing:` で isolated 再実行し parallel flake を切り分けてから判断 (CLAUDE.md「iOS テスト flake 切り分け」)。

- [ ] **Step 3: push + PR 作成**

push 直前に `git status` で HEAD ブランチ再確認、`gh pr list --head feature/issue-177-item5-emoji-rollout` で既存 PR 無しを確認。

PR description に必ず含める:

- Refs #177 (項目5 全 3 箇所 + 項目7)
- **スプラッシュ除外**: `SplashScreenView.swift:62` は #151 track のため対象外 (issue コメント指示どおり)
- **計画済み設計逸脱**: TaskSelectionRow の円塗りを白/青 → TaskCardView 同型 (brandPrimary 0.15 / gray 0.1) へ変更した理由
- **検証境界**: component テストまで。3 画面とも navigation/sheet 奥 + ASC スクショ非掲載のため視覚は手動確認推奨 (PR #192 前例)。ASC スクショ churn なし
- **TDD 逸脱**: Task 4 は正実装へのテスト強化のため red 無し、mutation 検証で代替 (結果を記載)
- 項目7 が AND 化不可分岐に入った場合はその実証結果
- 末尾: 🤖 Generated with [Claude Code](https://claude.com/claude-code) + session link

- [ ] **Step 4: issue #177 へ進捗コメント**

項目5 (3 箇所 + 円塗り逸脱) / 項目7 (AND 化 or 到達不能 finding) の結果と、残件 (項目6 のみ) を PR 番号付きでコメントする。文面は PR merge 確認後に投稿。

## 項目6 の扱い

本 plan のスコープ外 (user 判断待ち: 別 PR / issue 分離 / epic 継続のいずれか)。ツーリング (撮影スクリプト + UITest) は本 PR の製品 UI 変更と別目的のため同梱しない。
