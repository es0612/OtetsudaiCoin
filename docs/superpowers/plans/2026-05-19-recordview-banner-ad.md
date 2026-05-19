# RecordView バナー広告配置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RecordView の ScrollView 末端に AdMob バナーを追加し、初回セットアップ後ほぼ訪問されない TaskManagementView だけだった impressions を、毎日触られる主画面で稼げるようにする。

**Architecture:** 既存 `BannerAdView` を再利用。RecordView の `ScrollView` 内 `VStack(spacing: 16)` の末尾、`StateBasedContent` の直後に `BannerAdView().frame(height: 50)` を追加するのみ。AdMob 初期化や AdConstants は既存のまま。新規 `RecordViewTests.swift` で ViewInspector による存在テストを TDD で先行作成。

**Tech Stack:** SwiftUI / GoogleMobileAds SDK / ViewInspector / xcodebuild

**Spec:** `docs/superpowers/specs/2026-05-19-recordview-banner-ad-design.md`

---

## File Structure

| 種別 | パス | 責務 |
| --- | --- | --- |
| Modify | `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` | line 7-43 の ScrollView 内 VStack に BannerAdView を 1 行追加 |
| Create | `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` | ViewInspector で BannerAdView 存在テスト (新規ファイル) |

**変更しないファイル**:

- `app/OtetsudaiCoin/Presentation/Components/BannerAdView.swift` (既存のまま再利用)
- `app/OtetsudaiCoin/AppDelegate.swift` (AdMob 初期化済み)
- `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift` (既存 banner は保持)
- `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift` (mock 構築の参考のみ、変更なし)

## Pre-flight Verification

- [ ] **Branch 確認**

Run:
```bash
git status
```
Expected: `On branch feat/issue-49-recordview-banner` であり、変更ファイルが spec のみ（既に commit 済み）であること。違う branch にいたら `git checkout feat/issue-49-recordview-banner`。

- [ ] **origin 同期確認** (CLAUDE.md ルール)

Run:
```bash
git fetch origin && git log --oneline -1 origin/main
```
Expected: origin/main の最新が `4f43cab` (Merge pull request #68) 以降であること。ローカル branch は main から派生。

- [ ] **既存 PR の重複確認** (CLAUDE.md ルール)

Run:
```bash
gh pr list --head feat/issue-49-recordview-banner --json number,state,title
```
Expected: `[]` (空配列)。並列セッションが先に PR を作っていないこと。

---

## Task 1: RecordViewTests スケルトン + 失敗テスト追加 (TDD red)

**Files:**

- Create: `app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift`
- 参考 (読むだけ): `app/OtetsudaiCoinTests/Presentation/Views/HomeViewTests.swift` (ViewInspector パターン)
- 参考 (読むだけ): `app/OtetsudaiCoinTests/Presentation/RecordViewModelTests.swift:1-40` (mock 構築パターン)

- [ ] **Step 1: 参考ファイルを 1 度確認する**

`HomeViewTests.swift` 冒頭の `@testable import` 列、`setUp` / `tearDown` パターンと `RecordViewModelTests.swift:7-32` の RecordViewModel の dependencies (childRepository / helpTaskRepository / helpRecordRepository / soundService の 4 つ) を確認。

- [ ] **Step 2: RecordViewTests.swift を新規作成**

`app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift` に下記を書く:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

final class RecordViewTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockSoundService = MockSoundService()

        viewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockSoundService = nil
        mockHelpRecordRepository = nil
        mockHelpTaskRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }

    // MARK: - 広告表示テスト (#49)

    @MainActor
    func testRecordViewIncludesBannerAdAtBottom() throws {
        // RecordView のビュー階層に BannerAdView が存在することを確認する。
        // Ad の実際のロード成否は AdMob SDK 側で外部依存のため検証しない。
        let view = RecordView(viewModel: viewModel)
        XCTAssertNoThrow(try view.inspect().find(BannerAdView.self))
    }
}
```

- [ ] **Step 3: テストファイルを Xcode project に追加**

`.xcstrings` の bulk 編集と違い `.swift` ファイル新規追加は `project.pbxproj` の更新が必要。
Xcode で `app/OtetsudaiCoinTests/Presentation/Views/` に "New File" → Swift File → `RecordViewTests.swift` で追加するか、`xcodeproj` gem ベースのスクリプトで pbxproj を編集する。最も確実なのは Xcode GUI 経由。

代替: 既存の `HomeViewTests.swift` の隣に手で配置した後、Xcode で開いてターゲットメンバーシップ `OtetsudaiCoinTests` を付ける（Inspector の Target Membership チェック）。

- [ ] **Step 4: TDD red 確認 (テスト単独実行)**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin/app && \
xcodebuild test -project OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/testRecordViewIncludesBannerAdAtBottom 2>&1 | tail -20
```
Expected:
```
** TEST FAILED **
Test case 'RecordViewTests.testRecordViewIncludesBannerAdAtBottom()' failed
```
理由: RecordView にまだ BannerAdView が追加されていないため、`find(BannerAdView.self)` が throw する → `XCTAssertNoThrow` が失敗。

**もし pbxproj 編集ミスで build error になったら**: Step 3 に戻り Target Membership 設定を確認。

- [ ] **Step 5: Commit (TDD red をマーク)**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin && \
git add app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift \
        app/OtetsudaiCoin.xcodeproj/project.pbxproj && \
git commit -m "$(cat <<'EOF'
test(#49): RecordView の BannerAdView 存在テストを追加 (red)

新規 RecordViewTests.swift を作成し、ViewInspector で BannerAdView の
ビュー階層存在を検証する単一テスト testRecordViewIncludesBannerAdAtBottom
を追加。現状の RecordView には BannerAdView が無いため、このテストは
意図的に red から始まる (TDD)。

Refs #49

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: RecordView に BannerAdView を追加 (TDD green)

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift:7-43`

- [ ] **Step 1: 修正前の構造を 1 度確認する**

Read: `app/OtetsudaiCoin/Presentation/Views/RecordView.swift` の line 7-43。`ScrollView { VStack(spacing: 16) { StateBasedContent(...) {...} } }` の構造を頭に入れる。

- [ ] **Step 2: ScrollView 内 VStack の StateBasedContent 直後に BannerAdView を追加**

Edit `app/OtetsudaiCoin/Presentation/Views/RecordView.swift`:

下記の old → new で置換する。

old_string:
```swift
                    // メインコンテンツ
                    ScrollView {
                        VStack(spacing: 16) {
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
                                    
                                    childSelectionView

                                    dateSection

                                    taskListView
                                }
                                .padding()
                                .padding(.bottom, 80) // 固定ボタン分のスペース確保
                            }
                        }
                    }
```

new_string:
```swift
                    // メインコンテンツ
                    ScrollView {
                        VStack(spacing: 16) {
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
```

- [ ] **Step 3: TDD green 確認 (単独テスト)**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin/app && \
xcodebuild test -project OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests/testRecordViewIncludesBannerAdAtBottom 2>&1 | tail -10
```
Expected:
```
** TEST SUCCEEDED **
Test case 'RecordViewTests.testRecordViewIncludesBannerAdAtBottom()' passed
```

- [ ] **Step 4: 関連テストスイートの regression 確認**

Run (RecordView 周辺):
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin/app && \
xcodebuild test -project OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/RecordViewTests \
  -only-testing:OtetsudaiCoinTests/RecordViewModelTests \
  -only-testing:OtetsudaiCoinTests/HomeViewTests 2>&1 | tail -10
```
Expected: `** TEST SUCCEEDED **` で全件 pass。`HomeViewTests` は無関係だが、ViewInspector 系で副作用が無いことを確認。

**もし HomeViewTests/testHomeViewDisplaysUnpaidWarningBannerWithoutSelectedChild が落ちたら**: それは別件 (#56 の修正が main に取り込まれているはず) なので、`git log --oneline main -- "*HomeViewTests*"` で `4dd7774 fix(#56)` が含まれているか確認。含まれていなければ branch が古い → `git fetch origin && git rebase origin/main`。

- [ ] **Step 5: 並列 flake チェック** (CLAUDE.md ルール)

万一 RecordViewTests / HomeViewTests の一部が落ちたら、`-only-testing:` で当該テストを 1 件単独で再実行する。単独で pass すれば parallel simulator clone の flake と扱う。

- [ ] **Step 6: Commit**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin && \
git add app/OtetsudaiCoin/Presentation/Views/RecordView.swift && \
git commit -m "$(cat <<'EOF'
feat(#49): RecordView のスクロール末端に AdMob バナーを追加

毎日触られる主画面 RecordView の ScrollView 内 VStack 末尾、
StateBasedContent の直後に BannerAdView().frame(height: 50) を配置。
loading/error 中も常時表示できるよう StateBasedContent の外側に置く。

配置決定の根拠 (spec § 方針判断):
- Approach A (RecordView 下部常時 banner) + Option 2 (ScrollView 内最下)
- 子供が触る画面のため、CTA recordButtonView (固定下部) から物理距離確保
- impressions 不足なら follow-up issue で Option 1 (固定下部) への移行検討

TaskManagementView の既存 banner はゼロコストの二重露出として保持。

Test:
- 新規 RecordViewTests/testRecordViewIncludesBannerAdAtBottom が green
- RecordViewTests / RecordViewModelTests / HomeViewTests 全件 green を確認

Refs #49

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Simulator での手動目視確認

**Files:** なし (実行のみ)

- [ ] **Step 1: シミュレータ起動**

Run:
```bash
xcrun simctl boot "iPhone 17" || true
open -a Simulator
```
Expected: シミュレータが起動 / 既に boot 済みなら no-op。

- [ ] **Step 2: app build & install**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin/app && \
xcodebuild -project OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: app install & launch**

Run:
```bash
DERIVED=$(xcodebuild -project /Users/shinya/workspace/claude/OtetsudaiCoin/app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17' -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR =/{print $3}')
APP="$DERIVED/OtetsudaiCoin.app"
DEVICE_ID=$(xcrun simctl list devices booted | awk '/iPhone 17 \(/{gsub(/[()]/,"",$NF); print $NF; exit}')
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl launch "$DEVICE_ID" com.asapapalab.OtetsudaiCoin
```
Expected: アプリ起動。**Tutorial や Splash を bypass したい場合**、`ios-simulator-app-verification` skill の UserDefaults プリセットを参照。

- [ ] **Step 4: RecordView 到達 + scroll でバナー確認**

(手作業) シミュレータ画面で:
1. 子供がいない初回なら ChildFormView で 1 名登録 → ホームに戻る
2. タブの「記録」をタップ → RecordView 表示
3. 画面を上にスワイプして scroll 末端まで移動
4. 画面下部固定の「記録する」ボタンの **上**（scroll 領域末端）に「Test Ad」ラベル付きの banner (高さ 50pt) が表示されることを確認

Expected: テスト広告（Google AdMob のサンプル "Test Ad" バナー）が表示される。DEBUG ビルドなので本番広告ではなく test ad が表示される (`AdConstants.bannerAdUnitID` の DEBUG 分岐)。

- [ ] **Step 5: スクリーンショット保存 (PR エビデンス用)**

Run:
```bash
DEVICE_ID=$(xcrun simctl list devices booted | awk '/iPhone 17 \(/{gsub(/[()]/,"",$NF); print $NF; exit}')
mkdir -p /tmp/issue-49-screenshots
xcrun simctl io "$DEVICE_ID" screenshot /tmp/issue-49-screenshots/recordview-banner-bottom.png
echo "saved: /tmp/issue-49-screenshots/recordview-banner-bottom.png"
```
Expected: PNG が保存される。PR body に貼付けて視認性を伝える。

---

## Task 4: push & PR 作成

**Files:** なし (git 操作のみ)

- [ ] **Step 1: push 前 CLAUDE.md ルール遵守確認**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin && \
git status && echo "---" && \
gh pr list --head feat/issue-49-recordview-banner --json number,state,title
```
Expected:
- branch が `feat/issue-49-recordview-banner` であること
- working tree clean
- 既存 PR なし (`[]`)

- [ ] **Step 2: push**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin && \
git push -u origin feat/issue-49-recordview-banner
```
Expected: `* [new branch]      feat/issue-49-recordview-banner -> feat/issue-49-recordview-banner`

- [ ] **Step 3: PR 作成**

Run:
```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin && \
gh pr create --title "feat(#49): RecordView スクロール末端に AdMob バナーを追加" --body "$(cat <<'EOF'
## Summary

毎日触られる主画面 RecordView の ScrollView 末端に AdMob バナーを 1 つ追加し、
これまで TaskManagementView (Settings 配下) のみだった impressions を、
実際に使われる画面で稼げるようにします。

### 設計判断 (spec 抜粋)

- **Approach A + Option 2**: ScrollView 内 VStack の StateBasedContent 直後に
  \`BannerAdView().frame(height: 50)\` を配置 (loading/error 中も表示)
- **TaskManagementView の既存 banner は保持** (ゼロコストの二重露出)
- **子供 tap 安全性**: 画面下部固定の \`recordButtonView\` (CTA) は ScrollView の
  外側にあり、\`.background(.ultraThinMaterial)\` で視覚分離。banner は ScrollView
  末端のみで scroll しないと触れない位置

### 設計書

\`docs/superpowers/specs/2026-05-19-recordview-banner-ad-design.md\`

### 計測

merge 後 **1 週間** AdMob console で impressions delta を観測。想定より伸びない場合
は follow-up issue で **Option 1 (固定下部)** への移行を検討。

## Test plan

- [x] 新規 \`RecordViewTests/testRecordViewIncludesBannerAdAtBottom\` が green
- [x] \`RecordViewTests\` / \`RecordViewModelTests\` / \`HomeViewTests\` 全件 green (regression なし)
- [x] DEBUG ビルドで simulator (iPhone 17) で RecordView 下部に "Test Ad" バナー表示確認
- [ ] CI で xcodebuild test 全体実行
- [ ] TestFlight ビルドで実機での本番広告表示確認 (post-merge)
- [ ] AdMob console で merge 後 1 週間の impressions delta 観測 (post-merge)

## 変更ファイル

- \`app/OtetsudaiCoin/Presentation/Views/RecordView.swift\` — banner 配置 1 ブロック追加
- \`app/OtetsudaiCoinTests/Presentation/Views/RecordViewTests.swift\` — 新規作成 (ViewInspector 存在テスト)
- \`docs/superpowers/specs/2026-05-19-recordview-banner-ad-design.md\` — 設計書
- \`app/OtetsudaiCoin.xcodeproj/project.pbxproj\` — テストファイル登録

## 関連

- 親 issue: #49
- 過去の AdMob 関連 PR: #10 (初回導入), #21 (本番 ID), #22 (ATT/npa=1)

Closes #49

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Expected: PR URL が出力される (例: `https://github.com/es0612/OtetsudaiCoin/pull/XX`)。

- [ ] **Step 4: PR URL をユーザーに共有**

PR URL を会話に貼り、必要なら screenshot (\`/tmp/issue-49-screenshots/recordview-banner-bottom.png\`) を SendUserFile で proactive に送る。

---

## Self-Review Result (plan 作成者による)

- **Spec coverage**:
  - 実装スコープ §1 (RecordView 修正) → Task 2 ✓
  - §2 (TaskManagementView 変更なし) → 明示的に「変更しないファイル」に記載 ✓
  - §3 (BannerAdView/AdConstants 変更なし) → 同上 ✓
  - §4 (テスト追加) → Task 1 ✓
  - §5 (やらないこと) → 暗黙的に plan のスコープ外 (Task 化なし) ✓
  - テスト計画 → Task 1, 2 (自動) + Task 3 (手動) ✓
  - ロールアウト → Task 4 (PR 作成) ✓
- **Placeholder scan**: TBD / TODO / 曖昧表現なし ✓
- **Type consistency**: \`BannerAdView\` / \`RecordView\` / mock 名は spec / 実コード / plan 内すべてで一致 ✓
- **Ambiguity check**: Task 1 Step 3 の Xcode GUI vs スクリプト追加で 2 通り示しているが「最も確実なのは GUI」と推奨を明示 → 受容可
