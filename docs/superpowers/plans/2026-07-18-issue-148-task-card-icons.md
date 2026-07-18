# Issue #148: タスクカード絵文字アイコン Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** タスクごとの絵文字アイコン表示・変更を実現し、「タップして選択」の冗長テキストを削除する(spec: `docs/superpowers/specs/2026-07-18-task-card-icons-design.md`)。

**Architecture:** `HelpTask.icon: String?` + 表示時フォールバック(`displayIcon`、既存 `displayName` と同型)。Core Data は model v4 の optional 属性追加による lightweight migration。ピッカーは `TaskIconCatalog.presets` の LazyVGrid(ChildFormView 色グリッドと同一 UX)。カードは絵文字 Text 化 + 選択表現を「枠 + 右上チェック」に簡素化し、選択色を brandPrimary へ。

**Tech Stack:** SwiftUI / Core Data / XCTest / ViewInspector(findAll ベース)。`PBXFileSystemSynchronizedRootGroup` のため新規ファイルは配置のみで認識。

## Global Constraints

- branch: `feature/issue-148-task-card-icons`(作成済み・design doc commit 済み)
- テスト実行: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/<TestClass> 2>&1 | tail -20`(`** TEST SUCCEEDED / FAILED **` 文言で判定、exit code 不可、FOREGROUND 実行必須)
- デフォルト絵文字辞書(canonical ja 名 → 絵文字): 下の子の面倒を見る=👶 / お風呂を入れる=🛁 / 食器を出す=🍽️ / 食器を片付ける=🥣 / お片付けする=🧸 / 玄関の靴を並べる=👟 / ゴミ出しのお手伝い=🗑️ / 洗濯物を運ぶ=🧺 / テーブルを拭く=🧽 / 自分の部屋の掃除=🧹。汎用フォールバックは ✨
- 選択色は `AccessibilityColors.brandPrimary` の定数参照(hex 直書き禁止)
- `defaultTasks()` は icon を保存しない(nil のまま、表示時フォールバックが解決)
- 既存 DB の一括書き換え migration はしない
- commit footer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy`

---

### Task 1: HelpTask に icon / displayIcon / 辞書 / resolvePersistedIcon を追加

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Entities/HelpTask.swift`
- Test: `app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift`(既存 class 末尾に追記)

**Interfaces:**
- Produces: `HelpTask.icon: String?`(init は `icon: String? = nil` 末尾追加で後方互換)/ `displayIcon: String` / `updatingIcon(_:) -> HelpTask` / `static defaultIconsByName: [String: String]` / `static resolvePersistedIcon(selected: String?, original: HelpTask) -> String?`(Task 2-5 が使用)

- [ ] **Step 1: 失敗するテストを書く**

`HelpTaskTests.swift` の class 末尾に追記:

```swift
    // MARK: - icon (#148)

    func testDisplayIconUsesExplicitIcon() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true, icon: "🚿")
        XCTAssertEqual(task.displayIcon, "🚿")
    }

    func testDisplayIconFallsBackToDefaultDictionary() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertEqual(task.displayIcon, "🛁")
    }

    func testDisplayIconFallsBackToSparklesForUnknownName() {
        let task = HelpTask(id: UUID(), name: "ユーザー作成タスク", isActive: true)
        XCTAssertEqual(task.displayIcon, "✨")
    }

    func testCopyMethodsPreserveIcon() {
        let task = HelpTask(id: UUID(), name: "テスト", isActive: true, icon: "🧹")
        XCTAssertEqual(task.deactivate().icon, "🧹")
        XCTAssertEqual(task.activate().icon, "🧹")
        XCTAssertEqual(task.updateCoinRate(20).icon, "🧹")
        XCTAssertEqual(task.updatingSortOrder(5).icon, "🧹")
    }

    func testUpdatingIconReplacesIcon() {
        let task = HelpTask(id: UUID(), name: "テスト", isActive: true, icon: "🧹")
        XCTAssertEqual(task.updatingIcon("🧺").icon, "🧺")
        XCTAssertNil(task.updatingIcon(nil).icon)
    }

    func testEveryDefaultNameHasIconEntry() {
        // defaultTaskNames と defaultIconsByName のキー集合が完全一致すること
        XCTAssertEqual(
            Set(HelpTask.defaultTaskNames),
            Set(HelpTask.defaultIconsByName.keys),
            "keys: \(HelpTask.defaultIconsByName.keys.sorted())"
        )
    }

    func testResolvePersistedIconKeepsNilWhenUnchangedDefault() {
        // icon 未設定のデフォルトタスクで、表示中の絵文字をそのまま選んで保存 → nil 維持
        // (将来デフォルト絵文字を変えても DB 書き換えなしで追従させるため)
        let original = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertNil(HelpTask.resolvePersistedIcon(selected: "🛁", original: original))
    }

    func testResolvePersistedIconStoresExplicitSelection() {
        let original = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertEqual(HelpTask.resolvePersistedIcon(selected: "🧹", original: original), "🧹")
        // 明示 icon 済みタスクは同じ絵文字を選び直しても明示のまま維持
        let explicit = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true, icon: "🛁")
        XCTAssertEqual(HelpTask.resolvePersistedIcon(selected: "🛁", original: explicit), "🛁")
    }
```

- [ ] **Step 2: RED を確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/HelpTaskTests 2>&1 | tail -20`

Expected: BUILD FAILED(`icon` / `displayIcon` 等未定義のコンパイルエラー確定型)

- [ ] **Step 3: HelpTask を実装**

`HelpTask.swift` を以下のとおり変更:

struct 冒頭(プロパティ + init):

```swift
struct HelpTask: Equatable {
    let id: UUID
    let name: String
    let isActive: Bool
    let coinRate: Int
    let sortOrder: Int
    let icon: String?

    init(id: UUID, name: String, isActive: Bool, coinRate: Int = 10, sortOrder: Int = 0, icon: String? = nil) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.coinRate = coinRate
        self.sortOrder = sortOrder
        self.icon = icon
    }
```

copy 系 4 メソッドはすべて `icon: icon` を引き継ぐ形に置換し、`updatingIcon` を追加:

```swift
    func deactivate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: false, coinRate: coinRate, sortOrder: sortOrder, icon: icon)
    }

    func activate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: true, coinRate: coinRate, sortOrder: sortOrder, icon: icon)
    }

    func updateCoinRate(_ newRate: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: newRate, sortOrder: sortOrder, icon: icon)
    }

    func updatingSortOrder(_ newOrder: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: coinRate, sortOrder: newOrder, icon: icon)
    }

    func updatingIcon(_ newIcon: String?) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: coinRate, sortOrder: sortOrder, icon: newIcon)
    }
```

`defaultNameLocalizations` の直後に辞書と表示解決を追加:

```swift
    // defaultTaskNames と同期必須。漏れ → testEveryDefaultNameHasIconEntry が検出 (#148)
    static let defaultIconsByName: [String: String] = [
        "下の子の面倒を見る": "👶",
        "お風呂を入れる": "🛁",
        "食器を出す": "🍽️",
        "食器を片付ける": "🥣",
        "お片付けする": "🧸",
        "玄関の靴を並べる": "👟",
        "ゴミ出しのお手伝い": "🗑️",
        "洗濯物を運ぶ": "🧺",
        "テーブルを拭く": "🧽",
        "自分の部屋の掃除": "🧹"
    ]

    /// 表示用絵文字。明示 icon → デフォルト名辞書 → 汎用 ✨ の順で解決する。
    /// DB の一括書き換えをしない「表示時フォールバック」方式 (#148 spec 参照)。
    var displayIcon: String {
        if let icon, !icon.isEmpty { return icon }
        return HelpTask.defaultIconsByName[name] ?? "✨"
    }

    /// ピッカーの保存 icon を解決する。icon 未設定タスクで表示中のフォールバック絵文字を
    /// そのまま選んだ場合は nil を維持し、将来のデフォルト絵文字変更に追従させる
    /// (resolvePersistedName と同じ設計判断)。
    static func resolvePersistedIcon(selected: String?, original: HelpTask) -> String? {
        if original.icon == nil && selected == original.displayIcon { return nil }
        return selected
    }
```

- [ ] **Step 4: GREEN を確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`(既存 HelpTaskTests 含め全 PASS)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/HelpTask.swift app/OtetsudaiCoinTests/Domain/HelpTaskTests.swift
git commit -m "feat(#148): HelpTask に icon と表示時フォールバック displayIcon を追加

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 2: Core Data model v4 + repository mapping

**Files:**
- Create: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 4.xcdatamodel/contents`(v3 のコピー + icon 属性)
- Modify: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion`
- Modify: `app/OtetsudaiCoin/Data/Repositories/CoreDataHelpTaskRepository.swift:32-36,186-189,237-245`
- Test: `app/OtetsudaiCoinTests/Data/CoreDataHelpTaskRepositoryTests.swift`(追記)

**Interfaces:**
- Consumes: Task 1 の `HelpTask.icon`
- Produces: `CDHelpTask.icon`(optional String、codegen 自動生成)と save/update/toDomain の icon mapping

- [ ] **Step 1: model v4 を作成**

```bash
cp -R "app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 3.xcdatamodel" "app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 4.xcdatamodel"
```

`OtetsudaiCoin 4.xcdatamodel/contents` の `CDHelpTask` entity 内、`coinRate` 行の直後に追加(Xcode の属性アルファベット順に合わせる):

```xml
        <attribute name="icon" optional="YES" attributeType="String"/>
```

`.xccurrentversion` の `_XCCurrentVersionName` を更新:

```xml
	<key>_XCCurrentVersionName</key>
	<string>OtetsudaiCoin 4.xcdatamodel</string>
```

(optional 属性の追加は inferred mapping による lightweight migration で自動。`NSPersistentContainer` はデフォルトで `shouldMigrateStoreAutomatically` / `shouldInferMappingModelAutomatically` が有効)

- [ ] **Step 2: 失敗する roundtrip テストを書く**

`CoreDataHelpTaskRepositoryTests.swift` の class 末尾に追記(fixture 変数名はファイル既存の setUp に合わせる。以下は `repository` の想定 — 異なる場合はファイル内の既存テストと同じ名前を使う):

```swift
    // MARK: - icon roundtrip (#148)

    func testSaveAndFetchPersistsIcon() async throws {
        let task = HelpTask(id: UUID(), name: "アイコン付き", isActive: true, coinRate: 10, sortOrder: 0, icon: "🧹")
        try await repository.save(task)

        let fetched = try await repository.findById(task.id)
        XCTAssertEqual(fetched?.icon, "🧹")
    }

    func testSaveAndFetchKeepsNilIcon() async throws {
        let task = HelpTask(id: UUID(), name: "アイコンなし", isActive: true, coinRate: 10, sortOrder: 0)
        try await repository.save(task)

        let fetched = try await repository.findById(task.id)
        XCTAssertNil(fetched?.icon)
    }

    func testUpdatePersistsIconChange() async throws {
        let task = HelpTask(id: UUID(), name: "更新対象", isActive: true, coinRate: 10, sortOrder: 0)
        try await repository.save(task)

        try await repository.update(task.updatingIcon("🧺"))

        let fetched = try await repository.findById(task.id)
        XCTAssertEqual(fetched?.icon, "🧺")
    }
```

- [ ] **Step 3: RED を確認(behavioral red — 実行必須)**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/CoreDataHelpTaskRepositoryTests 2>&1 | tail -20`

Expected: `testSaveAndFetchPersistsIcon` と `testUpdatePersistsIconChange` が FAIL(model に属性はあるが mapping 未実装のため icon が nil で返る)。`testSaveAndFetchKeepsNilIcon` と既存テストは PASS。**mapping 漏れを検出する behavioral red なのでスキップ不可**。

- [ ] **Step 4: repository mapping を実装**

`CoreDataHelpTaskRepository.swift`:

save() の属性設定ブロック(:32-36)に追加:

```swift
                    cdHelpTask.icon = helpTask.icon
```

update() の属性設定ブロック(:186-189)に追加:

```swift
                        cdHelpTask.icon = helpTask.icon
```

toDomain()(:237-245)を置換:

```swift
extension CDHelpTask {
    func toDomain() -> HelpTask? {
        guard let id = self.id,
              let name = self.name else {
            return nil
        }
        
        return HelpTask(id: id, name: name, isActive: self.isActive, coinRate: Int(self.coinRate), sortOrder: Int(self.sortOrder), icon: self.icon)
    }
}
```

- [ ] **Step 5: GREEN を確認**

Run: Step 3 と同じコマンド
Expected: `** TEST SUCCEEDED **`(3 新テスト + 既存全テスト PASS)

- [ ] **Step 6: Commit**

```bash
git add "app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld" app/OtetsudaiCoin/Data/Repositories/CoreDataHelpTaskRepository.swift app/OtetsudaiCoinTests/Data/CoreDataHelpTaskRepositoryTests.swift
git commit -m "feat(#148): Core Data model v4 で CDHelpTask.icon を追加 (lightweight migration)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 3: TaskIconCatalog(ピッカー用プリセット)

**Files:**
- Create: `app/OtetsudaiCoin/Domain/Entities/TaskIconCatalog.swift`
- Test: `app/OtetsudaiCoinTests/Domain/TaskIconCatalogTests.swift`(新規)

**Interfaces:**
- Consumes: Task 1 の `HelpTask.defaultIconsByName`
- Produces: `TaskIconCatalog.presets: [String]`(Task 5 のグリッドが使用)

- [ ] **Step 1: 失敗するテストを書く**

`TaskIconCatalogTests.swift` を新規作成:

```swift
import XCTest
@testable import OtetsudaiCoin

final class TaskIconCatalogTests: XCTestCase {

    func testPresetsAreUniqueNonEmptySingleGraphemes() {
        let presets = TaskIconCatalog.presets
        XCTAssertGreaterThanOrEqual(presets.count, 24, "count: \(presets.count)")
        XCTAssertEqual(Set(presets).count, presets.count, "重複あり: \(presets)")
        for emoji in presets {
            XCTAssertEqual(emoji.count, 1, "\(emoji) は 1 grapheme cluster であること")
        }
    }

    func testPresetsContainAllDefaultIcons() {
        // デフォルトタスクの絵文字は編集時にグリッドでハイライトできるよう必ず含める
        let presets = Set(TaskIconCatalog.presets)
        for (name, emoji) in HelpTask.defaultIconsByName {
            XCTAssertTrue(presets.contains(emoji), "\(name) の \(emoji) が presets にない")
        }
    }
}
```

- [ ] **Step 2: RED を確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TaskIconCatalogTests 2>&1 | tail -20`
Expected: BUILD FAILED(`TaskIconCatalog` 未定義)

- [ ] **Step 3: TaskIconCatalog を実装**

`TaskIconCatalog.swift` を新規作成:

```swift
import Foundation

/// タスク絵文字ピッカーのプリセット (#148)。
/// 家事・生活系を中心にした厳選セット。デフォルトタスクの絵文字
/// (HelpTask.defaultIconsByName の値) を必ず含める — TaskIconCatalogTests が担保。
enum TaskIconCatalog {
    static let presets: [String] = [
        // デフォルトタスクの 10 個
        "👶", "🛁", "🍽️", "🥣", "🧸", "👟", "🗑️", "🧺", "🧽", "🧹",
        // 料理・買い物
        "🍳", "🥗", "🛒", "🍱",
        // 生き物・植物の世話
        "🐶", "🐱", "🐟", "🌱", "🪴",
        // 学び・持ち物
        "📚", "🎒", "✏️",
        // 生活・身のまわり
        "🪥", "🧦", "🛏️", "🧻", "💧", "✨"
    ]
}
```

- [ ] **Step 4: GREEN を確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`(2 テスト PASS。もし grapheme テストが FAIL したら該当絵文字を単一 cluster のものへ差し替える)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/TaskIconCatalog.swift app/OtetsudaiCoinTests/Domain/TaskIconCatalogTests.swift
git commit -m "feat(#148): タスク絵文字ピッカーのプリセット TaskIconCatalog を追加

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 4: TaskCardView 再設計(絵文字 + 選択表現の簡素化 + brandPrimary)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift`(全面書き換え)
- Test: `app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift`(新規)

**Interfaces:**
- Consumes: Task 1 の `task.displayIcon`、`AccessibilityColors.brandPrimary`
- Produces: TaskCardView の public initializer は不変(呼び出し側の変更不要)

- [ ] **Step 1: 失敗するテストを書く**

`TaskCardViewTests.swift` を新規作成(findAll ベース — iOS 26 の identifier 回帰対応。未実証 traversal に依存するため観測値を assertion message に dump する #106 ルール適用):

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: 0, icon: icon)
    }

    private func renderedTexts(_ view: TaskCardView) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    func testRendersExplicitIconEmoji() throws {
        let view = TaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🛁"), "rendered: \(texts)")
    }

    func testTapToSelectLabelIsRemoved() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertFalse(texts.contains { $0.contains("タップして選択") }, "rendered: \(texts)")
    }

    func testSingleModeSelectedShowsNoTextIndicator() throws {
        // 単独モードの選択表現は枠 + チェックマーク overlay のみ (「選択中」テキスト行は削除)
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertFalse(texts.contains { $0.contains("選択中") }, "rendered: \(texts)")
    }

    func testBulkModeKeepsSelectionIndicator() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, isBulkMode: true, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains { $0.contains("選択中") }, "rendered: \(texts)")
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let shapes = try view.inspect().findAll(ViewType.Shape.self)
        let fills = shapes.compactMap { try? $0.fillShapeStyle(Color.self) }
        // アイコン円 (brandPrimary 0.15) かカード背景 (brandPrimary 0.1) のどちらかが取得できること
        let expected: [Color] = [
            AccessibilityColors.brandPrimary.opacity(0.15),
            AccessibilityColors.brandPrimary.opacity(0.1)
        ]
        XCTAssertTrue(fills.contains { expected.contains($0) }, "observed fills: \(fills)")
    }
}
```

- [ ] **Step 2: RED を確認(behavioral red — 実行必須)**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TaskCardViewTests 2>&1 | tail -20`

Expected: コンパイルは通る(TaskCardView の init 不変)が、絵文字 Text 不在・「タップして選択」存在・「選択中」存在・blue fill で **4〜6 テストが assertion FAIL**。findAll が現行 View 構造で何を返すかの観測値が failure message に出ることを確認する。

- [ ] **Step 3: TaskCardView を書き換え**

`TaskCardView.swift` 全体を以下で置換:

```swift
import SwiftUI

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    var existingCount: Int = 0
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                existingCountRow
                if isBulkMode {
                    bulkSelectionIndicator
                }
            }
            .padding()
            .frame(height: 150)
            .background(cardBackground)
            .overlay(alignment: .topTrailing) {
                selectionCheckmark
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var existingCountRow: some View {
        if existingCount >= 1 {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                Text(existingCountText)
                    .appFont(.captionText)
                    .foregroundColor(.gray.opacity(0.7))
                    .accessibilityIdentifier("existing_count_label")
            }
        } else {
            EmptyView()
        }
    }

    private var existingCountText: String {
        // 文字列補間で xcstrings の plural variations を利用する。
        // String(format:) は variations を bypass する既知罠 (CLAUDE.md i18n 節)。
        let count = existingCount
        return String(localized: "すでに \(count) 件記録済み")
    }

    private var taskIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.15) : Color.gray.opacity(0.1))
                .frame(width: 50, height: 50)

            // 絵文字は装飾。カードの意味は taskTitle が担うため VoiceOver から隠す (#84 パターン)
            Text(task.displayIcon)
                .font(.title2)
                .accessibilityHidden(true)
        }
    }

    private var taskTitle: some View {
        Text(task.displayName)
            .appFont(.cardTitle)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(AccessibilityColors.textPrimary)
            .lineLimit(2)
    }

    private var coinInfo: some View {
        Text("\(task.coinRate)コイン")
            .appFont(.captionText)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? AccessibilityColors.brandPrimary : .secondary)
    }

    /// 単独モードの選択表現: 右上チェックマーク (枠線 cardBackground と対で「枠 + チェック」)
    @ViewBuilder
    private var selectionCheckmark: some View {
        if isSelected && !isBulkMode {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(AccessibilityColors.brandPrimary)
                .padding(8)
                .accessibilityHidden(true)
        }
    }

    private var bulkSelectionIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundColor(isSelected ? AccessibilityColors.brandPrimary : .gray.opacity(0.5))
            Text(isSelected ? "選択中" : "選択")
                .appFont(.captionText)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? AccessibilityColors.brandPrimary : .gray.opacity(0.7))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.large)
            .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(isSelected ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
            )
    }
}
```

- [ ] **Step 4: GREEN を確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`(6 テスト PASS)。`testSelectedCardUsesBrandPrimaryShapes` が findAll の Shape 到達不能で FAIL する場合は、観測値 dump を確認し、fills が空なら該当テストの assert を「絵文字 Text + 選択中不在」ベースへ縮退させる判断を report に明記(#84 の findAll(Shape) 実績があるため原則到達可能の想定)。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/TaskCardView.swift app/OtetsudaiCoinTests/Presentation/Components/TaskCardViewTests.swift
git commit -m "feat(#148): タスクカードを絵文字アイコン化し選択表現を枠+チェックに簡素化

「タップして選択」「✓選択中」のテキスト行を削除し、選択色を brandPrimary へ統一。

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 5: ピッカー UI + ViewModel icon 対応 + xcstrings

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift:51,72-79`(addTask に icon 引数)
- Modify: `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:168-258 付近`(TaskFormView に絵文字グリッド)
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`(「アイコン」キー追加)
- Test: `app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift`(追記)

**Interfaces:**
- Consumes: `TaskIconCatalog.presets`(Task 3)、`HelpTask.resolvePersistedIcon`(Task 1)
- Produces: `addTask(name: String, coinRate: Int = 10, icon: String? = nil) async`(既存呼び出しはデフォルト引数で互換)

- [ ] **Step 1: 失敗するテストを書く**

`TaskManagementViewModelTests.swift` の class 末尾に追記:

```swift
    // MARK: - icon (#148)

    func testAddTaskPersistsSelectedIcon() async {
        await viewModel.loadTasks()

        await viewModel.addTask(name: "植物の水やり", coinRate: 10, icon: "🌱")

        let saved = mockTaskRepository.tasks.first { $0.name == "植物の水やり" }
        XCTAssertEqual(saved?.icon, "🌱")
    }

    func testAddTaskWithoutIconKeepsNil() async {
        await viewModel.loadTasks()

        await viewModel.addTask(name: "アイコン未選択", coinRate: 10)

        let saved = mockTaskRepository.tasks.first { $0.name == "アイコン未選択" }
        XCTAssertNotNil(saved)
        XCTAssertNil(saved?.icon)
    }
```

- [ ] **Step 2: RED を確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests 2>&1 | tail -20`
Expected: BUILD FAILED(`addTask(name:coinRate:icon:)` 未定義のコンパイルエラー確定型)

- [ ] **Step 3: ViewModel と View を実装**

`TaskManagementViewModel.swift` — addTask のシグネチャと newTask 構築を変更:

```swift
    func addTask(name: String, coinRate: Int = 10, icon: String? = nil) async {
```

newTask 構築(:72-79)を置換:

```swift
        let newTask = HelpTask(
            id: UUID(),
            name: trimmedName,
            isActive: true,
            coinRate: coinRate,
            sortOrder: nextSortOrder,
            icon: icon
        )
```

`TaskManagementView.swift` の TaskFormView(:168 付近の struct):

`@State private var coinRate: Int = 10` の直後に追加:

```swift
    @State private var selectedIcon: String?
```

Form の `Section("タスク情報")` の直後に Section を追加:

```swift
                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(TaskIconCatalog.presets, id: \.self) { emoji in
                            Button {
                                selectedIcon = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .stroke(selectedIcon == emoji ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(Text(emoji))
                            .accessibilityAddTraits(selectedIcon == emoji ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
```

`.onAppear` ブロックに追加(編集時は現在の表示絵文字をハイライト):

```swift
                if let task = editingTask {
                    taskName = task.displayName
                    isActive = task.isActive
                    coinRate = task.coinRate
                    selectedIcon = task.displayIcon
                }
```

`addTask()` private func の呼び出しを変更:

```swift
            await viewModel.addTask(name: taskName, coinRate: coinRate, icon: selectedIcon)
```

`updateTask()` private func の updatedTask 構築を置換(表示絵文字を無変更で保存した場合は nil を維持 — resolvePersistedName と同型):

```swift
        let updatedTask = HelpTask(
            id: editingTask.id,
            name: HelpTask.resolvePersistedName(editedText: taskName, original: editingTask),
            isActive: isActive,
            coinRate: coinRate,
            sortOrder: editingTask.sortOrder,
            icon: HelpTask.resolvePersistedIcon(selected: selectedIcon, original: editingTask)
        )
```

`Localizable.xcstrings` に「アイコン」キーを追加(**手動 Edit で既存の `" : "` フォーマットを保つ** — Python json.dump 禁止、[[xcstrings-bulk-update]] 罠)。既存キーのアルファベット/文字コード順の適切な位置に:

```json
    "アイコン" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Icon"
          }
        }
      }
    },
```

- [ ] **Step 4: GREEN を確認**

Run: Step 2 と同じコマンド + `-only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests` を追加した 1 回で実行:

`xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/TaskManagementViewModelTests -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests 2>&1 | tail -20`

Expected: `** TEST SUCCEEDED **`(icon 2 テスト + 既存 + xcstrings 検証 green)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/TaskManagementViewModel.swift app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Presentation/ViewModels/TaskManagementViewModelTests.swift
git commit -m "feat(#148): タスク追加/編集フォームに絵文字ピッカーを追加

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 6: 全体テスト + 視覚検証

**Files:** 参照のみ。スクショ出力は目視後 discard

- [ ] **Step 1: unit テスト全体を実行**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`。FAIL 時は `Failing tests:` を確認、詳細は `.xcresult` を `xcrun xcresulttool` で開く(CLAUDE.md ルール)

- [ ] **Step 2: after スクショを撮影して一次目視**

```bash
./scripts/capture-asc-screenshots.sh
```

`docs/screenshots/asc/v1.1.x/ja/02-record.png` を Read で開き確認:

- タスクカードに絵文字(👶🛁🍽️ 等)が表示されている
- 「タップして選択」行が消えている
- 選択中カードが「brandPrimary 枠 + 右上チェック」表現になっている(スクショの初期状態は未選択の可能性あり — その場合はカード全体の変化のみ確認し、選択表現は Step 1 の TaskCardViewTests green を根拠とする)
- レイアウト崩れ(絵文字の欠け・カード高さの不整合)がない

- [ ] **Step 3: スクショを退避して discard**

```bash
SCRATCH=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/93a050ca-80ad-423e-b3bd-5adf77c259a8/scratchpad
mkdir -p "$SCRATCH/148-after"
cp docs/screenshots/asc/v1.1.x/ja/02-record.png "$SCRATCH/148-after/"
git checkout -- docs/screenshots/
git status --short
```

Expected: docs/screenshots 差分ゼロ

- [ ] **Step 4: 所見をまとめる**

視覚検証所見(変更点内訳 / out-of-scope finding の有無)を PR description 用にまとめる。データ migration の注意(既存ユーザーは表示時フォールバックで絵文字が出る、DB 書き換えなし)も PR に記載。

---

## Plan 自己レビュー済み事項

- spec カバレッジ: Domain(Task 1)/ Core Data(Task 2)/ カタログ(Task 3)/ カード再設計 + 選択色(Task 4)/ ピッカー + VM + i18n(Task 5)/ 検証(Task 6)— spec 全セクション対応。スコープ外 3 項目は plan に含めていないことを確認
- 型整合: `icon: String?` / `displayIcon: String` / `updatingIcon(_:)` / `resolvePersistedIcon(selected:original:)` / `TaskIconCatalog.presets: [String]` / `addTask(name:coinRate:icon:)` を定義側(Task 1/3/5)と使用側(Task 2/4/5)で一致確認済み
- 既知の注意: Task 2 のテスト fixture 変数名はファイル既存 setUp に合わせる(plan は `repository` 想定)。Task 4 Step 4 に findAll(Shape) 到達不能時の縮退判断を明記済み
