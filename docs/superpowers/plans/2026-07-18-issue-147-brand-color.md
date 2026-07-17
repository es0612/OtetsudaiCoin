# Issue #147: ブランドカラー確立と青→紫グラデ廃止 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 青→紫グラデーションを全廃し、「オレンジ × ティール」ブランドカラー体系(spec: `docs/superpowers/specs/2026-07-18-brand-color-design.md`)を確立する。

**Architecture:** ブランド色は `AccessibilityColors` に集約(#146 の役割宣言に従う)。`GradientButtonStyle.swift` を `AppButtonStyle.swift`(ソフト角丸 20pt 単色の `SolidButtonStyle`)へ置換し、呼び出し 11 箇所をリネーム。Tutorial 背景は温色グラデ、アイコン円は単色化。アバタープリセットは調和 12 色へ刷新。

**Tech Stack:** SwiftUI / XCTest。Xcode project は `PBXFileSystemSynchronizedRootGroup` のため新規 .swift はディレクトリ配置のみで認識(pbxproj 編集不要)。

## Global Constraints

- branch: `feature/issue-147-brand-color`(作成済み・design doc commit 済み)
- テスト実行はリポジトリ root からではなく `app/` の project 指定: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/<TestClass> 2>&1 | tail -20`(結果は `** TEST SUCCEEDED / FAILED **` 文言で判定。exit code チェーンを鵜呑みにしない)
- ブランド色 hex(暫定→Task 2 のコントラストテストで確定): brandPrimary `#E8590C` / brandPrimaryDark `#C2410C` / brandSecondary `#099268` / brandAccent `#FFD43B` / brandSurfaceWarm `#FFF4E6`
- ボタンラベルは 17pt semibold = WCAG large text 基準: 白文字とのコントラスト **3.0:1 以上必須**
- semantic colors(successGreen / errorRed / warningOrange)は変更しない
- 既存ユーザーの保存済み themeColor は migration しない
- commit footer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy`

---

### Task 1: ColorExtensions の contrastRatio スタブを本実装に修正

spec は「既存 `contrastRatio(with:)` で検証」としていたが、調査で `relativeLuminance()` が **常に 0.5 を返すスタブ**と判明(`app/OtetsudaiCoin/Utils/ColorExtensions.swift:47`)。Task 2 のコントラスト検証の前提となるため先に本実装へ直す。**consumer は grep 済みでゼロ**(`optimalTextColor` / `accessibleTextColor` / `isAccessible` は定義のみ、app/Tests/UITests 全ターゲット未使用)なので挙動変更は安全。

**Files:**
- Modify: `app/OtetsudaiCoin/Utils/ColorExtensions.swift:40-48`(`relativeLuminance()`)
- Test: `app/OtetsudaiCoinTests/Utils/ColorExtensionsTests.swift`(新規)

**Interfaces:**
- Produces: `Color.contrastRatio(with:) -> Double` が WCAG 2.1 の実計算値を返す(Task 2 が使用)

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Utils/ColorExtensionsTests.swift` を新規作成:

```swift
import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class ColorExtensionsTests: XCTestCase {

    func testContrastRatioWhiteVsBlackIs21() {
        let ratio = Color.white.contrastRatio(with: .black)
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1, "white/black は WCAG 定義で 21:1 (actual: \(ratio))")
    }

    func testContrastRatioIsSymmetric() {
        let a = Color(hex: "#E8590C")!
        let ratio1 = a.contrastRatio(with: .white)
        let ratio2 = Color.white.contrastRatio(with: a)
        XCTAssertEqual(ratio1, ratio2, accuracy: 0.001)
    }

    func testContrastRatioKnownValue() {
        // #767676 は白背景で 4.54:1 の既知の WCAG 境界色
        let gray = Color(hex: "#767676")!
        let ratio = gray.contrastRatio(with: .white)
        XCTAssertEqual(ratio, 4.54, accuracy: 0.05, "actual: \(ratio)")
    }
}
```

- [ ] **Step 2: テストが FAIL することを確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/ColorExtensionsTests 2>&1 | tail -20`

Expected: FAIL(スタブは全色 luminance=0.5 → 全 ratio が 1.0 になり 21.0 と不一致)。これは behavioral red なので **実行必須**(スキップ不可)。

- [ ] **Step 3: relativeLuminance を本実装に置換**

`app/OtetsudaiCoin/Utils/ColorExtensions.swift` の `relativeLuminance()`(40 行目付近〜末尾)を以下で置換:

```swift
    /// 相対輝度を計算(WCAG 2.1 定義)
    private func relativeLuminance() -> Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0.5
        }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
```

既存の「暫定値」コメント(43-47 行の説明コメントと `return 0.5`)は削除する。`import UIKit` は不要(SwiftUI が透過的に提供)だが、ビルドエラーになる場合のみ追加。

- [ ] **Step 4: テストが PASS することを確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`、3 テスト PASS

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Utils/ColorExtensions.swift app/OtetsudaiCoinTests/Utils/ColorExtensionsTests.swift
git commit -m "fix(#147): contrastRatio の relativeLuminance スタブを WCAG 2.1 実計算に修正

Task 2 のブランド色コントラスト検証の前提。consumer は全ターゲット grep でゼロ確認済み。

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 2: Brand Colors を AccessibilityColors に追加(コントラスト検証付き)

**Files:**
- Modify: `app/OtetsudaiCoin/Utils/AccessibilityColors.swift`(`// MARK: - Utility Functions` の直前に挿入)
- Test: `app/OtetsudaiCoinTests/Utils/BrandColorsTests.swift`(新規)

**Interfaces:**
- Consumes: Task 1 の `Color.contrastRatio(with:)`
- Produces: `AccessibilityColors.brandPrimary` / `.brandPrimaryDark` / `.brandSecondary` / `.brandAccent` / `.brandSurfaceWarm`(いずれも `static let ...: Color`。Task 3-7 が使用)

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Utils/BrandColorsTests.swift` を新規作成:

```swift
import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class BrandColorsTests: XCTestCase {

    // ボタンラベルは 17pt semibold = WCAG large text 基準 (3.0:1)
    func testBrandPrimaryContrastOnWhiteTextMeetsLargeTextAA() {
        let ratio = AccessibilityColors.brandPrimary.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "brandPrimary は白文字ボタン地に使う (actual: \(ratio))")
    }

    func testBrandSecondaryContrastOnWhiteTextMeetsLargeTextAA() {
        let ratio = AccessibilityColors.brandSecondary.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "brandSecondary は白文字ボタン地に使う (actual: \(ratio))")
    }

    func testBrandPrimaryDarkContrastOnWhiteMeetsAA() {
        let ratio = AccessibilityColors.brandPrimaryDark.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "押下状態・強調用は AA (actual: \(ratio))")
    }

    func testBrandSurfaceWarmIsLightBackground() {
        // 淡背景は黒文字が AA (4.5:1) で載ること
        let ratio = AccessibilityColors.brandSurfaceWarm.contrastRatio(with: .black)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "brandSurfaceWarm は淡背景 (actual: \(ratio))")
    }
}
```

- [ ] **Step 2: コンパイルエラーで FAIL することを確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/BrandColorsTests 2>&1 | tail -20`

Expected: BUILD FAILED(`brandPrimary` 未定義)。コンパイルエラー確定型なので、BUILD FAILED のログ確認をもって red 扱いにしてよい(CLAUDE.md の skip 条件 (a) だが実行自体は行う)。

- [ ] **Step 3: Brand Colors セクションを追加**

`app/OtetsudaiCoin/Utils/AccessibilityColors.swift` の `// MARK: - Utility Functions` の直前に挿入:

```swift
    // MARK: - Brand Colors (Issue #147: オレンジ × ティール)

    /// ブランドプライマリ(温かいオレンジ)。メイン CTA・AccentColor・進捗バーに使用。
    /// 白文字ボタン地として WCAG large text 基準 (3:1) を BrandColorsTests で担保。
    static let brandPrimary = Color(hex: "#E8590C") ?? .orange

    /// ブランドプライマリの濃色。押下状態・ダークモード調整用 (白文字 AA 4.5:1)。
    static let brandPrimaryDark = Color(hex: "#C2410C") ?? .orange

    /// ブランドセカンダリ(ティール)。記録・保存など成功系アクションに使用。
    static let brandSecondary = Color(hex: "#099268") ?? .green

    /// ブランドアクセント(コインゴールド)。コイン表現・お祝い演出に使用。
    /// 白文字は載らないため地色として使う場合は濃色文字と組み合わせる。
    static let brandAccent = Color(hex: "#FFD43B") ?? .yellow

    /// 温色の淡背景。
    static let brandSurfaceWarm = Color(hex: "#FFF4E6") ?? .orange.opacity(0.1)
```

- [ ] **Step 4: テストが PASS することを確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`。もし contrast 不足で FAIL したら(想定計算値: brandPrimary≈3.58 / brandSecondary≈3.95 / brandPrimaryDark≈5.2)、FAIL した色を次の代替へ暗め調整して再実行: brandSecondary → `#087F5B`、brandPrimary → `#D9480F`。調整した場合は spec (`docs/superpowers/specs/2026-07-18-brand-color-design.md`) の表も同時更新する。

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Utils/AccessibilityColors.swift app/OtetsudaiCoinTests/Utils/BrandColorsTests.swift
git commit -m "feat(#147): ブランドカラー(オレンジ×ティール)を AccessibilityColors に追加

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 3: AppButtonStyle(ソフト角丸単色ボタン)を新設

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/Views/Components/AppButtonStyle.swift`
- Test: `app/OtetsudaiCoinTests/Presentation/Components/AppButtonStyleTests.swift`(新規)

**Interfaces:**
- Consumes: `AccessibilityColors.brandPrimary` / `.brandSecondary` / `.errorRed`(Task 2)、`AppRadius.xLarge` / `AppShadow.cardElevated`(#146 既存)
- Produces: `SolidButtonStyle(backgroundColor:isDisabled:)`(`backgroundColor: Color` / `isDisabled: Bool` は `let` 公開)、プリセット `SolidButtonStyle.primary` / `.success` / `.destructive`、View extension `primaryButton(isDisabled: Bool = false)` / `successButton(isDisabled: Bool = false)` / `destructiveButton(isDisabled: Bool = false)`(Task 4-5 が使用)

- [ ] **Step 1: 失敗するテストを書く**

`app/OtetsudaiCoinTests/Presentation/Components/AppButtonStyleTests.swift` を新規作成:

```swift
import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class AppButtonStyleTests: XCTestCase {

    func testPrimaryPresetUsesBrandPrimary() {
        XCTAssertEqual(SolidButtonStyle.primary.backgroundColor, AccessibilityColors.brandPrimary)
        XCTAssertFalse(SolidButtonStyle.primary.isDisabled)
    }

    func testSuccessPresetUsesBrandSecondary() {
        XCTAssertEqual(SolidButtonStyle.success.backgroundColor, AccessibilityColors.brandSecondary)
    }

    func testDestructivePresetUsesErrorRed() {
        XCTAssertEqual(SolidButtonStyle.destructive.backgroundColor, AccessibilityColors.errorRed)
    }

    func testDefaultInitIsPrimaryEnabled() {
        let style = SolidButtonStyle()
        XCTAssertEqual(style.backgroundColor, AccessibilityColors.brandPrimary)
        XCTAssertFalse(style.isDisabled)
    }

    func testDisabledFlagIsStored() {
        let style = SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary, isDisabled: true)
        XCTAssertTrue(style.isDisabled)
    }
}
```

- [ ] **Step 2: コンパイルエラーで FAIL することを確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/AppButtonStyleTests 2>&1 | tail -20`

Expected: BUILD FAILED(`SolidButtonStyle` 未定義)

- [ ] **Step 3: AppButtonStyle.swift を実装**

`app/OtetsudaiCoin/Presentation/Views/Components/AppButtonStyle.swift` を新規作成:

```swift
import SwiftUI

// MARK: - 単色ソフト角丸ボタンスタイル (Issue #147: 青→紫グラデ廃止)

/// ブランドカラー単色 + ソフト角丸 (AppRadius.xLarge) のボタンスタイル。
/// 旧 GradientButtonStyle の後継。押下時の縮小アニメーションは踏襲し、グローは廃止。
struct SolidButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let isDisabled: Bool

    init(backgroundColor: Color = AccessibilityColors.brandPrimary, isDisabled: Bool = false) {
        self.backgroundColor = backgroundColor
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(isDisabled ? Color.gray.opacity(0.6) : backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xLarge))
            .appShadow(isDisabled ? AppShadowStyle(color: .clear, radius: 0, x: 0, y: 0) : AppShadow.cardElevated)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - プリセットスタイル

extension SolidButtonStyle {
    /// メイン CTA (ブランドオレンジ)
    static let primary = SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary)
    /// 記録・保存など成功系アクション (ティール)
    static let success = SolidButtonStyle(backgroundColor: AccessibilityColors.brandSecondary)
    /// 削除など破壊的アクション (エラーレッド)
    static let destructive = SolidButtonStyle(backgroundColor: AccessibilityColors.errorRed)
}

// MARK: - View Extension

extension View {
    func primaryButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary, isDisabled: isDisabled))
    }

    func successButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandSecondary, isDisabled: isDisabled))
    }

    func destructiveButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.errorRed, isDisabled: isDisabled))
    }
}
```

- [ ] **Step 4: テストが PASS することを確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`、5 テスト PASS

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Components/AppButtonStyle.swift app/OtetsudaiCoinTests/Presentation/Components/AppButtonStyleTests.swift
git commit -m "feat(#147): ソフト角丸単色の SolidButtonStyle を新設

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 4: 呼び出し 11 箇所を置換し GradientButtonStyle を削除

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/TaskListActionButtons.swift:19` / `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:193` / `app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift:217` / `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift:94` / `app/OtetsudaiCoin/Presentation/Views/ChildFormView.swift:108` / `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift:133,145` / `app/OtetsudaiCoin/Presentation/Views/Components/StateBasedContent.swift:80` / `app/OtetsudaiCoin/Presentation/Components/RecordButtonBar.swift:25` / `app/OtetsudaiCoin/Presentation/Views/TaskManagementView.swift:209` / `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:324`
- Delete: `app/OtetsudaiCoin/Presentation/Views/Components/GradientButtonStyle.swift`
- Test: 既存の `RecordButtonBarTests` / `TaskListActionButtonsTests` が green のままであること

**Interfaces:**
- Consumes: Task 3 の `primaryButton()` / `successButton()` / `destructiveButton()`

- [ ] **Step 1: 機械的リネームを実施**

引数は既存のまま名前だけ置換する(isDisabled 引数がある呼び出しはそのまま渡す):

| 対象 | 置換 |
| --- | --- |
| `.primaryGradientButton()` (7 箇所: TaskListActionButtons:19, HelpHistoryView:193, MonthlySummaryView:217, SettingsView:94, StateBasedContent:80) | `.primaryButton()` |
| `.primaryGradientButton(isDisabled: !isValidInput)` (ChildFormView:108) | `.primaryButton(isDisabled: !isValidInput)` |
| `.primaryGradientButton(isDisabled: !viewModel.hasChanges \|\| viewModel.isLoading)` (HelpRecordEditView:133) | `.primaryButton(isDisabled: !viewModel.hasChanges \|\| viewModel.isLoading)` |
| `.successGradientButton(isDisabled: recordButtonDisabled)` (RecordButtonBar:25) | `.successButton(isDisabled: recordButtonDisabled)` |
| `.successGradientButton(isDisabled: taskName...isEmpty)` (TaskManagementView:209) | `.successButton(isDisabled: taskName...isEmpty)` |
| `.successGradientButton(isDisabled: hasRecorded)` (RecordTutorialView:324) | `.successButton(isDisabled: hasRecorded)` |
| `.warningGradientButton(isDisabled: viewModel.isLoading)` (HelpRecordEditView:145 削除ボタン) | `.destructiveButton(isDisabled: viewModel.isLoading)` |

- [ ] **Step 2: GradientButtonStyle.swift を削除**

```bash
git rm app/OtetsudaiCoin/Presentation/Views/Components/GradientButtonStyle.swift
```

- [ ] **Step 3: 全ターゲット残存参照 grep(CLAUDE.md 削除ルール)**

```bash
grep -rn "GradientButton\|gradientButton" app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests
```

Expected: 出力ゼロ(1 件でも残れば置換漏れ。修正してから次へ)

- [ ] **Step 4: ビルド + 関連コンポーネントテストで green 確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/RecordButtonBarTests -only-testing:OtetsudaiCoinTests/TaskListActionButtonsTests -only-testing:OtetsudaiCoinTests/AppButtonStyleTests 2>&1 | tail -20`

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A app/
git commit -m "refactor(#147): グラデボタン 11 箇所を SolidButtonStyle へ置換し GradientButtonStyle を削除

参照ゼロの accentGradientButton / CompactGradientButtonStyle も同時削除。
全ターゲット grep で残存参照ゼロを確認済み。

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 5: Tutorial 2 画面を温色グラデ + 単色アイコンに統一

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift:19-24,91,170,187`
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:28-33,114,357`

**Interfaces:**
- Consumes: `AccessibilityColors.brandPrimary` / `.brandSecondary` / `.brandAccent`(Task 2)

- [ ] **Step 1: ChildTutorialView を置換(4 箇所)**

:19 背景グラデ:

```swift
            LinearGradient(
                colors: [AccessibilityColors.brandPrimary.opacity(0.10), AccessibilityColors.brandAccent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
```

:91 welcome アイコン円(`.fill(LinearGradient(colors: [.blue, .purple], ...))`):

```swift
                    .fill(AccessibilityColors.brandPrimary)
```

:170 CTA ボタン背景(`LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)`):

```swift
                        AccessibilityColors.brandPrimary
```

:187 completion アイコン円(`[.green, .blue]`):

```swift
                    .fill(AccessibilityColors.brandSecondary)
```

- [ ] **Step 2: RecordTutorialView を置換(3 箇所)**

:28 背景グラデ:

```swift
            LinearGradient(
                colors: [AccessibilityColors.brandPrimary.opacity(0.10), AccessibilityColors.brandAccent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
```

:114 intro アイコン円(`[.green, .blue]`)→ `.fill(AccessibilityColors.brandSecondary)`
:357 completion トロフィー円(`[.yellow, .orange]`)→ `.fill(AccessibilityColors.brandPrimary)`

- [ ] **Step 3: 青紫系グラデの残存 grep**

```bash
grep -rn "\.blue, \.purple\|\.purple, \.blue\|\.green, \.blue\|\.pink, \.purple" app/OtetsudaiCoin --include="*.swift"
```

Expected: 出力ゼロ(SkeletonViews / Splash / 子テーマ色グラデは色リテラル構成が異なるためヒットしない)

- [ ] **Step 4: ビルド確認**

Run: `xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/
git commit -m "refactor(#147): Tutorial 2 画面を温色ブランドグラデ + 単色アイコン円に統一

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 6: AccentColor asset をブランドオレンジに設定

**Files:**
- Modify: `app/OtetsudaiCoin/Assets.xcassets/AccentColor.colorset/Contents.json`

- [ ] **Step 1: Contents.json を置換**

ライト #E8590C / ダーク #FF7A2E(明るめ調整):

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x0C",
          "green" : "0x59",
          "red" : "0xE8"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x2E",
          "green" : "0x7A",
          "red" : "0xFF"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: ビルド確認**

Run: `xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`(asset catalog の JSON 構文エラーはビルドで検出される)

- [ ] **Step 3: Commit**

```bash
git add app/OtetsudaiCoin/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "feat(#147): AccentColor をブランドオレンジに設定 (dark variant 付き)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 7: アバタープリセット 12 色刷新 + デフォルト/サンプルデータ更新

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/ChildManagementViewModel.swift:11-16`
- Modify: `app/OtetsudaiCoin/Presentation/Views/ChildFormView.swift:10`
- Modify: `app/OtetsudaiCoin/ContentView.swift:149-150`
- Modify: `app/OtetsudaiCoin/Domain/Services/SampleDataService.swift:25-26`
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift:213`(preview 用)
- Test: `app/OtetsudaiCoinTests/Presentation/ViewModels/ChildManagementViewModelTests.swift`(テスト追加)

**Interfaces:**
- Produces: `getAvailableThemeColors() -> [String]` が 12 色を返す(シグネチャ不変)

- [ ] **Step 1: プリセット検証テストを追加**

`ChildManagementViewModelTests.swift` の class 末尾に追加:

```swift
    @MainActor
    func testAvailableThemeColorsAreTwelveUniqueParseableColors() {
        let colors = viewModel.getAvailableThemeColors()
        XCTAssertEqual(colors.count, 12, "パレット調和の 12 色 (actual: \(colors.count))")
        XCTAssertEqual(Set(colors).count, colors.count, "重複なし")
        for hex in colors {
            XCTAssertNotNil(Color(hex: hex), "\(hex) は Color(hex:) で解釈可能であること")
        }
        XCTAssertEqual(colors.first, "#E8590C", "先頭はブランドオレンジ (ChildFormView のデフォルトと一致)")
    }
```

`import SwiftUI` が無ければファイル先頭に追加。

- [ ] **Step 2: テストが FAIL することを確認**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests/ChildManagementViewModelTests 2>&1 | tail -20`

Expected: 新テストのみ FAIL(現状 25 色ネオンリストのため count 不一致)。既存テストは PASS を維持していること。

- [ ] **Step 3: プリセットとデフォルト・サンプル色を更新**

`ChildManagementViewModel.swift:11-16` を置換(Open Color 系 shade 6-8 の調和 12 色):

```swift
    private let themeColors: [String] = [
        "#E8590C", // ブランドオレンジ
        "#FAB005", // ハニーイエロー
        "#66A80F", // ライム
        "#2F9E44", // グリーン
        "#099268", // ブランドティール
        "#0C8599", // シアン
        "#1C7ED6", // ブルー
        "#3B5BDB", // インディゴ
        "#7048E8", // バイオレット
        "#AE3EC9", // グレープ
        "#D6336C", // ピンク
        "#E03131"  // レッド
    ]
```

`ChildFormView.swift:10`:

```swift
    @State private var selectedThemeColor: String = "#E8590C"
```

`ContentView.swift:149-150` と `SampleDataService.swift:25-26`(同一内容):

```swift
                            Child(id: UUID(), name: "太郎", themeColor: "#E8590C"),
                            Child(id: UUID(), name: "花子", themeColor: "#099268")
```

(SampleDataService はインデント 12 スペース側に合わせる)

`HelpRecordEditView.swift:213`:

```swift
            let child = Child(id: UUID(), name: "太郎", themeColor: "#E8590C")
```

- [ ] **Step 4: テストが PASS することを確認**

Run: Step 2 と同じコマンド
Expected: `** TEST SUCCEEDED **`(既存テスト含め全 PASS。既存テストは任意 hex 使用でプリセット非依存を確認済み)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/ChildManagementViewModel.swift app/OtetsudaiCoin/Presentation/Views/ChildFormView.swift app/OtetsudaiCoin/ContentView.swift app/OtetsudaiCoin/Domain/Services/SampleDataService.swift app/OtetsudaiCoin/Presentation/Views/HelpRecordEditView.swift app/OtetsudaiCoinTests/Presentation/ViewModels/ChildManagementViewModelTests.swift
git commit -m "feat(#147): アバタープリセットをパレット調和の 12 色に刷新

デフォルト選択色とサンプルデータ (太郎/花子) もブランド色へ。
既存ユーザーの保存済み themeColor は migration しない (Color(hex:) で表示互換)。

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DsNUB8Tn2vfw6sdVJu9ivy"
```

---

### Task 8: 全体テスト + before/after 視覚検証

**Files:**
- 参照のみ(コード変更なし)。スクショ出力 `docs/screenshots/asc/v1.1.x/{ja,en}/` は目視後 discard

- [ ] **Step 1: unit テスト全体を実行**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:OtetsudaiCoinTests 2>&1 | tail -30`

Expected: `** TEST SUCCEEDED **`。FAIL 時は log の `Failing tests:` を確認し、詳細が出ない場合は `.xcresult` を `xcrun xcresulttool get test-results tests --path <xcresult>` で開く(CLAUDE.md ルール)。

- [ ] **Step 2: before スクショを取得(HEAD~N = main 相当)**

before は撮影済みの committed スクショ(`git show origin/main:docs/screenshots/asc/v1.1.x/ja/01-home.png` 等)をそのまま before として使用(手戻り防止のため再撮影しない)。scratchpad へ抽出:

```bash
mkdir -p /private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/93a050ca-80ad-423e-b3bd-5adf77c259a8/scratchpad/before
for f in 01-home 02-record 03-settings; do
  git show "origin/main:docs/screenshots/asc/v1.1.x/ja/$f.png" > "/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/93a050ca-80ad-423e-b3bd-5adf77c259a8/scratchpad/before/$f.png"
done
```

- [ ] **Step 3: after スクショを撮影**

```bash
./scripts/capture-asc-screenshots.sh
```

Expected: `docs/screenshots/asc/v1.1.x/{ja,en}/` に 6 PNG 再生成(exit 0)

- [ ] **Step 4: before/after を Read で並べて一次目視**

`scratchpad/before/*.png` と `docs/screenshots/asc/v1.1.x/ja/*.png` を Read し、以下を確認して所見を表にまとめる:

- ボタンが青→紫グラデでなくオレンジ / ティール単色になっている
- サンプル子どもアバターが新パレット色
- 崩れ(文字はみ出し・コントラスト低下)がない
- 変更対象外の差分(status bar 時刻・記録日churn)の内訳を切り分ける(CLAUDE.md 再撮影ルール)

- [ ] **Step 5: after スクショを PR 添付用に scratchpad へ退避して discard**

```bash
cp docs/screenshots/asc/v1.1.x/ja/*.png /private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/93a050ca-80ad-423e-b3bd-5adf77c259a8/scratchpad/after-ja/
git checkout -- docs/screenshots/
git status --short  # docs/screenshots 差分ゼロを確認
```

(ASC artifact を feature PR に混ぜない CLAUDE.md ルール。`after-ja/` は事前に `mkdir -p`)

- [ ] **Step 6: 視覚検証所見を記録して完了報告**

before/after 比較の所見(変更点内訳・out-of-scope finding の有無)を PR description 用にまとめる。out-of-scope finding があれば PR description に inline 記載 + merge 後 issue 化(CLAUDE.md ルール)。

---

## Plan 自己レビュー済み事項

- spec カバレッジ: パレット定義(Task 2)/ ボタン置換(Task 3-4)/ Tutorial(Task 5)/ AccentColor(Task 6)/ アバター(Task 7)/ テスト・視覚検証(Task 1,8)— spec 全セクション対応
- spec からの既知の逸脱: `contrastRatio` がスタブと判明したため Task 1(修正)を追加。PR description の `## Plan からの逸脱` ではなく plan 段階で織り込み済みと記載する
- 型整合: `SolidButtonStyle.backgroundColor: Color` / `isDisabled: Bool`、extension 名 `primaryButton/successButton/destructiveButton` を Task 3(定義)と Task 4-5(使用)で一致確認済み
