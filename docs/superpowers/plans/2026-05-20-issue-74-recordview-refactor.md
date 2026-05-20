# Issue #74 RecordView Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RecordView を ViewInspector で部分的に traverse 可能な構造に整理し、`record_button` への structural / accessibility identifier test を書けるようにする。BannerAdView は **#49 の元 UX (スクロール末尾表示) を維持** し、ScrollView 内の他要素 (bulk_mode_toggle / record_date_picker) への traversal は諦める。

**Architecture:** `body` の top-level `ZStack` を `.overlay { }` modifier に置換、`.ultraThinMaterial` を `Color(.systemBackground).opacity(0.95)` に置換。`BannerAdView` は ScrollView 内末尾のまま維持。2 つの blocker (ZStack / Material) を取り除き、ScrollView の sibling である `record_button` への traversal を可能にする。記録ボタン背景の blur は失われる (許容済み)。

**Tech Stack:** SwiftUI / ViewInspector / XCTest / Xcode 16+ (`PBXFileSystemSynchronizedRootGroup`)

**Scope NOT in this plan:**

- 一括モードの UX 変更 (#73 で別途)
- BannerAdView の位置変更 (#49 の元 UX を維持)
- ScrollView 内要素 (`bulk_mode_toggle` / `record_date_picker`) への structural test (BannerAdView UIViewRepresentable が blocker のまま)
- NavigationStack 自体の入れ子整理 (NavigationStack 単体は ViewInspector の blocker ではないため保持)
- 他 View (HomeView 等) への同様 refactor の適用 (本 issue は RecordView 限定)

---

## File Structure

| File | Responsibility |
| --- | --- |
| `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | View body の構造変更 (ZStack → overlay / Material → Color)。BannerAdView は移動しない |
| `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` | 新規 structural test 追加 (`record_button` traversal / navigation title / bulk label) |

新規ファイルなし。`PBXFileSystemSynchronizedRootGroup` のため `project.pbxproj` の編集は不要。

---

## Task 1: Red: structural test を追加して既存構造で fail を確認する

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift`

- [ ] **Step 1: Failing test を追加する**

`RecordViewTests` クラス末尾 (`test_toggleBulkMode_setsStateForView` の下) に以下を追加:

```swift
/// #74 refactor 完了後に PASS することを期待する structural test (red 段階).
/// 現状の top-level ZStack + .ultraThinMaterial で record_button へ ViewInspector
/// が到達できないことを Task 1 の段階で確認する.
/// BannerAdView (ScrollView 内) は #49 仕様維持のため移動せず、その結果
/// ScrollView 内の bulk_mode_toggle / record_date_picker には traversal せず
/// ScrollView の sibling である record_button のみを対象にする.
func test_recordView_canTraverseToRecordButton() throws {
    let view = RecordView(viewModel: viewModel)
    XCTAssertNoThrow(try view.inspect().find(viewWithAccessibilityIdentifier: "record_button"))
}
```

- [ ] **Step 2: テストが fail することを確認する**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_canTraverseToRecordButton
```

Expected: FAIL。エラーメッセージに `"Search did not find a match. Possible blockers: ..., Material, ..."` 系が含まれることを確認 (ZStack または Material が blocker)。

- [ ] **Step 3: red 段階を commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift
git commit -m "test(#74): RecordView の record_button traversal test を追加 (red)

ViewInspector で record_button へ到達できないことを assert。現状の top-level
ZStack + .ultraThinMaterial が blocker のため FAIL。Task 2-3 の refactor で
PASS させる。"
```

---

## Task 2: ZStack を `.overlay { }` modifier に置換する

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift:7-110` (body 全体)

- [ ] **Step 1: body の top-level ZStack を外し、コインアニメーションを `.overlay` 化**

(BannerAdView と `.ultraThinMaterial` は **このタスクではまだ変更しない**) `RecordView.body` を以下に置き換える:

```swift
var body: some View {
    NavigationStack {
        VStack(spacing: 0) {
            // メインコンテンツ
            ScrollView {
                VStack(spacing: 16) {
                    bulkModeToggleRow
                    StateBasedContent(
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        onRetry: { viewModel.loadTasks() }
                    ) {
                        VStack(spacing: 16) {
                            if let successMessage = viewModel.successMessage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AccessibilityColors.successGreen)
                                    Text(successMessage)
                                        .appFont(.buttonText)
                                        .foregroundColor(AccessibilityColors.successGreen)
                                }
                                .padding()
                                .background(AccessibilityColors.successGreenLight)
                                .cornerRadius(8)
                            }

                            if let warningMessage = viewModel.warningMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(warningMessage)
                                        .appFont(.buttonText)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(8)
                            }

                            childSelectionView

                            dateSection

                            taskListView
                        }
                        .padding()
                        .padding(.bottom, 80) // 固定ボタン分のスペース確保
                    }

                    // Issue #49: スクロール末端に AdMob バナーを配置。
                    // StateBasedContent の外側に置くことで loading/error 中も表示。
                    BannerAdView()
                        .frame(height: 50)
                        .padding(.bottom, 8)
                }
            }

            // 画面下部固定の記録ボタン
            VStack(spacing: 0) {
                Divider()

                recordButtonView
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("お手伝い記録")
        .onAppear {
            // エラーメッセージのみクリアし、成功メッセージは保持
            viewModel.clearErrorMessage()
            viewModel.loadData()
        }
    }
    .overlay {
        if showCoinAnimation {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showCoinAnimation = false
                }
        }
    }
    .overlay {
        if showCoinAnimation, let selectedChild = viewModel.selectedChild {
            CoinAnimationView(
                isVisible: $showCoinAnimation,
                coinValue: viewModel.lastRecordedCoinValue,
                themeColor: selectedChild.themeColor
            )
        }
    }
    .onChange(of: viewModel.successMessage) { _, successMessage in
        if successMessage != nil && !showCoinAnimation {
            showCoinAnimation = true
        }
    }
    .onChange(of: showCoinAnimation) { _, isShowing in
        if !isShowing {
            // アニメーション終了時に成功メッセージをクリア
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.clearMessages()
            }
        }
    }
}
```

ポイント:

- top-level の `ZStack` を撤去し、`NavigationStack` を body の root にした
- コインアニメーションは 2 段の `.overlay { }` に分けた (背景 dim と CoinAnimationView)
- `.ultraThinMaterial` と `BannerAdView` の位置は **Task 3 / Task 4 でさらに変更** する (今は配置だけ動かさない)

- [ ] **Step 2: 既存テストが pass し続けることを確認する**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_initializes_withoutCrash \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_toggleBulkMode_setsStateForView
```

Expected: PASS。

- [ ] **Step 3: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "refactor(#74): RecordView の top-level ZStack を .overlay modifier に置換

コインアニメーションの背景 dim と CoinAnimationView を 2 段の overlay に
分割し、body root を NavigationStack に変更。視覚的な挙動は変えない。
ViewInspector の ZStack blocker を取り除く第 1 段階。"
```

---

## Task 3: `.ultraThinMaterial` を Color 系背景に置換する

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` (記録ボタン背景 1 箇所)

- [ ] **Step 1: Material を Color に置換**

`recordButtonView` をラップしている部分 (Task 2 後の body 内):

```swift
// 画面下部固定の記録ボタン
VStack(spacing: 0) {
    Divider()

    recordButtonView
        .padding()
        .background(.ultraThinMaterial)
}
```

を以下に変更:

```swift
// 画面下部固定の記録ボタン
VStack(spacing: 0) {
    Divider()

    recordButtonView
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
}
```

`Color(.systemBackground)` は dark mode で自動切替されるシステム色。`opacity(0.95)` で Material 風の半透明感を残す。

- [ ] **Step 2: ビルド & 既存テスト確認**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests
```

Expected: 既存 2 件 PASS, Task 1 で追加した 3 件は引き続き FAIL (BannerAdView blocker のため)。

- [ ] **Step 3: commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift
git commit -m "refactor(#74): 記録ボタン背景の .ultraThinMaterial を Color(.systemBackground) 化

ViewInspector が Material を traverse できない既知制約を回避するため、
dark mode 対応の Color(.systemBackground).opacity(0.95) に置換。視覚的な
挙動は半透明感を含めほぼ同等。"
```

---

## Task 4: Green: structural test の網羅性を上げる (任意の追加 assert)

**Files:**

- Modify: `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift`

- [ ] **Step 1: NavigationTitle と taskListView の structural test を追加**

`RecordViewTests` 末尾に追加:

```swift
/// NavigationStack の title が "お手伝い記録" であることを ViewInspector で確認.
func test_recordView_hasExpectedNavigationTitle() throws {
    let view = RecordView(viewModel: viewModel)
    let title = try view.inspect().find(ViewType.NavigationStack.self).navigationTitle()
    XCTAssertEqual(try title.string(), "お手伝い記録")
}

/// 一括モード時に record_button のラベルが "{n} 件をまとめて記録する" になることを
/// ViewModel と View の wire-up 経由で確認.
func test_recordButtonLabel_inBulkMode_reflectsSelectedTaskCount() throws {
    let task = HelpTask(id: UUID(), name: "Test", isActive: true, coinRate: 10)
    viewModel.availableTasks = [task]
    viewModel.toggleBulkMode()
    viewModel.selectedTaskIds = [task.id]

    let view = RecordView(viewModel: viewModel)
    // ViewInspector で Button label の Text を取得し、"1" が含まれることを確認
    let button = try view.inspect().find(viewWithAccessibilityIdentifier: "record_button")
    let labelText = try button.find(ViewType.Text.self, traversal: .breadthFirst).string()
    XCTAssertTrue(labelText.contains("1"), "Expected button label to contain '1', got: \(labelText)")
}
```

Note: 2 件目の test は xcstrings plural variations の wire-up (CLAUDE.md「i18n: xcstrings plural variations」節) を間接的に担保する。

- [ ] **Step 2: テスト実行**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordView_hasExpectedNavigationTitle \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/test_recordButtonLabel_inBulkMode_reflectsSelectedTaskCount
```

Expected: PASS。

もし `navigationTitle()` の取得方法が ViewInspector API バージョン差で動かない場合は、`view.inspect().navigationStackContent()` 経由で試す。それでも動かないなら 1 件目は削除して 2 件目だけ残す (重要度の差: 2 件目 > 1 件目)。

- [ ] **Step 3: commit**

```bash
git add app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift
git commit -m "test(#74): RecordView の structural / behavior test を追加

NavigationStack title の確認と、一括モード時の record_button label
plural variations の wire-up を ViewInspector 経由で間接担保。"
```

---

## Task 5: Simulator で UI 視覚 regression がないことを確認する

**REQUIRED SUB-SKILL:** `ios-simulator-app-verification` (UI 視覚確認)

**Files:**

- Verify only (no code changes)

- [ ] **Step 1: Simulator boot & launch**

Run:

```bash
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcodebuild build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/otetsudai-build
APP_PATH=$(find /tmp/otetsudai-build/Build/Products -name 'OtetsudaiCoin.app' | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.asapapalab.OtetsudaiCoin
sleep 3
xcrun simctl io booted screenshot /tmp/record-view-after-refactor.png
```

- [ ] **Step 2: スクリーンショットを目視確認**

確認項目:

- [ ] NavigationStack title "お手伝い記録" が画面上部に表示されている
- [ ] 一括モード toggle が表示されている
- [ ] お子様選択 / 記録日 / お手伝いタスクが表示されている
- [ ] 画面下部に固定された記録ボタンが表示されている
- [ ] ScrollView の中身を一番下まで scroll した時に AdMob バナーが見える (#49 仕様)
- [ ] 記録ボタンの背景が `Color(.systemBackground)` で、blur が無くなっていることを確認 (許容済みの変更)
- [ ] dark mode に切替えても背景色が破綻しない (`Color(.systemBackground)`)

- [ ] **Step 3: dark mode 切替確認**

Run:

```bash
xcrun simctl ui booted appearance dark
sleep 1
xcrun simctl io booted screenshot /tmp/record-view-dark.png
xcrun simctl ui booted appearance light
```

両 mode のスクリーンショットを `git status` で残さず、PR コメントへ添付する形にする (リポジトリには push しない)。

- [ ] **Step 4: 視覚 regression が無ければ "verified" commit (空 commit 不要)**

実際にはコード変更がないため commit はスキップ。verification log は PR 本文の Test plan に書く。

---

## Task 6: 全テスト実行 & PR 作成

**Files:**

- No code changes (PR 作成のみ)

- [ ] **Step 1: 全テスト suite を実行**

Run:

```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: 全テスト PASS。

もし flake で UI/load 系テストが落ちた場合は、CLAUDE.md「iOS テスト flake 切り分け」節に従い、当該テストを `xcodebuild test -only-testing:` で isolated 再実行し、PASS すれば parallel flake として扱う。

- [ ] **Step 2: push & PR 作成**

Run:

```bash
git push -u origin feat/issue-74-recordview-refactor
gh pr list --head feat/issue-74-recordview-refactor  # 二重 PR チェック (CLAUDE.md ルール)
gh pr create --title "refactor(#74): RecordView を ViewInspector で traverse 可能な構造に整理" --body "$(cat <<'EOF'
## Summary

- top-level ZStack を `.overlay { }` modifier に置換 (ViewInspector blocker 解消)
- 記録ボタン背景の `.ultraThinMaterial` を `Color(.systemBackground).opacity(0.95)` に置換 (blur が無くなる仕様変更を許容)
- `BannerAdView` は #49 の元 UX (ScrollView 末尾) を維持
- `record_button` への ViewInspector traversal を可能にする structural test を追加 (Task 1 の red → Task 3 で green)
- NavigationStack title と 一括モード label の structural / behavior test を 2 件追加

## 背景

`#69` (PR #72) で RecordView の structural test を書こうとしたが、ViewInspector が ZStack + NavigationStack + ScrollView + .ultraThinMaterial + BannerAdView (UIViewRepresentable) の組み合わせを深く traverse できず断念。UI 構造は simulator 手動検証に依存していた。本 PR で **ScrollView の sibling である `record_button` への traversal blocker (ZStack / Material)** を取り除き、ViewModel テストと structural test の二段で品質を担保する。BannerAdView は #49 の UX 維持のため移動せず、ScrollView 内要素 (`bulk_mode_toggle` / `record_date_picker`) への traversal は引き続き諦める。

Refs #69, Closes #74

## 視覚変更について

- 記録ボタン背景: frosted glass (`.ultraThinMaterial`) → 薄い単色 (`Color(.systemBackground).opacity(0.95)`)。light / dark mode どちらでも視覚的に違いが出るが、テスト容易性のトレードオフとして許容。

## Test plan

- [x] `RecordViewTests` 5 件 (smoke / behavior / structural 3 件) すべて PASS
- [x] `BannerAdViewTests` 9 件 (既存、特に `testRecordViewShowsBannerAdBelowScrollContent`) すべて PASS
- [x] `xcodebuild test` 全 suite PASS
- [x] Simulator 視覚確認 (light / dark mode) で 想定の視覚変更のみ・予期せぬ regression なし
- [x] AdMob バナー (Test Ad) が ScrollView 末尾までスクロールすると表示されることを確認

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (実行前チェック)

**Spec coverage (#74 本文の提案 a-d):**

- [ ] (a) BannerAdView を別 component に切り出し → **スコープ外** (#49 の UX 維持のため位置変更せず、structural test も諦める)
- [x] (b) Material 依存を削減 → Task 3 で `Color(.systemBackground)` 化
- [x] (c) ZStack の overlay を `.overlay { }` modifier に変更 → Task 2
- [x] (d) NavigationStack の入れ子整理 → NavigationStack 単体は blocker でないため保持。body root を NavigationStack にすることで「ZStack で wrap」の入れ子を 1 段解消 (Task 2)

**Placeholder scan:** 「TBD」「TODO」「implement later」「add appropriate ... 」等の placeholder は無し ✅

**Type consistency:**

- `recordButtonView` / `recordButtonLabel` / `bulkSummaryView` / `record_button` の名前は既存実装と一致 ✅
- `Color(.systemBackground)` は SwiftUI 標準 API ✅
