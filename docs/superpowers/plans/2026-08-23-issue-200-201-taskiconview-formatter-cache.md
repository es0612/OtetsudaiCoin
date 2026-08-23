# Issue #200 + #201: TaskIconView 共通化 + timeString formatter cache 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PR #198 の whole-branch review が検出した 2 つの follow-up を 1 PR で解消する — #201: `HelpHistoryView.timeString` が行 render ごとに `DateFormatter` を生成する perf 問題を locale キーの cache で解消。#200: displayIcon 絵文字 + 選択円塗りの verbatim 三重複を `TaskIconView` component へ集約し、テスト側の重複 (renderedTexts 7 箇所 / AND assert ブロック / `@MainActor` 位置不統一) を Helpers へ共通化。

**Architecture:** #201 は `HelpHistoryView` の static helper 群に `@MainActor` の formatter cache を足すだけ (View body = MainActor からのみ呼ばれる)。#200 は `Presentation/Components/TaskIconView.swift` を新設し、**verbatim 重複の 3 site のみ** (TaskCardView / TutorialTaskCardView / TaskSelectionRow) を置換する。円塗り 2 色は `AccessibilityColors` の named constant へ hoist。リスク仮説「findAll(Text/Shape) が親 View から custom subview 内部へ traverse できるか」(iOS 26 + ViewInspector 0.10.2 で未実証) は Task 4 冒頭の TaskCardView swap 直後のテスト実行で最初に検証する。

**Tech Stack:** SwiftUI / XCTest + ViewInspector 0.10.2 / xcodebuild (iPhone 17 Pro Max simulator、2026-08-23 実在確認済み)

**Spec:** GitHub Issue #200・#201 本文 + #200 のコメント (claude-review bot 指摘: `@MainActor` 位置統一) が仕様。独立 spec ドキュメントなし。

## Global Constraints

- テストコマンドは FOREGROUND 実行、判定は `grep -E -A6 '\*\* TEST|Failing tests:'` で判定行を直接抽出する (exit code / tail 判定不可)
- destination: `platform=iOS Simulator,name=iPhone 17 Pro Max` / project: `app/OtetsudaiCoin.xcodeproj` / scheme: `OtetsudaiCoin`
- 新規 .swift は所定ディレクトリに置くだけで自動認識 (`PBXFileSystemSynchronizedRootGroup`)。pbxproj 編集不要
- TDD red の skip は (a) コンパイルエラー確定の場合のみ許可し、commit メッセージに skip 理由を明記する
- 色比較は hex リテラル直書きではなく `AccessibilityColors` の定数参照で行う
- コミットは issue 単位で分け、PR description で commit → issue の対応を map する

## スコープ判断 (PR description / issue close コメントに転記すること)

- **#200 の「3〜6 site」のうち集約するのは verbatim 重複の 3 site のみ**: `TaskCardView.taskIcon` (50pt 円 / .title2)、`TutorialTaskCardView` (RecordTutorialView.swift:436-446、50pt 円 / .title2)、`TaskSelectionRow` (HelpRecordEditView.swift:166-173、32pt 円 / .title3)。
- **意図的に残す 2 site**: `HelpRecordRow` (HelpHistoryView.swift:338-353) はテーマカラーグラデリング + 内側適応色ディスクの別デザイン、`TaskRowView` (TaskManagementView.swift:123-128) は円なしの素 Text + minWidth。強制的に統合すると誰も求めていない style enum が必要になり (YAGNI)、#151/#155 で再デザインされる可能性もある。
- **site 数の整合**: issue 本文の「6 site」は grep 上の `displayIcon` 出現数で、表示 site は実際には 5 (HelpTask.swift:96 は定義、TaskManagementView:256 はフォーム state 代入で表示でない)。

---

### Task 1: #201 timeString の formatter cache 化 (+ HelpHistoryViewTests の @MainActor クラスレベル化)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:263-273` (timeString)
- Test: `app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift`

**Interfaces:**
- Consumes: 既存 `HelpHistoryView.timeString(from:locale:)` (HelpRecordRow.body:362 から呼ばれる)
- Produces: `@MainActor static func timeFormatter(locale: Locale) -> DateFormatter` (cache された instance を返す)。`timeString` は signature 不変だが `@MainActor` が付く

**設計メモ:** cache を `@MainActor` にすると **actor isolation チェックは strict-concurrency レベルに関係なく効く**ため、現在 isolation 注釈なしの `HelpHistoryViewTests` からの同期呼び出しがコンパイルエラーになる。クラスレベル `@MainActor` 付与を本 Task に含める (これは #200 コメントの「`@MainActor` はクラスレベルへ統一」とも整合)。呼び出し元の `HelpRecordRow.body` は View body = MainActor なので変更不要。

- [ ] **Step 1: 失敗するテストを書く** — `HelpHistoryViewTests` に以下を追加し、クラス宣言に `@MainActor` を付ける

```swift
// クラス宣言を変更 (#200 の @MainActor クラスレベル統一と同方針):
@MainActor
final class HelpHistoryViewTests: XCTestCase {
```

```swift
    // MARK: - timeFormatter cache (#201)

    /// 同一 locale では formatter instance が再利用されること (行 render ごとの生成コスト解消)。
    func testTimeFormatterIsCachedPerLocale() {
        let ja1 = HelpHistoryView.timeFormatter(locale: Locale(identifier: "ja_JP"))
        let ja2 = HelpHistoryView.timeFormatter(locale: Locale(identifier: "ja_JP"))
        XCTAssertTrue(ja1 === ja2, "同一 locale で formatter が再生成されている")

        let en = HelpHistoryView.timeFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertFalse(ja1 === en, "locale が異なるのに同一 formatter が返っている")
    }
```

- [ ] **Step 2: red 確認は skip (条件 (a))** — `timeFormatter` が未定義のため `BUILD FAILED` 必至のコンパイルエラー red。実行せず、Step 5 の commit メッセージに「red は timeFormatter 未定義のコンパイルエラー確定のため skip (CLAUDE.md 条件 (a))」と明記する

- [ ] **Step 3: 実装** — `HelpHistoryView.swift` の `timeString` (263-273 行) を以下へ置換

```swift
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
```

- [ ] **Step 4: テスト実行 → PASS 確認**

```bash
LOG=/tmp/t1.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/HelpHistoryViewTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **` (既存 ja/en 非退行テスト 4 件 + 新規 cache テスト 1 件)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift \
        app/OtetsudaiCoinTests/Presentation/Views/HelpHistoryViewTests.swift
git commit -m "perf(#201): timeString の DateFormatter を locale 別 cache 化 (行 render ごとの生成を解消)

- @MainActor static cache (View body からのみ呼ばれる) + instance 再利用テスト
- HelpHistoryViewTests を @MainActor クラスレベルへ (isolation 上の必須 + #200 統一方針)
- TDD red は timeFormatter 未定義のコンパイルエラー確定のため skip (CLAUDE.md 条件 (a))"
```

---

### Task 2: テスト共通 helper (renderedTexts / renderedFills / AND assert) + @MainActor 統一

**Files:**
- Create: `app/OtetsudaiCoinTests/Helpers/ViewInspectorHelpers.swift`
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift` (private renderedTexts 削除・helper 呼び出し化・AND assert を共通 helper 化)
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift` (同上)
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TaskRowViewTests.swift` (private renderedTexts 削除)
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/HelpRecordRowTests.swift:99,106` (inline 2 箇所)
- Modify: `app/OtetsudaiCoinTests/Presentation/Views/HelpRecordEditViewTests.swift:101,110` (inline 2 箇所 + @MainActor クラスレベル化)
- Modify: `app/OtetsudaiCoinTests/Presentation/Views/StoreLoadErrorViewTests.swift:22` (inline 1 箇所)

**Interfaces:**
- Produces: `View.renderedTexts() throws -> [String]`、`View.renderedFills() throws -> [Color]`、`XCTestCase.assertBrandPrimaryIconAndCardFills(_:file:line:) throws` — Task 3 / Task 4 のテストはこれらを使う

**注:** `RecordCalendarViewTests:173` は取得済み配列の compactMap で形が異なるため対象外。これは純テストリファクタで **新規 red は無い** — 既存 suite green がゲート (mutation 検証済みの AND テストが green を保つこと自体が担保)。

- [ ] **Step 1: helper ファイルを作成**

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// ViewInspector 共通 helper (#200)。
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かない既知回帰があるため (CLAUDE.md「SwiftUI View テスト戦略」節)、
/// findAll ベースで blocker を跨いで収集するパターンを 1 箇所に固定する。
@MainActor
extension View {
    /// 描画された全 Text の文字列を列挙する。
    func renderedTexts() throws -> [String] {
        try inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    /// 描画された全 Shape の fill 色を列挙する。
    func renderedFills() throws -> [Color] {
        try inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }
    }
}

extension XCTestCase {
    /// #177 項目7 で確立した AND assert (アイコン円 0.15 + カード背景 0.1 を個別検証) の共通化 (#200)。
    /// OR だと片方だけの色 regression を検出できない。両辺の検出力は PR #198 の mutation 検証で実証済み。
    @MainActor
    func assertBrandPrimaryIconAndCardFills(
        _ view: some View, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let fills = try view.renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.15)),
            "アイコン円の brandPrimary 0.15 が無い / observed fills: \(fills)", file: file, line: line
        )
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.1)),
            "カード背景の brandPrimary 0.1 が無い / observed fills: \(fills)", file: file, line: line
        )
    }
}
```

- [ ] **Step 2: 各テストを helper 呼び出しへ置換**
  - `TaskCardViewTests`: private `renderedTexts(_:)` func (18-20 行) を削除し、呼び出しを `try renderedTexts(view)` → `try view.renderedTexts()` へ (6 箇所)。`testSelectedCardUsesBrandPrimaryShapes` の body を `try assertBrandPrimaryIconAndCardFills(view)` へ。`testUnselectedCardBackgroundUsesAdaptiveColor` の findAll 2 行を `try view.renderedFills()` へ
  - `TutorialTaskCardViewTests`: 同様 (private func 削除、`testSelectedCardUsesBrandPrimaryShapes` を共通 helper 化)
  - `TaskRowViewTests`: private renderedTexts func を削除して helper 呼び出しへ
  - `HelpRecordRowTests` / `HelpRecordEditViewTests` / `StoreLoadErrorViewTests`: inline の `try X.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }` を `try X.renderedTexts()` へ
  - `HelpRecordEditViewTests`: クラス宣言へ `@MainActor` を付け、メソッド/`setUp` の個別 `@MainActor` を全削除 (#200 コメントの統一項目)

- [ ] **Step 3: 対象テストを実行 → 全 PASS 確認**

```bash
LOG=/tmp/t2.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests \
  -only-testing:OtetsudaiCoinTests/TutorialTaskCardViewTests \
  -only-testing:OtetsudaiCoinTests/TaskRowViewTests \
  -only-testing:OtetsudaiCoinTests/HelpRecordRowTests \
  -only-testing:OtetsudaiCoinTests/HelpRecordEditViewTests \
  -only-testing:OtetsudaiCoinTests/StoreLoadErrorViewTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinTests
git commit -m "test(#200): ViewInspector 共通 helper (renderedTexts/renderedFills/AND assert) を Helpers へ抽出、@MainActor をクラスレベルへ統一

純テストリファクタのため新規 red なし (既存 suite green + mutation 検証済み AND テストの green 維持がゲート)"
```

---

### Task 3: TaskIconView component + AccessibilityColors 定数 hoist + component テスト

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/Components/TaskIconView.swift`
- Modify: `app/OtetsudaiCoin/Utils/AccessibilityColors.swift` (Brand Colors 節の末尾、brandSurfaceWarm:132 の後に 2 定数追加)
- Test: `app/OtetsudaiCoinTests/Presentation/Components/TaskIconViewTests.swift` (新規)

**Interfaces:**
- Consumes: `HelpTask.displayIcon` (Domain/Entities/HelpTask.swift:96)、Task 2 の `renderedTexts()` / `renderedFills()`
- Produces: `TaskIconView(task: HelpTask, isSelected: Bool, size: CGFloat = 50, font: Font = .title2)`、`AccessibilityColors.taskIconSelectedFill` / `.taskIconUnselectedFill` — Task 4 が 3 site の置換に使う

- [ ] **Step 1: 失敗するテストを書く** — `TaskIconViewTests.swift` を新規作成

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// TaskIconView (displayIcon 絵文字 + 選択円塗りの共通 component、#200) のテスト。
/// findAll ベース (CLAUDE.md「SwiftUI View テスト戦略」節) + トークン定数の等価比較。
@MainActor
final class TaskIconViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: 0, icon: icon)
    }

    func testRendersExplicitIconEmoji() throws {
        let view = TaskIconView(task: makeTask(icon: "🧹"), isSelected: false)
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testUnknownNameFallsBackToSparkle() throws {
        let view = TaskIconView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false)
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    func testSelectedCircleUsesSelectedFillToken() throws {
        let fills = try TaskIconView(task: makeTask(), isSelected: true).renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.taskIconSelectedFill),
            "選択時の円が taskIconSelectedFill でない / observed fills: \(fills)"
        )
    }

    func testUnselectedCircleUsesUnselectedFillToken() throws {
        let fills = try TaskIconView(task: makeTask(), isSelected: false).renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.taskIconUnselectedFill),
            "非選択時の円が taskIconUnselectedFill でない / observed fills: \(fills)"
        )
    }
}
```

- [ ] **Step 2: red 確認は skip (条件 (a))** — `TaskIconView` / 定数が未定義のためコンパイルエラー red 確定。commit メッセージに明記

- [ ] **Step 3: 実装** — まず `AccessibilityColors.swift` の `brandSurfaceWarm` (132 行) の直後に追加:

```swift
    /// タスクアイコン円の塗り (選択時)。TaskIconView で使用 (#200 で 3 site から hoist)。
    static let taskIconSelectedFill = brandPrimary.opacity(0.15)

    /// タスクアイコン円の塗り (非選択時)。TaskIconView で使用 (#200 で 3 site から hoist)。
    static let taskIconUnselectedFill = Color.gray.opacity(0.1)
```

次に `TaskIconView.swift` を新規作成:

```swift
import SwiftUI

/// displayIcon 絵文字 + 選択状態の円塗りを表示する共通アイコン (#200)。
///
/// TaskCardView / TutorialTaskCardView / TaskSelectionRow で verbatim 重複していた
/// ZStack + Circle + Text を集約する。tint / font 変更時の追随がここ 1 箇所で済む。
///
/// - ZStack + 非拘束 Text: 固定 frame + overlay/background だと AX サイズの
///   Dynamic Type で絵文字が truncate する (#177 PR #198 で確立したパターン)。
/// - 絵文字は装飾。意味は隣接する displayName の Text が担うため VoiceOver から隠す (#84 パターン)。
struct TaskIconView: View {
    let task: HelpTask
    let isSelected: Bool
    var size: CGFloat = 50
    var font: Font = .title2

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected
                    ? AccessibilityColors.taskIconSelectedFill
                    : AccessibilityColors.taskIconUnselectedFill)
                .frame(width: size, height: size)

            Text(task.displayIcon)
                .font(font)
                .accessibilityHidden(true)
        }
    }
}
```

- [ ] **Step 4: テスト実行 → PASS 確認**

```bash
LOG=/tmp/t3.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/TaskIconViewTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskIconView.swift \
        app/OtetsudaiCoin/Utils/AccessibilityColors.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TaskIconViewTests.swift
git commit -m "feat(#200): TaskIconView component 新設 + 円塗り 2 色を AccessibilityColors へ hoist

- TDD red は TaskIconView / 定数未定義のコンパイルエラー確定のため skip (CLAUDE.md 条件 (a))"
```

---

### Task 4: 3 site を TaskIconView へ置換 (TaskCardView 先行 = findAll traverse の実証ゲート) + mutation 検証

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift:58-69` (taskIcon)
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:436-446` (TutorialTaskCardView 内 ZStack)
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift:158-173` (TaskSelectionRow 内 ZStack)
- Modify (必要時のみ): `app/OtetsudaiCoinTests/Presentation/Views/HelpRecordEditViewTests.swift:127-132` (gray.opacity(0.1) 参照 → `taskIconUnselectedFill` 定数参照へ)

**Interfaces:**
- Consumes: Task 3 の `TaskIconView(task:isSelected:size:font:)` と fill 定数

**リスクゲート:** 「親 View への `findAll(Text/Shape)` が custom subview (TaskIconView) の内部まで traverse できるか」は本リポで**未実証** (既存実績は component 直接 inspect のみ、#106 ルールの「未検証機構」領域)。TaskCardView を最初に swap して即テストし、fills/texts の dump で即診断する。**FAIL した場合の fallback**: 親テストは `find(TaskIconView.self)` + `actualView().isSelected` の wiring 検証に切替え、アイコン円 fill の assert は TaskIconViewTests 側へ移し、カード背景 (brandPrimary 0.1) の assert は親テストに残す。fallback 採用時は commit メッセージ + PR `## Plan からの逸脱` に明記。

- [ ] **Step 1: TaskCardView を置換** — `taskIcon` (58-69 行) を以下へ:

```swift
    private var taskIcon: some View {
        // ZStack + 非拘束 Text / VoiceOver hidden / 円塗りトークンは TaskIconView に集約 (#200)
        TaskIconView(task: task, isSelected: isSelected)
    }
```

- [ ] **Step 2: 実証ゲート — TaskCardViewTests を即実行**

```bash
LOG=/tmp/t4a.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **` = findAll が component 境界を跨げると実証 → Step 3 へ。FAIL なら上記 fallback に切替えて (assert 移設後に green を確認して) から Step 3 へ

- [ ] **Step 3: TutorialTaskCardView を置換** — RecordTutorialView.swift:436-446 の ZStack ブロックを:

```swift
                // ZStack + 非拘束 Text / VoiceOver hidden / 円塗りトークンは TaskIconView に集約 (#200)
                TaskIconView(task: task, isSelected: isSelected)
```

- [ ] **Step 4: TaskSelectionRow を置換** — HelpRecordEditView.swift:158-173 のコメント + ZStack ブロックを:

```swift
                // タスクアイコン (32pt / .title3 は行レイアウト用の縮小版)。
                // ZStack + 非拘束 Text / VoiceOver hidden / 円塗りトークンは TaskIconView に集約 (#200)
                TaskIconView(task: task, isSelected: isSelected, size: 32, font: .title3)
```

- [ ] **Step 5: テスト側の色参照を定数へ揃える** — `HelpRecordEditViewTests.testTaskSelectionRowCircleFillFollowsSelectionState` の `AccessibilityColors.brandPrimary.opacity(0.15)` → `AccessibilityColors.taskIconSelectedFill`、`Color.gray.opacity(0.1)` → `AccessibilityColors.taskIconUnselectedFill` (single source 化。値は同一なので挙動不変)

- [ ] **Step 6: 関連 component テストを一括実行 → PASS 確認**

```bash
LOG=/tmp/t4b.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests \
  -only-testing:OtetsudaiCoinTests/TutorialTaskCardViewTests \
  -only-testing:OtetsudaiCoinTests/TaskIconViewTests \
  -only-testing:OtetsudaiCoinTests/HelpRecordEditViewTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: mutation 検証** — 置換は pure refactor で red が原理的に出ないため、CLAUDE.md「厳格化テスト変更では mutation 検証を red の代替とする」ルールに従い検出力を実証する: `TaskIconView` の `taskIconSelectedFill` を一時的に `taskIconUnselectedFill` へ書き換え → Step 6 のコマンドを再実行して **TaskCardViewTests / TutorialTaskCardViewTests / TaskIconViewTests / HelpRecordEditViewTests が FAIL** することを確認 → revert して再実行、GREEN 復帰を確認

- [ ] **Step 8: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift \
        app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift \
        app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift \
        app/OtetsudaiCoinTests/Presentation/Views/HelpRecordEditViewTests.swift
git commit -m "refactor(#200): displayIcon 円アイコンの verbatim 3 site を TaskIconView へ集約

- findAll(Text/Shape) が component 境界を跨いで traverse できることを TaskCardView swap 直後のテストで実証
- pure refactor のため red なし。selected fill の mutation 検証で 4 テストクラスの検出力を確認 → revert 済み
- HelpRecordRow (テーマグラデリング) / TaskRowView (円なし素 Text) は別デザインのため意図的に対象外"
```

---

### Task 5: 全 unit suite + whole-branch レビュー + PR 作成

**Files:**
- なし (検証と PR 作成のみ)

- [ ] **Step 1: 全 unit テストを実行**

```bash
LOG=/tmp/t5.log; xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests > "$LOG" 2>&1; \
  grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`。FAIL したら `-only-testing:` の isolated 再実行で parallel flake と regression を切り分ける

- [ ] **Step 2: whole-branch レビュー** — inline 実行でも省略不可 (CLAUDE.md 2026-08-15 ルール)。`git diff origin/main...HEAD` を全読みし、spec (#200/#201) との突合 + code-quality 観点 (特に: cache の isolation、helper 抽出でのコスト特性変化、コメントの stale 化) でレビューする。指摘があれば fix commit を積む

- [ ] **Step 3: push 直前の HEAD 再確認 + 既存 PR 確認**

```bash
git status --short --branch
gh pr list --head feature/issue-200-201-taskiconview-and-formatter
```

- [ ] **Step 4: push + PR 作成** — PR description に含めること: (a) 冒頭のスコープ判断節 (3/6 site の意図的限定 + site 数の整合)、(b) commit → issue の対応表、(c) `## Plan からの逸脱` (あれば。fallback 採用時は必須)、(d) `Closes #200` / `Closes #201`

- [ ] **Step 5: #200 へ close 前提のコメントを 1 件投稿** — 「HelpRecordRow (グラデリング) / TaskRowView (素 Text) は別デザインのため意図的に未集約 (#151/#155 の再デザインで再検討)」というスコープ判断を、PR link と共に issue 側にも残す

---

## Self-Review 済み事項

- **Spec coverage**: #201 (cache + 非退行テスト) → Task 1。#200 項目1 (円塗り ternary 三重複) → Task 3+4。項目2 (絵文字 unit 6 箇所) → 3 site 集約 + スコープ判断節で残り 2 site の理由を明文化。項目3a (AND assert 重複) / 3b (renderedTexts 7 箇所) → Task 2。コメント項目 (@MainActor 統一) → Task 1 (HelpHistoryViewTests) + Task 2 (HelpRecordEditViewTests)。
- **Type consistency**: `TaskIconView(task:isSelected:size:font:)` の引数順は Swift の「let 先・default 後」に従い全 Task で一致。`renderedTexts()`/`renderedFills()`/`assertBrandPrimaryIconAndCardFills(_:file:line:)` の名前は Task 2 定義と Task 3/4 使用で一致。
- **既存テスト名の温存**: TaskCardViewTests / TutorialTaskCardViewTests のテストメソッド名は変えない (helper 化は body のみ)。
