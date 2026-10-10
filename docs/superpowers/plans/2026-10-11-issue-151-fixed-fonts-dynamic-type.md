# #151 提案3: 固定フォント `.system(size: <数値>)` 14 件の Dynamic Type 追従 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Presentation 配下に残る数値リテラル指定の `.font(.system(size: N))` 14 件を、文字サイズ設定 (Dynamic Type) に追従させる。装飾の大きなアイコンは上限つき (最大 1.3 倍) で拡大し、AX サイズで見出しやボタンを画面外へ押し出さないようにする。

**Architecture:** 新規 `DecorativeScale` (pure helper) が「`@ScaledMetric` の生の倍率 → 1.0〜1.3 倍へ clamp」を担い、`ViewModifier` 2 つ (`.decorativeFont(size:weight:design:)` / `.decorativeFrame(size:)`) が `@ScaledMetric(relativeTo: .largeTitle)` を読んで呼び出し側へ配る。呼び出し側は数値の基準サイズを渡すだけになり、上限ルールは 1 ファイルに集まる。操作アイコン (履歴行の ✏️ / 🗑) はテキストスタイル `.callout` (既定 16pt) にして上限なしで追従させ、タップ枠を `minWidth/minHeight: 44` へ変えてアイコンと一緒に広がるようにする。

**Tech Stack:** SwiftUI (`@ScaledMetric`, `ViewModifier`), ViewInspector 0.10.2 (findAll ベース), XCTest

**Spec:** GitHub Issue #151 本文「提案3: 固定サイズフォントを `.font(.title)` 等のスタイル or `@ScaledMetric` へ置換」+ 受け入れ条件「主要画面が Dynamic Type に追従する」。2026-10-11 triage で user が装飾アイコンの方針を「上限つきで拡大」に決定。先行計画: `docs/superpowers/plans/2026-08-31-issue-151-dynamic-type-subset.md` (カレンダー日セルの `@ScaledMetric` + clamp helper の型)。

## Global Constraints

- 対象 14 件 (2026-10-11 に `grep -rn "\.system(size:" app/OtetsudaiCoin` で実測、すべて SF Symbol か Text):
  - 装飾アイコン 10 件: `HelpHistoryView.swift:170` (空状態 60) / `RecordTutorialView.swift:119` (円 120 内 50) `:150` (80) `:269` (80) `:362` (円 120 内 50) / `ChildTutorialView.swift:96` (円 120 内 50) `:127` (80) `:143` (60) `:181` (円 120 内 50) / `SplashScreenView.swift:63` (コイン 100 内 32 semibold)
  - 状態バッジ 1 件: `RecordTutorialView.swift:207` (60pt 固定アバター上の ✓ 14、背景円 14) → 固定サイズのアバターに載るので上限つき側
  - ワードマーク 1 件: `SplashScreenView.swift:79` (「OtetsudaiCoin」36 bold rounded) → ロゴ扱いで上限つき側 (上限なしだと AX5 で約 63pt になり 13 文字が 430pt 幅に 1 行で収まらない)
  - 操作アイコン 2 件: `HelpHistoryView.swift:389` (✏️ 16) `:399` (🗑 16) → `.callout` で上限なし
- 上限は **1.3 倍** (`DecorativeScale.maxFactor`)。下限は 1.0 倍 (小さい文字設定でも今より小さくしない。カレンダーの floor と同じ考え方)
- 倍率の基準テキストスタイルは `.largeTitle` (チュートリアルの見出しと同じ。largeTitle は AX1 で約 1.29 倍、AX2 で約 1.41 倍なので、上限には AX1〜AX2 で達する)
- `@ScaledMetric` の基準値は 100 にして `/ 100` で倍率にする (基準値 1 だと丸めが入った場合に倍率が 1 か 2 しか取れなくなるため)
- 既定の文字サイズ (`large`) では、14 件とも見た目のサイズが今と同じ (倍率 1.0 → 基準値そのもの。`.callout` も既定 16pt)
- `@ScaledMetric` の配線自体は ViewInspector から検証できない → 「clamp を pure helper の unit テストで固定し、配線はレビューと AX サイズの撮影で確かめる」を検証境界として PR description に書く (2026-08-31 計画と同じ扱い)
- ViewInspector の accessibilityIdentifier は iOS 26 で解決できない → `findAll(ViewType.X.self)` で書く。初めて使う traversal (`Image` の `flexFrame()`) に PASS が依存するので、assertion message に観測値を出す (#106 ルール)
- xcodebuild は FOREGROUND で実行し、判定は `grep -E -A6 '\*\* TEST|Failing tests:'` で読む (exit code で判定しない)
- unit テストの destination: `platform=iOS Simulator,name=iPhone 17` (2026-10-11 に `simctl list devices available` で 1 台だけあることを確認済み)
- 新規 `.swift` は置くだけで target に入る (`PBXFileSystemSynchronizedRootGroup`、pbxproj 編集不要)
- commit は path 指定で stage する (`git add -A` / `git add .` は使わない)

## Review Focus

1. **AX 最大サイズ (`accessibility-extra-extra-extra-large`) でチュートリアルの「次へ」ボタンが画面外に押し出されない (少なくとも今より悪化しない)** — 装飾アイコンが上限なしで大きくなると縦スクロールの無いステップで起きる。→ Task 5 Step 3 の before/after 撮影 (12 / 13) で確認
2. **既定サイズでは 14 件とも見た目が変わらない** (Splash のロゴも 36pt のまま) — → Task 1 の `test_size_atDefaultFactor_returnsBase` で倍率 1.0 → 基準値を固定、Task 5 Step 3 の既定サイズ撮影で目視
3. **小さい文字設定 (xSmall 等) で装飾アイコンが今より縮まない** — → Task 1 の `test_size_belowDefault_isFlooredAtBase`
4. **上限を超える倍率 (AX5 ≈ 1.76) でも 1.3 倍で止まる / 円とアイコンが同じ倍率で育つ (アイコンが円からはみ出さない)** — → Task 1 の `test_size_aboveCap_isClampedToMaxFactor` と、円とアイコンが同じ `DecorativeScale.size` を通ることを Task 3 / 4 のコードで担保
5. **履歴行の ✏️ / 🗑 は AX サイズでもタップ領域 44pt 以上を保ち、アイコンが枠の外にはみ出して隣と重ならない** — → Task 2 の `test_editAndDeleteButtons_meetMinimumTapTargetSize` を `flexFrame` (minWidth / minHeight) 版へ更新。記録ありの履歴画面は検証用撮影のシーンに無いため、AX での見た目は未確認として PR に書く

---

### Task 1: `DecorativeScale` helper と ViewModifier 2 つ

**Files:**
- Create: `app/OtetsudaiCoin/Utils/DecorativeScale.swift`
- Test: `app/OtetsudaiCoinTests/Utils/DecorativeScaleTests.swift`

**Interfaces:**
- Consumes: なし
- Produces:
  - `enum DecorativeScale { static let maxFactor: CGFloat; static func size(base: CGFloat, rawFactor: CGFloat) -> CGFloat }`
  - `extension View { func decorativeFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View }`
  - `extension View { func decorativeFrame(size: CGFloat) -> some View }` (正方形の `.frame(width:height:)`)

- [ ] **Step 1: Write the failing test**

`app/OtetsudaiCoinTests/Utils/DecorativeScaleTests.swift`:

```swift
import XCTest
@testable import OtetsudaiCoin

/// #151 提案3: 装飾アイコンを Dynamic Type に「上限つき」で追従させる clamp のテスト。
/// `@ScaledMetric` の配線は ViewInspector から読めないため、倍率 → サイズの変換だけを
/// pure helper で固定する (RecordCalendarView.clampedDayCellSize と同じ検証境界)。
final class DecorativeScaleTests: XCTestCase {

    /// 既定の文字サイズ (倍率 1.0) では今の固定値そのまま
    func test_size_atDefaultFactor_returnsBase() {
        XCTAssertEqual(DecorativeScale.size(base: 50, rawFactor: 1.0), 50)
        XCTAssertEqual(DecorativeScale.size(base: 120, rawFactor: 1.0), 120)
    }

    /// 上限 (1.3) までは倍率どおりに育つ
    func test_size_withinCap_scalesLinearly() {
        XCTAssertEqual(DecorativeScale.size(base: 80, rawFactor: 1.2), 96, accuracy: 0.001)
    }

    /// AX5 (largeTitle で約 1.76 倍) でも 1.3 倍で止まる
    func test_size_aboveCap_isClampedToMaxFactor() {
        XCTAssertEqual(DecorativeScale.maxFactor, 1.3)
        XCTAssertEqual(DecorativeScale.size(base: 80, rawFactor: 1.76), 104, accuracy: 0.001)
        XCTAssertEqual(DecorativeScale.size(base: 120, rawFactor: 3.0), 156, accuracy: 0.001)
    }

    /// 小さい文字設定 (倍率 1 未満) でも今より縮めない
    func test_size_belowDefault_isFlooredAtBase() {
        XCTAssertEqual(DecorativeScale.size(base: 50, rawFactor: 0.82), 50)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

型が未定義なのでコンパイルエラー (`BUILD FAILED`) が確定する → CLAUDE.md の red skip 条件 (a) に当たるので実行を省略してよい。省略したら commit メッセージに理由を書く。

- [ ] **Step 3: Write minimal implementation**

`app/OtetsudaiCoin/Utils/DecorativeScale.swift`:

```swift
import SwiftUI

/// #151 提案3: 装飾アイコン (チュートリアルの大きなアイコン・空状態・Splash のコインとロゴ) を
/// Dynamic Type に「上限つき」で追従させるための倍率ルール。
///
/// 上限なしで追従させると、AX サイズで 80pt のアイコンが 2 倍近くになり、縦スクロールの無い
/// チュートリアルで見出しや「次へ」ボタンを画面外へ押し出す。装飾は文字ほど大きくする必要が
/// ないので、1.3 倍で止めて画面の縦幅を文字に残す。
enum DecorativeScale {
    static let maxFactor: CGFloat = 1.3

    /// `@ScaledMetric` から得た生の倍率を 1.0〜maxFactor に clamp して base に掛ける。
    /// 下限 1.0 は「小さい文字設定でも今より縮めない」ため (RecordCalendarView の floor と同じ)。
    static func size(base: CGFloat, rawFactor: CGFloat) -> CGFloat {
        base * min(max(rawFactor, 1), maxFactor)
    }
}

/// 倍率は largeTitle 基準で読む。基準値を 100 にして /100 するのは、基準値 1 だと
/// 丸めが入った場合に倍率が 1 か 2 しか取れなくなるため。
private struct DecorativeFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @ScaledMetric(relativeTo: .largeTitle) private var scaledHundred: CGFloat = 100

    func body(content: Content) -> some View {
        content.font(.system(
            size: DecorativeScale.size(base: size, rawFactor: scaledHundred / 100),
            weight: weight,
            design: design
        ))
    }
}

private struct DecorativeFrameModifier: ViewModifier {
    let size: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var scaledHundred: CGFloat = 100

    func body(content: Content) -> some View {
        let side = DecorativeScale.size(base: size, rawFactor: scaledHundred / 100)
        return content.frame(width: side, height: side)
    }
}

extension View {
    /// 装飾アイコン / ロゴ用のフォント。既定サイズでは `size` そのもの、最大 1.3 倍まで育つ。
    func decorativeFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(DecorativeFontModifier(size: size, weight: weight, design: design))
    }

    /// 装飾アイコンを載せる円などの正方形 frame。`decorativeFont` と同じ倍率で育つので、
    /// 円の中のアイコンが円からはみ出さない。
    func decorativeFrame(size: CGFloat) -> some View {
        modifier(DecorativeFrameModifier(size: size))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
LOG=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad/t1.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/DecorativeScaleTests > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **` (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Utils/DecorativeScale.swift app/OtetsudaiCoinTests/Utils/DecorativeScaleTests.swift
git commit -m "feat(#151): 装飾アイコンを上限 1.3 倍で Dynamic Type に追従させる DecorativeScale を追加

TDD red は型未定義のコンパイルエラーが確定するため省略 (CLAUDE.md の skip 条件 a)。"
```

---

### Task 2: 履歴画面 (操作アイコン 2 件 + 空状態アイコン 1 件)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift:170` (空状態), `:388-391` (✏️), `:398-401` (🗑)
- Test: `app/OtetsudaiCoinTests/Presentation/Components/HelpRecordRowTests.swift` (既存 `test_editAndDeleteButtons_meetMinimumTapTargetSize` を書き換え)

**Interfaces:**
- Consumes: Task 1 の `.decorativeFont(size:)`
- Produces: なし

- [ ] **Step 1: Write the failing test**

`HelpRecordRowTests.swift` の `test_editAndDeleteButtons_meetMinimumTapTargetSize` を、固定 frame ではなく「最小 44pt の伸びる frame」を確かめる形へ書き換える (doc コメントの 1 段落目はそのまま残し、2 段落目以降を差し替え):

```swift
    /// #151: 編集・削除ボタンは HIG の最小タップ領域 44×44pt を満たす。
    ///
    /// 修正前は明示 frame が無く、`Image(systemName:).font(.system(size: 16))` の
    /// 実寸（約 16〜20pt）がそのままタップ領域だった。しかも 2 つが 12pt 間隔で
    /// 横並びなので、押し間違いが起きやすい。
    ///
    /// #151 提案3 でアイコンを `.callout` (Dynamic Type 追従) にしたため、枠は固定 44 ではなく
    /// `minWidth/minHeight: 44` にして、AX サイズでアイコンが育ったら枠も一緒に広がるようにした
    /// (固定 44 のままだと Image が枠からはみ出して隣のボタンと重なる)。
    ///
    /// `flexFrame()` を Image に使うのは本リポ初出なので、観測値を dump し、
    /// 「frame が読めない」のか「値が足りない」のかを再実行なしで切り分けられるようにする。
    func test_editAndDeleteButtons_meetMinimumTapTargetSize() throws {
        let minimumTapTarget: CGFloat = 44
        let view = makeView()

        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertEqual(buttons.count, 2, "編集・削除の 2 ボタンが見つからない (buttons=\(buttons.count))")

        // タップ領域は Button ではなく label 側の Image に付けている
        // (contentShape と組で当たり判定を frame 全体へ広げるため)。
        // frame を持たない兄弟 Image (star.fill) は compactMap で落ちる。
        let images = try view.inspect().findAll(ViewType.Image.self)
        let flexFrames = images.compactMap { try? $0.flexFrame() }
        let fixedFrames = images.compactMap { try? $0.fixedFrame() }
        let observed = "images=\(images.count) / flex=\(flexFrames.map { ($0.minWidth, $0.minHeight) }) / fixed=\(fixedFrames.map { ($0.width, $0.height) })"

        XCTAssertEqual(flexFrames.count, 2, "編集・削除アイコンの伸びる frame を 2 つ読めない (\(observed))")
        XCTAssertTrue(fixedFrames.isEmpty, "固定 frame が残っている (AX サイズでアイコンが枠からはみ出す) (\(observed))")

        for frame in flexFrames {
            XCTAssertGreaterThanOrEqual(frame.minWidth ?? 0, minimumTapTarget, "最小幅が 44pt 未満 (\(observed))")
            XCTAssertGreaterThanOrEqual(frame.minHeight ?? 0, minimumTapTarget, "最小高さが 44pt 未満 (\(observed))")
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
LOG=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad/t2.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests/HelpRecordRowTests > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: FAIL (`伸びる frame を 2 つ読めない` / `固定 frame が残っている`)。もし `flex=[]` かつ `fixed=[]` の両方空で落ちたら traversal 自体が届いていないので、実装に進まず報告する。

- [ ] **Step 3: Write minimal implementation**

`HelpHistoryView.swift` の編集・削除ボタン (2 箇所とも同じ形):

```swift
                Button(action: onEdit) {
                    // #151 提案3: .callout (既定 16pt) で Dynamic Type に追従。枠は min 44 にして
                    // AX サイズでアイコンが育ったら枠も広がるようにする (固定 44 だと隣と重なる)。
                    Image(systemName: "pencil")
                        .font(.callout)
                        .foregroundColor(AccessibilityColors.brandPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
```

```swift
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundColor(.red)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
```

`HelpHistoryView.swift:170` の空状態アイコン:

```swift
            Image(systemName: "list.clipboard")
                .decorativeFont(size: 60)
                .foregroundColor(.secondary)
```

- [ ] **Step 4: Run test to verify it passes**

Step 2 と同じコマンド。Expected: `** TEST SUCCEEDED **` (HelpRecordRowTests 全件)

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/HelpHistoryView.swift app/OtetsudaiCoinTests/Presentation/Components/HelpRecordRowTests.swift
git commit -m "fix(#151): 履歴の編集・削除アイコンと空状態アイコンを Dynamic Type に追従させる"
```

---

### Task 3: チュートリアル 2 画面 (9 件)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift:115-120, 150, 207-212, 269, 358-363`
- Modify: `app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift:92-97, 127, 143, 177-182`
- Test: なし (View の unit テストは既存に無く、`@ScaledMetric` の配線は ViewInspector から読めない。clamp は Task 1 で固定済み。見た目は Task 5 の撮影で確認)

**Interfaces:**
- Consumes: Task 1 の `.decorativeFont(size:weight:design:)` / `.decorativeFrame(size:)`
- Produces: なし

- [ ] **Step 1: 円 120 + アイコン 50 の 4 箇所を置換**

`RecordTutorialView.swift:115-120` / `:358-363`、`ChildTutorialView.swift:92-97` / `:177-182` の 4 箇所は同じ形。円の frame とアイコンのフォントを同じ倍率で育てる (塗り色・アイコン名は各箇所のまま):

```swift
            // #151 提案3: 円とアイコンを同じ倍率 (最大 1.3 倍) で育て、アイコンが円からはみ出さないようにする
            ZStack {
                Circle()
                    .fill(AccessibilityColors.brandSecondary)
                    .decorativeFrame(size: 120)
                    .shadow(radius: 10)

                Image(systemName: "list.clipboard.fill")
                    .decorativeFont(size: 50)
                    .foregroundColor(.white)
            }
```

- [ ] **Step 2: 単独の大きなアイコン 4 箇所を置換**

`RecordTutorialView.swift:150` (`person.2.circle.fill`) / `:269` (`checklist`)、`ChildTutorialView.swift:127` (`person.circle.fill`) は `.font(.system(size: 80))` → `.decorativeFont(size: 80)`。`ChildTutorialView.swift:143` (`checkmark.circle.fill`) は `.font(.system(size: 60))` → `.decorativeFont(size: 60)`。

- [ ] **Step 3: 選択チェックのバッジ (1 箇所) を置換**

`RecordTutorialView.swift:207-212`。60pt 固定のアバター上に載るバッジなので、上限つきで背景円と一緒に育てる:

```swift
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .decorativeFont(size: 14)
                                                            .foregroundColor(.white)
                                                            .background(
                                                                Circle()
                                                                    .fill(Color.green)
                                                                    .decorativeFrame(size: 14)
                                                            )
                                                            .offset(x: 0, y: -1)
```

- [ ] **Step 4: ビルドと残件 grep**

```bash
grep -n -E '\.system\(size: *[0-9]' app/OtetsudaiCoin/Presentation/Views/Tutorial/*.swift
```

Expected: 出力なし (0 件)

```bash
LOG=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad/t3.log
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' > "$LOG" 2>&1; grep -E '\*\* BUILD|error:' "$LOG" | head
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/Tutorial/RecordTutorialView.swift app/OtetsudaiCoin/Presentation/Views/Tutorial/ChildTutorialView.swift
git commit -m "fix(#151): チュートリアルの装飾アイコンを上限 1.3 倍で Dynamic Type に追従させる"
```

---

### Task 4: Splash (コイン + ロゴ)

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/SplashScreenView.swift:43, 59, 63, 79`
- Test: なし (Task 3 と同じ理由)

**Interfaces:**
- Consumes: Task 1 の `.decorativeFont(size:weight:design:)` / `.decorativeFrame(size:)`
- Produces: なし

- [ ] **Step 1: コイン (グロー 200 / コイン 100 / アイコン 32) を同じ倍率へ**

```swift
                        // :43 外側のグロー
                        .decorativeFrame(size: 200)
```

```swift
                        // :59 メインコイン
                        .decorativeFrame(size: 100)
                        .overlay(
                            // コインの中央アイコン
                            Image(systemName: "hands.sparkles")
                                .decorativeFont(size: 32, weight: .semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        )
```

グローの `RadialGradient` の `startRadius: 60` / `endRadius: 120` は固定のまま (最大 1.3 倍でも frame 260 の内側で減衰が終わるだけで、見た目の破綻は無い)。

- [ ] **Step 2: ロゴ「OtetsudaiCoin」を上限つきへ**

```swift
                    // #151 提案3: ロゴ (ワードマーク) 扱いで上限 1.3 倍。上限なしだと AX5 で約 63pt になり
                    // 13 文字の rounded bold が 1 行に収まらない
                    Text("OtetsudaiCoin")
                        .decorativeFont(size: 36, weight: .bold, design: .rounded)
```

- [ ] **Step 3: 全体の残件 grep とビルド**

```bash
grep -rn -E '\.system\(size: *[0-9]' app/OtetsudaiCoin/Presentation
```

Expected: 出力なし (Presentation 配下の数値リテラル指定 0 件。`DecorativeScale.swift` は Utils 配下で、かつ数値リテラルではない)

ビルドは Task 3 Step 4 と同じコマンドで `** BUILD SUCCEEDED **`。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/SplashScreenView.swift
git commit -m "fix(#151): Splash のコインとロゴを上限 1.3 倍で Dynamic Type に追従させる"
```

---

### Task 5: 検証 (unit 全体 + 既定 / AX サイズの before/after 撮影) と PR

**Files:** なし (撮影出力は gitignored の `docs/screenshots/verification/`)

- [ ] **Step 1: unit テスト全体**

```bash
LOG=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad/unit.log
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OtetsudaiCoinTests > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"
```

Expected: `** TEST SUCCEEDED **`。落ちたら `-only-testing:` で単独再実行し、parallel flake か regression かを切り分ける。

- [ ] **Step 2: before 用 worktree を作る**

```bash
SP=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad
git worktree add "$SP/before" origin/main
```

- [ ] **Step 3: 既定サイズと AX 最大サイズで before/after を撮る**

撮影 script と同じ simulator (名前 `iPhone 17 Pro Max`、Booted 優先) を選び、文字サイズを切り替えて 4 回撮る。元の文字サイズは最後に戻す。jq が asdf shim で壊れていたら `/usr/bin/jq` を使う (#96)。

```bash
SP=/private/tmp/claude-501/-Users-shinya-workspace-claude-OtetsudaiCoin/bd5d20d9-bdc2-4094-8755-a0a324cd489e/scratchpad
UDID=$(xcrun simctl list devices available -j | /usr/bin/jq -r '[.devices[][] | select(.name == "iPhone 17 Pro Max" and .isAvailable)] | sort_by(.state != "Booted") | .[0].udid')
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b >/dev/null
ORIG=$(xcrun simctl ui "$UDID" content_size); echo "orig=$ORIG"
for size in large accessibility-extra-extra-extra-large; do
  xcrun simctl ui "$UDID" content_size "$size"
  (cd "$SP/before" && /bin/bash scripts/capture-verification-screenshots.sh --appearance light) > "$SP/cap-before-$size.log" 2>&1
  mkdir -p "$SP/shots/before-$size" && cp "$SP/before/docs/screenshots/verification/light/"*.png "$SP/shots/before-$size/"
  /bin/bash scripts/capture-verification-screenshots.sh --appearance light > "$SP/cap-after-$size.log" 2>&1
  mkdir -p "$SP/shots/after-$size" && cp docs/screenshots/verification/light/*.png "$SP/shots/after-$size/"
done
xcrun simctl ui "$UDID" content_size "$ORIG"
```

撮影 script が別の UDID を選んだ場合 (Booted が無く並びが変わった等) に備え、`cap-*.log` に出る udid が `$UDID` と一致することを grep で確かめる。

- [ ] **Step 4: 一次目視 (assistant が全枚数を Read して所見を表にする)**

見るシーン: `00-splash` (best-effort)、`08-help-history` (空状態アイコン)、`12-tutorial-child`、`13-tutorial-record`。各シーンで before/after × 既定/AX の 4 枚を並べ、次を表に書く:

| 観点 | 期待 |
|---|---|
| 既定サイズ | before と after で見た目が同じ (アイコン・円・ロゴの大きさ) |
| AX 最大 | after のアイコンと円が before より大きい (最大 1.3 倍)、アイコンが円からはみ出していない |
| AX 最大 | 「次へ」ボタンと見出しが after でも画面内にある。before で既に画面外なら、after で悪化していない (別課題として PR に記録) |
| AX 最大 | Splash のロゴが 1 行に収まっている |

所見をまとめたうえで、user に closed 質問で確認する (CLAUDE.md「User 介在の verification step は assistant が一次目視してから」)。

- [ ] **Step 5: 後片付け**

```bash
git worktree remove "$SP/before" --force && git worktree prune
git status --short   # docs/screenshots/verification は gitignored なので何も出ない想定
```

- [ ] **Step 6: 最終 whole-branch レビュー**

inline 実行でも省略しない (CLAUDE.md 2026-08-15 ルール)。`superpowers:requesting-code-review` で branch 全体をレビューし、指摘を反映する。

- [ ] **Step 7: PR 作成**

`git status` で branch を再確認 → `gh pr list --head fix/151-dynamic-type-fixed-fonts` で既存 PR が無いことを確認 → push → `gh pr create`。PR body に含めるもの:
- 対応した epic 項目 (提案3) と 14 件の内訳 (装飾 10 / バッジ 1 / ロゴ 1 → 上限 1.3 倍、操作 2 → `.callout` で上限なし)
- 検証境界: `@ScaledMetric` の配線は unit テスト対象外。clamp は `DecorativeScaleTests`、配線は撮影で確認
- Step 4 の所見表
- 未確認: 記録ありの履歴画面 (✏️ / 🗑) の AX 表示は撮影シーンに無く未目視
- merge 後に #238 の逆方向確認 (この PR は `app/` を変更するので、Xcode Cloud のビルドが開始されることを TestFlight で読む) を行うこと

- [ ] **Step 8: merge 後**

- #151 に進捗コメント (提案3 を done へ。残り: ダークモード1 Splash の背景グラデ / ダークモード3 の `brandSurfaceWarm`・橙の統一 / `focusIndicator` は使用 0 件の未使用トークン)
- #238: ASC (ログイン済みの Chrome、読み取りのみ) で TestFlight 1.1.5 に新しいビルドが始まったことを確認し、コメントして close
