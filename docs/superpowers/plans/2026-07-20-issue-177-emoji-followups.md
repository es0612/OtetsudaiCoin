# Issue #177 項目1〜3: タスク絵文字アイコン残課題 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** #148 の follow-up 3 件を消化する — (1) TutorialTaskCardView を実 UI と同じ絵文字カードデザインへ追随、(2) DEBUG サンプルタスクに明示 icon を付与し「全部 ✨」を解消、(3) #73 由来の TaskCardView テスト 2 件の弱さ(en locale false positive / 無条件 pass)を修正。

**Architecture:** (1) は `TaskCardView` の確立済みパターン(絵文字 Text + brandPrimary 選択表現)を `TutorialTaskCardView` へ移植。(2) は `sampleHelpTasks()` の specs タプルに icon を追加(DEBUG 専用・migration 不要)。(3) はテストのみの変更で、predicate 強化 + findAll ベース不在 assert へ書き換え。

**Tech Stack:** SwiftUI / XCTest / ViewInspector(findAll ベース、`find(viewWithAccessibilityIdentifier:)` は iOS 26 + ViewInspector 0.10.2 で systematic に効かないため使用禁止)。`PBXFileSystemSynchronizedRootGroup` のため新規テストファイルは配置のみで認識。

## Global Constraints

- branch: `feature/issue-177-emoji-followups`(origin/main 起点)
- テスト実行: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/<TestClass> 2>&1 | tail -20`(`** TEST SUCCEEDED / FAILED **` 文言で判定、exit code 不可、**FOREGROUND 実行必須・background 禁止**)
- 色は `AccessibilityColors.brandPrimary` の**定数参照**(hex 直書き禁止)
- `xcodebuild test` の clone simulator は **en_US 既定で起動する**(TaskCardViewTests.swift:72-77 の観測記録参照)。locale 依存 assert を書かない
- coinInfo の描画は ja `"10コイン"` / en `"10 Coins"`(xcstrings `%lldコイン` → `%lld Coins` 確認済み)。existingCountRow は ja `"すでに 1 件記録済み"` / en `"Already recorded 1 time"`(plural variations)
- commit footer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh`

---

### Task 1: TutorialTaskCardView を displayIcon ベースの新デザインへ追随 (#177 項目1)

**Files:**
- Create: `app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:428-477`(`TutorialTaskCardView` struct 全体)

**Interfaces:**
- Consumes: `HelpTask.displayIcon: String`(明示 icon → `defaultIconsByName` → ✨ の順で解決、HelpTask.swift:96-99)/ `AccessibilityColors.brandPrimary` / `AppRadius.large`
- Produces: なし(View の内部変更のみ。`TutorialTaskCardView(task:isSelected:onTap:)` のシグネチャ不変)

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// TutorialTaskCardView (RecordTutorialView.swift 内宣言) のコンポーネントテスト。
///
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かない既知回帰があるため (CLAUDE.md「SwiftUI View テスト戦略」節)、
/// findAll(ViewType.Text.self) / findAll(ViewType.Shape.self) ベースで検証する。
/// TaskCardViewTests と同型 (#148 で確立したパターンの Tutorial 版、#177 項目1)。
@MainActor
final class TutorialTaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: 0, icon: icon)
    }

    private func renderedTexts(_ view: TutorialTaskCardView) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    func testRendersExplicitIconEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🛁"), "rendered: \(texts)")
    }

    func testUnknownNameFallsBackToSparkle() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TutorialTaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let fills = try view.inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }
        // アイコン円 (brandPrimary 0.15) かカード背景 (brandPrimary 0.1) のどちらかが取得できること
        let expected: [Color] = [
            AccessibilityColors.brandPrimary.opacity(0.15),
            AccessibilityColors.brandPrimary.opacity(0.1)
        ]
        XCTAssertTrue(fills.contains { expected.contains($0) }, "observed fills: \(fills)")
    }
}
```

- [ ] **Step 2: RED を確認する**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TutorialTaskCardViewTests 2>&1 | tail -20`

Expected: `** TEST FAILED **`。旧デザインは絵文字 Text を描画しない(hands.sparkles の Image のみ)ため 4 テスト全て FAIL(testSelectedCardUsesBrandPrimaryShapes は旧 `.blue` 系 fill のため FAIL)。behavioral RED なので **skip 禁止・必ず実行**。

- [ ] **Step 3: TutorialTaskCardView を新デザインに書き換える**

`RecordTutorialView.swift` の `struct TutorialTaskCardView`(428〜477 行) 全体を以下に置き換える(TaskCardView.swift の確立パターンへ追随):

```swift
struct TutorialTaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    // 絵文字は装飾。カードの意味は displayName の Text が担うため VoiceOver から隠す
                    // (TaskCardView と同型、#84 パターン)
                    Text(task.displayIcon)
                        .font(.title2)
                        .accessibilityHidden(true)
                }

                Text(task.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AccessibilityColors.brandPrimary)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
            .padding()
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(isSelected ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
```

変更点: グレー円 + `Image(systemName: "hands.sparkles")` → `displayIcon` 絵文字 Text / 選択色 `.blue` → `AccessibilityColors.brandPrimary` / `.accessibilityAddTraits(.isSelected)` 追加(TaskCardView と同じ a11y 挙動)。

- [ ] **Step 4: GREEN を確認する**

Run: Step 2 と同じコマンド

Expected: `** TEST SUCCEEDED **`(4 テスト PASS)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift app/OtetsudaiCoinTests/Presentation/Components/TutorialTaskCardViewTests.swift
git commit -m "feat(#177): TutorialTaskCardView を絵文字カードデザインへ追随 (項目1)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh"
```

---

### Task 2: DEBUG サンプルタスクへ明示 icon 付与 (#177 項目2)

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/SampleDataService.swift:127-139`(`sampleHelpTasks()`)
- Test: `app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift`(既存 class 末尾に追記)

**Interfaces:**
- Consumes: `HelpTask(id:name:isActive:coinRate:sortOrder:icon:)`(icon は末尾引数、既定 nil)/ `HelpTask.displayIcon`
- Produces: なし(sampleHelpTasks() のシグネチャ不変)

- [ ] **Step 1: 失敗するテストを書く**

`SampleDataServiceTests.swift` の class 末尾(`testSampleHelpTasksHaveDistinctSortOrders` の後)に追記:

```swift
    /// サンプルタスク名は defaultIconsByName に無いため、明示 icon が無いと
    /// demo で全カードが ✨ フォールバックになる (#177 項目2)。
    func testSampleHelpTasksHaveExplicitIcons() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertFalse(tasks.isEmpty, "サンプルタスクが空")
        for task in tasks {
            XCTAssertNotNil(task.icon, "\(task.name) に明示 icon が無い")
            XCTAssertNotEqual(task.displayIcon, "✨", "\(task.name) が汎用 ✨ にフォールバックしている")
        }
    }
```

- [ ] **Step 2: RED を確認する**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/SampleDataServiceTests 2>&1 | tail -20`

Expected: `** TEST FAILED **`(`testSampleHelpTasksHaveExplicitIcons` が「洗い物 に明示 icon が無い」で FAIL。既存 2 テストは PASS)

- [ ] **Step 3: sampleHelpTasks() に icon を追加する**

`SampleDataService.swift` の `sampleHelpTasks()` を以下に置き換える:

```swift
    /// サンプルタスク定義。sortOrder を 0 始まりの連番で付与し、
    /// 並べ替え機能の DEBUG 検証時に決定的な初期順序を保証する (#130-⑥)。
    /// 名前は defaultIconsByName に無いため明示 icon を付与する (#177 項目2、DEBUG 専用・migration 不要)。
    static func sampleHelpTasks() -> [HelpTask] {
        let specs: [(name: String, coinRate: Int, icon: String)] = [
            ("洗い物", 10, "🧼"),
            ("洗濯物たたみ", 15, "👕"),
            ("掃除機かけ", 20, "🧹"),
            ("おもちゃの片付け", 5, "🧸"),
            ("お風呂掃除", 25, "🛁"),
            ("ゴミ出し", 10, "🗑️")
        ]
        return specs.enumerated().map { index, spec in
            HelpTask(id: UUID(), name: spec.name, isActive: true, coinRate: spec.coinRate, sortOrder: index, icon: spec.icon)
        }
    }
```

- [ ] **Step 4: GREEN を確認する**

Run: Step 2 と同じコマンド

Expected: `** TEST SUCCEEDED **`(3 テスト PASS)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Services/SampleDataService.swift app/OtetsudaiCoinTests/Domain/Services/SampleDataServiceTests.swift
git commit -m "feat(#177): DEBUG サンプルタスクに明示 icon を付与し ✨ 一色を解消 (項目2)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh"
```

---

### Task 3: TaskCardView テスト 2 件の強化 (#177 項目3)

**Files:**
- Modify: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift:24-56`(existingCountRow 3 テスト)

**Interfaces:**
- Consumes: 既存 `renderedTexts(_:)` ヘルパー(同ファイル :18-20)
- Produces: なし(テストのみの変更、プロダクトコード不変)

**背景:** (a) `test_existingCountRow_visible_whenCountIsOne` の predicate `!hasSuffix("コイン") && contains("1")` は、clone simulator の en_US 既定起動時に coinInfo が `"10 Coins"` と描画されるため、existingCountRow 不在でも "10 Coins" が "1" を含んで通る false positive。(b) `test_existingCountRow_hidden_whenCountIsZero` は `find(viewWithAccessibilityIdentifier:)` が iOS 26 で常に throw するため無条件 pass。

- [ ] **Step 1: existingCountRow 3 テストを書き換える**

`TaskCardViewTests.swift` の `// MARK: - #73 existingCountRow` 節(24〜56 行)を以下に置き換える:

```swift
    // MARK: - #73 existingCountRow

    /// coinInfo (ja "10コイン" / en "10 Coins") を除外した Text に判定文字列が現れるか。
    /// clone simulator は en_US 既定で起動する (下記 tapToSelectVariants のコメント参照) ため、
    /// ja suffix だけの除外だと "10 Coins" が数字を含んで false positive になる (#177 項目3)。
    private func nonCoinTexts(_ texts: [String]) -> [String] {
        texts.filter { !$0.hasSuffix("コイン") && !$0.hasSuffix("Coins") }
    }

    func test_existingCountRow_hidden_whenCountIsZero() throws {
        // 旧実装の XCTAssertThrowsError(find(viewWithAccessibilityIdentifier:)) は
        // iOS 26 + ViewInspector 0.10.2 で当該 API が常に throw するため無条件 pass だった (#177 項目3)。
        // findAll ベースで「coinInfo 以外に数字を含む Text が無い」ことを直接 assert する。
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 0, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertFalse(
            nonCoinTexts(texts).contains { $0.contains(where: \.isNumber) },
            "existingCount(0) なのに件数表示の Text が描画されている。rendered: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsOne() throws {
        // 文言を exact match しないため locale / 文言変更には依存しない
        // (ja "すでに 1 件記録済み" / en "Already recorded 1 time" のどちらでも "1" を含む)。
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 1, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(
            nonCoinTexts(texts).contains { $0.contains("1") },
            "existingCount(1) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 3, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(
            nonCoinTexts(texts).contains { $0.contains("3") },
            "existingCount(3) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }
```

- [ ] **Step 2: テストが PASS することを確認する**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TaskCardViewTests 2>&1 | tail -20`

Expected: `** TEST SUCCEEDED **`(全 9 テスト PASS。強化はテスト側のみでプロダクト挙動は正しいため RED は無い)

- [ ] **Step 3: mutation 検証 — 強化後テストが regression を検出できることを実証する**

テストのみの変更で通常の RED が無いため、mutation で検出力を実証する(「未検証の traversal に PASS が依存するテストは観測値 dump + 検出力実証」の CLAUDE.md 方針):

1. `test_existingCountRow_hidden_whenCountIsZero` の `existingCount: 0` を一時的に `existingCount: 1` へ変更
2. Step 2 と同じコマンドを実行 → Expected: `** TEST FAILED **`(当該テストのみ。旧実装なら PASS してしまうケース = 無条件 pass の解消を実証)
3. `existingCount: 0` へ戻す
4. `test_existingCountRow_visible_whenCountIsOne` の `existingCount: 1` を一時的に `existingCount: 0` へ変更
5. 実行 → Expected: `** TEST FAILED **`(旧 predicate なら en locale で "10 Coins" にマッチして PASS してしまうケース = false positive の解消を実証)
6. `existingCount: 1` へ戻し、Step 2 と同じコマンドで `** TEST SUCCEEDED **` を最終確認

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift
git commit -m "test(#177): existingCountRow テストの false positive / 無条件 pass を解消 (項目3)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WbCyy2e8ySmrecnDphvqwh"
```

---

### Task 4: unit 全体 + PR 作成(main session 実行)

**Files:**
- なし(検証と PR 作成のみ)

- [ ] **Step 1: unit テスト全体を回す**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests 2>&1 | tail -20`

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: 削除シンボルの残存参照 grep**

hands.sparkles を TutorialTaskCardView から除去したので、**test / UITests ターゲット含めて** grep(削除系 verification ルール):

```bash
grep -rn "hands.sparkles" app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests --include="*.swift"
```

Expected: TutorialTaskCardView 由来の参照は消えている。SplashScreenView / HelpRecordEditView / HelpHistoryView / TaskManagementView の 4 箇所は #177 項目5(スコープ外・任意)なので**残っていて正しい**。

- [ ] **Step 3: push + PR 作成**

`git status` で HEAD が `feature/issue-177-emoji-followups` であることを再確認し、`gh pr list --head feature/issue-177-emoji-followups` で既存 PR が無いことを確認してから:

```bash
git push -u origin feature/issue-177-emoji-followups
gh pr create --title "feat(#177): 絵文字アイコン残課題 項目1〜3 (Tutorial カード追随・サンプル icon・テスト強化)" --body "..."
```

PR body には #177 項目1〜3 への対応内容、項目4〜6 はスコープ外で epic 継続、mutation 検証結果(Task 3 Step 3)を記載。

- [ ] **Step 4: Issue #177 に進捗コメント**

`gh issue comment 177` で「項目1〜3 を PR #NNN で対応、項目4(release checklist)・5・6 は未着手のまま epic 継続」と記録する。
