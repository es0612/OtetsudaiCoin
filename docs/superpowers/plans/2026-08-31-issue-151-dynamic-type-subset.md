# #151 Dynamic Type サブセット (TaskCardView 固定 height / カレンダー日セル固定 frame) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** #151 epic の「Dynamic Type 4」項目 — TaskCardView の固定 `height: 150` とカレンダー日セルの固定 frame + `.system(size: 15)` を Dynamic Type 追従に改修し、AX サイズでのクリップを解消する。

**Architecture:** TaskCardView は `.frame(height:)` → `.frame(minHeight:)` 化 (#198 の `minWidth` 前例と同型)。RecordCalendarView は日番号フォントを `.appFont(.secondaryInfo)` (= `.subheadline` ≈15pt、スケーリング対応) へ、セル geometry を `@ScaledMetric(relativeTo: .subheadline)` へ置換。filler セルの高さも同メトリクスから導出して行崩れを防ぐ。

**Tech Stack:** SwiftUI (`@ScaledMetric`), ViewInspector 0.10.2 (findAll ベース、iOS 26 制約準拠), XCTest

**Spec:** GitHub Issue #151 本文 + 2026-07-05 コメントの「Dynamic Type / タップ領域の実課題 4」(TaskCardView.swift:14 の固定 height 150、RecordCalendarView.swift:89-91 の固定 frame + size:15 が大文字設定でクリップ)。単独の spec ドキュメントはなし。

## Global Constraints

- ViewInspector の accessibilityIdentifier 解決は iOS 26 で不可 → 新規テストは `findAll(ViewType.Text/Button/Shape.self)` ベースで書く (CLAUDE.md § SwiftUI View テスト戦略)
- 未実証の traversal (`flexFrame()` は本リポ初出) に PASS が依存するテストは assertion message に観測値を dump する (#106 ルール)
- xcodebuild は FOREGROUND 実行、判定は `grep -E -A6 '\*\* TEST|Failing tests:'` で行う
- simulator destination: `platform=iOS Simulator,name=iPhone 17` (2026-08-31 に `simctl list devices available` で実在確認済み)
- テスト対象ファイル: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift` / `RecordCalendarViewTests.swift` (既存ファイルに追記)
- `@ScaledMetric` のスケーリング配線自体は ViewInspector から検証不能 → 「デフォルト geometry (30pt) とフォントスタイルを unit テストで pin、スケーリング配線はレビュー + 視覚確認で担保」を検証境界として PR description に明記する (#189 の環境値ルールと同じ扱い)
- 記録ドット (6pt Circle) は固定のまま維持する (意図的選択: 装飾ドットで情報は accessibilityLabel が伝えるため拡大不要)

---

### Task 1: TaskCardView の固定 height → minHeight 化

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift:22`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift`

**Interfaces:**
- Consumes: 既存 `TaskCardView(task:isSelected:isBulkMode:existingCount:onTap:)` (シグネチャ変更なし)
- Produces: card VStack が `.frame(minHeight: 150)` を持つ (固定 height なし)。呼び出し側 (RecordView の LazyVGrid) は変更不要

- [ ] **Step 1: Write the failing test**

`TaskCardViewTests.swift` に追記 (既存の makeView 系 helper があればそれを利用、なければ最小 init):

```swift
/// #151: AX サイズで内容がクリップしないよう、カードは固定 height ではなく
/// minHeight で下方向に伸びられること。
/// flexFrame() traversal は本リポ初出のため観測値を message に dump する (#106 ルール)。
func test_cardFrame_usesMinHeightNotFixedHeight() throws {
    // makeTask() は既存 fixture (TaskCardViewTests.swift:9-11) を再利用
    let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
    let vstacks = try view.inspect().findAll(ViewType.VStack.self)
    let flexFrames = vstacks.compactMap { try? $0.flexFrame() }
    let fixedFrames = vstacks.compactMap { try? $0.fixedFrame() }
    XCTAssertTrue(
        flexFrames.contains(where: { $0.minHeight == 150 }),
        "minHeight=150 の flexFrame が見つからない。vstacks=\(vstacks.count), flex=\(flexFrames), fixed=\(fixedFrames)"
    )
    XCTAssertFalse(
        fixedFrames.contains(where: { $0.height == 150 }),
        "固定 height=150 が残っている。fixed=\(fixedFrames)"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/TaskCardViewTests \
  2>&1 | grep -E -A6 '\*\* TEST|Failing tests:'
```

Expected: FAIL (`minHeight=150 の flexFrame が見つからない`)

- [ ] **Step 3: Write minimal implementation**

`TaskCardView.swift:22`:

```swift
// before
.frame(height: 150)
// after — #151: AX サイズの Dynamic Type で内容がクリップしないよう下方向へ伸ばせるようにする
.frame(minHeight: 150)
```

- [ ] **Step 4: Run test to verify it passes**

Step 2 と同じコマンド。Expected: `** TEST SUCCEEDED **` (TaskCardViewTests 全件 green = 既存テスト非退行も同時確認)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift
git commit -m "fix(#151): TaskCardView の固定 height 150 を minHeight 化し AX サイズのクリップを解消"
```

---

### Task 2: RecordCalendarView 日番号フォントの Dynamic Type 追従化

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift:90`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`

**Interfaces:**
- Consumes: 既存 `makeView()` helper (RecordCalendarViewTests.swift:27-52、表示月 2026-06 / today=15日)
- Produces: 日番号 Text のフォントが `AccessibilityFonts.secondaryInfo` (= `.subheadline`)

- [ ] **Step 1: Write the failing test**

`RecordCalendarViewTests.swift` に追記:

```swift
/// #151: 日番号は固定 .system(size: 15) ではなく Dynamic Type 追従フォント
/// (.appFont(.secondaryInfo) = .subheadline) であること。
func test_dayCellFont_isDynamicTypeScaling() throws {
    let view = makeView()
    let texts = try view.inspect().findAll(ViewType.Text.self)
    let day15 = texts.first(where: { (try? $0.string()) == "15" })
    let font = day15.flatMap { try? $0.attributes().font() }
    XCTAssertEqual(
        font, AccessibilityFonts.secondaryInfo,
        "日セルのフォントが Dynamic Type 追従でない。observed=\(String(describing: font)), texts=\(texts.count)"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests \
  2>&1 | grep -E -A6 '\*\* TEST|Failing tests:'
```

Expected: FAIL (observed = `.system(size: 15)`)

- [ ] **Step 3: Write minimal implementation**

`RecordCalendarView.swift:90` (dayCell 内):

```swift
// before
.font(.system(size: 15))
// after — #151: Dynamic Type 追従。.secondaryInfo = .subheadline ≈ 15pt で既定サイズは同等
.appFont(.secondaryInfo)
```

- [ ] **Step 4: Run test to verify it passes**

Step 2 と同じコマンド。Expected: `** TEST SUCCEEDED **` (既存の RecordCalendarViewTests 全件 green も確認)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift
git commit -m "fix(#151): カレンダー日番号を .system(size:15) から .appFont(.secondaryInfo) へ変更し Dynamic Type 追従化"
```

---

### Task 3: RecordCalendarView セル geometry の @ScaledMetric 化

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift:32,90-92` (filler / dayCell frame)
- Test: `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift`

**Interfaces:**
- Consumes: Task 2 適用後の dayCell (`.appFont(.secondaryInfo)`)
- Produces: `@ScaledMetric(relativeTo: .subheadline) private var dayCellSize: CGFloat = 30` と `private var fillerHeight: CGFloat { dayCellSize + 8 }` (8 = ドット 6pt + VStack spacing 2pt)。既定サイズでの geometry は現状と同一 (30×30 / filler 38)

- [ ] **Step 1: Write the pinning test (既定 geometry の characterization)**

`RecordCalendarViewTests.swift` に追記:

```swift
/// #151: @ScaledMetric 化後も既定サイズでは 30×30 の geometry を維持すること
/// (スケーリング配線自体は ViewInspector から検証不能 → 検証境界は PR description 参照)。
func test_dayCellGeometry_defaultSizeIs30() throws {
    let view = makeView()
    let texts = try view.inspect().findAll(ViewType.Text.self)
    let day15 = texts.first(where: { (try? $0.string()) == "15" })
    let frame = day15.flatMap { try? $0.fixedFrame() }
    XCTAssertEqual(frame?.width, 30, "既定サイズの日セル幅が 30 でない。observed=\(String(describing: frame))")
    XCTAssertEqual(frame?.height, 30, "既定サイズの日セル高が 30 でない。observed=\(String(describing: frame))")
}
```

- [ ] **Step 2: Run test — GREEN を確認 (red なし、理由を記録)**

Task 2 Step 2 と同じコマンド。Expected: PASS

現行実装 (リテラル 30) でも通る characterization テストのため **TDD red は原理的に発生しない**。CLAUDE.md「既存条件を厳格化するテスト変更では red の代替に mutation 検証」ルールに従い Step 4 で mutation 検証を行う。

- [ ] **Step 3: Implement @ScaledMetric**

`RecordCalendarView.swift`:

```swift
// property 追加 (struct 冒頭、cal の隣)
// #151: AX サイズの Dynamic Type でも日番号がクリップしないよう、セル geometry を
// フォント (.subheadline) と同係数でスケールさせる。記録ドット (6pt) は装飾のため固定
// (情報は accessibilityLabel が伝える)。
@ScaledMetric(relativeTo: .subheadline) private var dayCellSize: CGFloat = 30
/// filler は日セル 30 + spacing 2 + ドット 6 に相当。dayCellSize と連動させないと
/// AX サイズで nil セルを含む週だけ行高が縮んで崩れる。
private var fillerHeight: CGFloat { dayCellSize + 8 }
```

```swift
// body 内 filler (line 32)
// before
Color.clear.frame(maxWidth: .infinity).frame(height: 38)
// after
Color.clear.frame(maxWidth: .infinity).frame(height: fillerHeight)
```

```swift
// dayCell 内 (line 91)
// before
.frame(width: 30, height: 30)
// after
.frame(width: dayCellSize, height: dayCellSize)
```

- [ ] **Step 4: Mutation 検証 → revert**

`dayCellSize` の既定値を一時的に `31` へ変更 → Task 2 Step 2 のコマンドで `test_dayCellGeometry_defaultSizeIs30` が FAIL することを確認 → `30` へ戻して GREEN 復帰を確認。これで pin テストが実際に検出力を持つことを証明する。

- [ ] **Step 5: Run full RecordCalendarViewTests**

Task 2 Step 2 と同じコマンド。Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift \
        app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift
git commit -m "fix(#151): カレンダー日セル geometry を @ScaledMetric 化 (filler も連動)。mutation 検証を TDD red の代替とする"
```

---

### Task 4: 統合検証 + 視覚確認 + PR

**Files:**
- なし (検証と PR 作成のみ)

- [ ] **Step 1: Unit テスト全体を実行**

```bash
LOG=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/f6cce732-ce67-423f-aa64-32f6ac61b0f8/scratchpad/unit-tests.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests > "$LOG" 2>&1
grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`。flake が出たら `-only-testing:` で isolated 再実行して切り分け。

- [ ] **Step 2: AX サイズでの視覚確認 (before/after)**

simulator を boot し `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` で AX 最大サイズを強制 → app をビルド・起動して Record タブのカレンダー / タスクカードを screenshot で一次目視 (ios-simulator-app-verification skill 準拠)。Record タブは `@State selectedTab` のため simctl から切替不可 → `scripts/capture-asc-screenshots.sh` の流用 (02-record) で撮影し、目視後 `git checkout -- docs/screenshots/` で discard する。before は `git stash` で working tree を退避して同手順。日番号クリップの解消とカード伸長を確認し、観察結果を PR description に記載する。

- [ ] **Step 3: Whole-branch レビュー**

`/code-review` (inline 実行でも whole-branch レビュー必須の CLAUDE.md ルール)。finding が出たら修正 commit を追加。

- [ ] **Step 4: Push + PR 作成**

```bash
git status  # HEAD ブランチ再確認 (CLAUDE.md ルール)
gh pr list --head feature/issue-151-dynamic-type-subset  # 既存 PR 二重作成チェック
git push -u origin feature/issue-151-dynamic-type-subset
gh pr create --title "fix(#151): Dynamic Type サブセット — TaskCardView minHeight 化 + カレンダー日セル @ScaledMetric 化" --body "..."
```

PR body には以下を含める: (a) 対応した epic 項目 (Dynamic Type 4)、(b) 検証境界 (「@ScaledMetric のスケーリング配線は unit テスト対象外、既定 geometry pin + mutation 検証 + AX サイズ視覚確認で担保」)、(c) before/after 視覚確認の所見、(d) 記録ドット 6pt 固定の意図的選択。

- [ ] **Step 5: Merge 後の epic 進捗コメント**

merge 確認 (`gh pr view --json state,mergedAt`) 後、#151 に進捗コメントを投稿 (PR #185/#196 と同じ様式): Dynamic Type 4 を ✅ 対応済みへ移し、残件 (ダークモード 1 スプラッシュ / ダークモード 3 固定 hex 適応色化 / 提案 1 スクショ棚卸し / 提案 3 固定フォント→ScaledMetric 全体) を ⏳ 未着手として再掲。epic は open 継続。
