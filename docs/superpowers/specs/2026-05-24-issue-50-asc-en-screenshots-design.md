# Issue #50 Phase 1 § 1.5 — ASC 英語ロケーション用スクショ撮影 Design

- **Issue**: [#50 Phase 1 § 1.5](https://github.com/es0612/OtetsudaiCoin/issues/50)
- **Date**: 2026-05-24
- **Status**: Draft (brainstorming approved by user)
- **Related decisions**: Issue #50 本体に判断結果ログあり (AI draft + spot review / 在外日本人/バイリンガル限定 / ASC 側を先行更新)
- **Related skills**: `[[ios-simulator-locale-testing]]`, `[[ios-simulator-app-verification]]`

## 1. Background

Issue #50 Phase 1 のうち、テキスト系 draft (§ 1.2 説明文 / § 1.3 キーワード / § 1.4 プロモテキスト / § 1.6 What's New) は `RELEASE_v1.1.1_ASC_EN.md` で全て完了済み。`RELEASE_v1.1.1_ASC_EN.md` § 7 ASC paste-in checklist にも `Capture English-locale screenshots and upload — track in a v1.1.x follow-up using [[ios-simulator-locale-testing]]` が **唯一の未完了項目** として残っている。

Phase 1 残作業 = **英語ロケール用スクショ撮影 (§ 1.5)** のみ。本 spec はその scope と実装方針を確定する。

## 2. Scope

### Included

- ASC 英語ロケーション用スクリーンショット 3 枚 (ホーム / 記録 / 設定 tab) を撮影し ASC アップロード可能な状態にする。
- 副産物: 同じ XCUITest function で ja 3 枚も同時取得し、repo 内 reference として保存。将来 ja スクショ更新時のベースとして再利用。
- 画像保存場所の新設: `docs/screenshots/asc/v1.1.x/{ja,en}/`。
- `RELEASE_v1.1.1_ASC_EN.md` § 7 の deferred checkbox 解除 + image path 追記。

### Excluded (別 issue へ)

- v1.1.2 新機能 (一括モード ON 状態 / 重複警告ラベル) の特殊状態スクショ。状態作り込み (重複記録データ pre-set) が要るので別 issue 化。
- `ContentView` の `selectedTab` を `@AppStorage` 化する UX 改修。「最後に見た tab を覚える」が prod 動作になるため UX 判断が要り、本 issue とは独立。
- ASC への画像アップロード操作。Phase 1 § 1.7 (user 手動作業) の範疇。

## 3. Architecture

### Files to add

| Path | Role |
| --- | --- |
| `app/OtetsudaiCoinUITests/ASCScreenshotUITests.swift` | locale loop で 3 tab × 2 locale = 6 枚を撮影する XCUITest class |
| `scripts/capture-asc-screenshots.sh` | `xcodebuild test -only-testing` 実行 → xcresult から PNG 抽出 → リネーム配置するワンショット script |
| `docs/screenshots/asc/v1.1.x/ja/{01-home,02-record,03-settings}.png` | ja 撮影結果 (reference 保存用) |
| `docs/screenshots/asc/v1.1.x/en/{01-home,02-record,03-settings}.png` | en 撮影結果 (ASC アップロード対象) |

### Files to modify

| Path | Change |
| --- | --- |
| `RELEASE_v1.1.1_ASC_EN.md` § 7 | "Capture English-locale screenshots …" の `(Deferred)` を解除し、image path リンク追記 |
| `app/OtetsudaiCoin/TutorialService.swift` 等 (必要なら) | `--uitesting` 起動時に `checkFirstLaunch()` を no-op 化する小修正。実装段階で必要性を判断 |

### Class layout

```swift
final class ASCScreenshotUITests: XCTestCase {
    func testCaptureScreenshots_ja() throws {
        captureScreenshots(language: "ja", locale: "ja_JP")
    }

    func testCaptureScreenshots_en() throws {
        captureScreenshots(language: "en", locale: "en_US")
    }

    private func captureScreenshots(language: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        skipTutorialIfPresent(app: app)

        attach(name: "\(language)-01-home")
        tapTab(app: app, index: 1)
        attach(name: "\(language)-02-record")
        tapTab(app: app, index: 2)
        attach(name: "\(language)-03-settings")
    }

    private func tapTab(app: XCUIApplication, index: Int) {
        app.tabBars.buttons.element(boundBy: index).tap()
        sleep(2)
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Image extraction

`xcrun xcresulttool export attachments --path <xcresult> --output-path <tmp>` (Xcode 16 標準提供) で manifest.json + PNG 群が出る。manifest.json から `attachment.name → file ID` をマップし、`docs/screenshots/asc/v1.1.x/{ja,en}/{01-home,02-record,03-settings}.png` 形式にリネームして配置する shell script を書く。

### Key implementation notes

1. **TutorialService の skip**: 既存 `--uitesting` でサンプル子供 (太郎 / 花子) は pre-set されるが、`TutorialContainerView` の表示自体は skip されていない可能性あり。実装時に確認し、必要なら `--uitesting` で `TutorialService.checkFirstLaunch()` を no-op にする 1〜2 行修正を含める。既存 `OtetsudaiCoinUITests.skipTutorialIfPresent` は ja button name (「次へ」「完了」等) で hardcoded なので en 時には動かない。
2. **Tab 切替は `element(boundBy: index)`**: button label が locale で変わるため `app.tabBars.buttons["ホーム"]` のような名前指定は使えない。位置参照で language-agnostic にする。
3. **Simulator は iPhone 17 Pro Max (6.7-inch)**: ASC の最大サイズ要件に対応する device で撮影する。`-destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`。
4. **Splash screen のスキップ待ち**: `app.launch()` 後 splash screen が 1〜2 秒表示されるので、ホーム撮影前にも `sleep(2)` 程度入れる (上記コード内で `skipTutorialIfPresent` 後に追加する)。

## 4. Test strategy

### CI 取り扱い

- 同じ test target (`OtetsudaiCoinUITests`) に同居。class 名で分離 (`ASCScreenshotUITests`) し、撮影 script は `-only-testing:OtetsudaiCoinUITests/ASCScreenshotUITests` で個別実行する。
- 通常 CI 全件実行時にも走るが、副作用は xcresult attachments 追加のみで failure にはならない。CI 時間影響は test 2 件 × ~30 秒 ≈ 1 分追加の見込みで許容範囲。
- 必要なら将来 `.xctestplan` で分離するが、初版では入れない (YAGNI)。

### TDD application

- スクショ撮影 test は「artifact 生成」用途で、伝統的 red/green の対象外。
- verification は `scripts/capture-asc-screenshots.sh` の完走と、出力 6 枚の目視確認 (en tab label が `Home / Record / Settings` になっていること等)。
- TutorialService 修正など app コード側の変更が必要になった場合は、その箇所のみ red/green 適用 (`xcodebuild test` で confirm)。

### Success criteria (PR review)

1. `scripts/capture-asc-screenshots.sh` が green で完走。
2. `docs/screenshots/asc/v1.1.x/{ja,en}/01-home.png` 等 6 枚が正しく配置。
3. en 3 枚で tab label が `Home / Record / Settings` 表示になっている (目視)。
4. `RELEASE_v1.1.1_ASC_EN.md` § 7 deferred checkbox 解除 + image link 追加。
5. PR description に ja/en home スクショを inline 表示 (verification 証拠)。

## 5. PR structure

### Title

```
docs(#50): ASC 英語ロケーション用スクショ撮影 (Phase 1.5)
```

### Branch

`docs/issue-50-asc-en-localization-phase1` (本 spec 作成時に切り替え済み)

### Commit plan

1. `ASCScreenshotUITests.swift` 追加 (locale loop + tab tap + attachment)
2. `scripts/capture-asc-screenshots.sh` 追加 (xcodebuild test + xcresulttool export + rename)
3. (必要なら) `TutorialService.swift` 等の `--uitesting` skip 対応 1〜2 行
4. 生成スクショ 6 枚を `docs/screenshots/asc/v1.1.x/{ja,en}/` に追加
5. `RELEASE_v1.1.1_ASC_EN.md` § 7 deferred checkbox 解除 + image link 追記

### Hand-off after merge

- `RELEASE_v1.1.1_ASC_EN.md` § 7 残項目 (ASC ロケ追加 / paste / 保存) を user が手動実行 (#50 § 1.1, 1.2〜1.6, 1.7)。
- 完了後 #50 close (Phase 1 完了)。Phase 2 (v1.1.2 以降の What's New 英訳組み込み) は `RELEASE_v1.1.2.md` § 2.5 で先行実装済みのため、Phase 2 自体は close 時点で完了扱い。

## 6. Out-of-scope / future work

| Topic | Where |
| --- | --- |
| 一括モード ON / 重複警告ラベルの ja/en スクショ更新 | 別 issue (#50 sister)。RELEASE_v1.1.2.md § 1.4 で撮り直しが「◎」と言及されているが、状態作り込みが必要 |
| `selectedTab` の `@AppStorage` 化 (UX 改善) | 別 issue。「最後の tab を覚える」が prod 動作変更になり、UX 判断が要る |
| 全 5.5-inch / 6.1-inch サイズも撮影 | 別 issue。ASC は 6.7-inch 必須 + 他サイズは流用可能 (Apple 仕様) なので初版は 6.7-inch のみ |
| `release-version-bump-check` / `release-retrospective` skill との連携 | 既に v1.1.2 リリースで Phase 2 が実装済み。本 issue では触らない |

## 7. Risks / known unknowns

| Risk | Mitigation |
| --- | --- |
| `xcresulttool export attachments` の manifest.json フォーマットが想定と異なる | 実装初手で `xcrun xcresulttool export attachments --help` と実際の出力構造を確認してから shell script を書く |
| TutorialContainerView が `--uitesting` で skip されず、ホーム到達できない | 既存 `OtetsudaiCoinUITests.testHappyPath_TabNavigation` が green であることを確認し、同じ前提が成立するか check。skip されない場合は `--uitesting` で `TutorialService.checkFirstLaunch()` を no-op 化する小修正を入れる |
| Simulator 上で en locale が反映されない (skill SKILL.md にある common mistakes) | `terminate` 前提 / `'(en)'` の literal parens / launch arg 順序を守る |
| 既存 XCUITest が flaky で en run だけ落ちる | CLAUDE.md「iOS テスト flake 切り分け」に従い `-only-testing` で isolated 再実行して flake 切り分け |
