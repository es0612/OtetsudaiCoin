# Issue #175 項目1: カレンダー選択日 circle の brandPrimary 化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RecordCalendarView の選択日サークルを旧ブランド色 `primaryBlue` から `brandPrimary`(オレンジ #E8590C) へ変更し、#147 で確立したオレンジ×ティールの世界観に揃える(#175 findings 1、優先: 高)。

**Architecture:** 1 行の色定数差し替え + テスト期待値の追随のみ。記録ドット(successGreen)は semantic なので不変。選択日の文字色(white)はオレンジ地でもコントラスト維持のため不変。

**Tech Stack:** SwiftUI / XCTest / ViewInspector(findAll + `fillShapeStyle(Color.self)` 定数比較、#84 で確立)。

## Global Constraints

- branch: `feature/issue-175-calendar-brandprimary`(作成済み・origin/main 起点)
- テスト実行: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests 2>&1 | tail -20`(`** TEST SUCCEEDED / FAILED **` 文言で判定、exit code 不可、**FOREGROUND 実行必須・background 禁止**)
- 色は `AccessibilityColors.brandPrimary` の**定数参照**(hex リテラル直書き禁止)
- 記録ドットの `AccessibilityColors.successGreen` には触らない
- commit footer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh`

---

### Task 1: 選択日サークルを brandPrimary へ変更 (TDD)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift:94`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift:86-103`

**Interfaces:**
- Consumes: `AccessibilityColors.brandPrimary`(`app/OtetsudaiCoin/Utils/AccessibilityColors.swift:119` 定義済み)
- Produces: なし(末端の View 変更)

- [ ] **Step 1: テスト期待値を brandPrimary に変更する(RED になる書き換え)**

`RecordCalendarViewTests.swift` の `test_selectionCircle_shownForSelectedDayInMonth`(86〜103 行) を以下に置き換える(doc コメントの色名・hex 記載とアサーションメッセージも追随):

```swift
    /// 表示月内の選択日 (12) には brandPrimary の選択リングがあり、非選択日 (10) には無い。
    /// dot テストと同じ findAll(ViewType.Shape.self) + fillShapeStyle 方式で
    /// Circle の fill 色 (#E8590C) を直接確認する (#175 で primaryBlue から変更)。
    func test_selectionCircle_shownForSelectedDayInMonth() throws {
        let view = makeView(selectedDay: 12)
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        let btn12 = allButtons.first(where: { (try? $0.find(text: "12")) != nil })
        let btn10 = allButtons.first(where: { (try? $0.find(text: "10")) != nil })
        let selectionColor = AccessibilityColors.brandPrimary
        XCTAssertTrue(
            btn12.map { shapeFills(in: $0).contains(selectionColor) } ?? false,
            "選択日(12)の Circle に brandPrimary fill がない。allButtons=\(allButtons.count), fills=\(btn12.map { shapeFills(in: $0) } ?? [])"
        )
        XCTAssertFalse(
            btn10.map { shapeFills(in: $0).contains(selectionColor) } ?? false,
            "非選択日(10)に余計な brandPrimary 選択リングがある。fills=\(btn10.map { shapeFills(in: $0) } ?? [])"
        )
    }
```

- [ ] **Step 2: RED を確認する**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/RecordCalendarViewTests 2>&1 | tail -20`

Expected: `** TEST FAILED **`、失敗は `test_selectionCircle_shownForSelectedDayInMonth` の「選択日(12)の Circle に brandPrimary fill がない」のみ(実装がまだ primaryBlue のため)。他 6 テストは PASS。

- [ ] **Step 3: 実装を変更する**

`RecordCalendarView.swift:94` の 1 行を変更:

```swift
                    .background {
                        if isSelected {
                            Circle().fill(AccessibilityColors.brandPrimary)
                        }
                    }
```

(変更は `AccessibilityColors.primaryBlue` → `AccessibilityColors.brandPrimary` のみ)

- [ ] **Step 4: GREEN を確認する**

Run: Step 2 と同じコマンド

Expected: `** TEST SUCCEEDED **`(RecordCalendarViewTests 全 7 テスト PASS)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/RecordCalendarView.swift app/OtetsudaiCoinTests/Presentation/Components/RecordCalendarViewTests.swift
git commit -m "fix(#175): カレンダー選択日サークルを brandPrimary 化 (旧 primaryBlue 残存の解消)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh"
```

---

### Task 2: 視覚検証 + unit 全体 + PR 作成(main session 実行)

**Files:**
- なし(検証と PR 作成のみ。スクショ出力は discard する)

- [ ] **Step 1: unit テスト全体を回す**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests 2>&1 | tail -20`

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: 視覚検証(一次目視)**

`./scripts/capture-asc-screenshots.sh` を実行し、`docs/screenshots/asc/v1.1.x/ja/02-record.png` を Read で開いて選択日サークルがオレンジ(brandPrimary)になっていることを目視確認する。確認後、**必ず discard する**(ASC artifact を feature PR に混ぜない):

```bash
git checkout -- docs/screenshots/
git status --short   # docs/screenshots/ に差分が無いことを確認
```

- [ ] **Step 3: push + PR 作成**

`git status` で HEAD が `feature/issue-175-calendar-brandprimary` であることを再確認し、`gh pr list --head feature/issue-175-calendar-brandprimary` で既存 PR が無いことを確認してから:

```bash
git push -u origin feature/issue-175-calendar-brandprimary
gh pr create --title "fix(#175): カレンダー選択日サークルを brandPrimary 化" --body "..."
```

PR body には #175 findings 1 への参照、変更内容(1 行 + テスト追随)、視覚検証結果(スクショ一次目視済み・出力は discard)を記載。

- [ ] **Step 4: Issue #175 に進捗コメント**

`gh issue comment 175` で「findings 1 を PR #NNN で対応、findings 2〜4 は未着手のまま epic 継続」と記録する。
