---
name: writing-swiftui-view-tests
description: Use when writing or fixing SwiftUI View tests or XCUITests in OtetsudaiCoin — choosing between ViewInspector and XCUITest, or when ViewInspector fails with "Search did not find a match. Possible blockers: BannerAdView, Material, AccessibilityImageLabel", find(viewWithAccessibilityIdentifier:) finds nothing on iOS 26, accessibilityLabel() throws "EmptyView does not have 'accessibilityLabel' modifier", an XCUITest tap or waitForExistence does nothing (Toggle, off-screen List/LazyVGrid rows at AX sizes), or view logic depends on gestures or environment values (@Environment).
---

# OtetsudaiCoin の SwiftUI View テスト

## Overview

このリポの View テストは ViewInspector 0.10.2 と XCUITest の 2 本立て。iOS 26 SDK では ViewInspector が accessibility 系の modifier (identifier / label) を読めないため、**表示は `findAll` で、読み上げと操作は XCUITest で**確かめる。テストしにくい判定は、View の外の pure 関数へ出す。

もとは CLAUDE.md の「SwiftUI View テスト戦略」節 (#233 で移した)。

## Quick Reference

| 確かめたいこと | 使うもの |
| --- | --- |
| 表示される文字列 | `findAll(ViewType.Text.self)` + 兄弟の除外 + 観測値を assert message に出す |
| 図形の有無・色 | `findAll(ViewType.Shape.self)` + `fillShapeStyle(Color.self)` を定数参照と比較 |
| Button の状態 | `findAll(ViewType.Button.self)` を表示 Text で絞って `isDisabled()` / `tap()` |
| Image のフォント | `InspectableView.font()` (Text は `attributes().font()`) |
| 読み上げ文 (accessibilityLabel) | XCUITest の `element.label` + mutation で検出力を確認 |
| accessibilityIdentifier で探す | ViewInspector では使わない (iOS 26 で 0 件)。XCUITest では使える |
| gesture / 環境値で分かれる見た目 | 判定を static pure helper に出してテスト、配線だけテスト外 |
| Toggle を押す | 行ではなく右端のスイッチを座標で押す |
| AX サイズで画面外の要素 | スクロールで寄せてから待つ |

## ViewInspector の制約と回避

- ViewInspector は NavigationStack + ZStack + UIViewRepresentable (BannerAdView) + Material の組み合わせを深く traverse できない既知制約がある。`find(viewWithAccessibilityIdentifier:)` / `find(text:)` / `find(ViewType.X.self)` いずれも該当 view へ到達不可、`"Search did not find a match. Possible blockers: BannerAdView, Material, AccessibilityImageLabel"` で fail する。
- 上記が予想される View では UI 構造の structural test を強行せず、(a) ViewModel テストでロジック網羅 + (b) View の smoke test (init crash なし) + (c) behavior test (toggle/binding が ViewModel state を動かすこと) で間接担保、UI の最終 visual は simulator 手動 / UI test に委ねる。
- 該当 View の refactor を入れるなら BannerAdView を component 分離 / Material 依存を Color 系に置換 する方向で別 issue 化する (例: #74)。
- **`AccessibilityImageLabel` blocker** (`Image(systemName:)` + `.foregroundColor` の組み合わせ): `find(viewWithAccessibilityIdentifier:)` は AccessibilityImageLabel が 1 つでもあると該当 button へ到達できない。回避策は `find(ViewType.Button.self)` 経由で button 自体を掴み `try button.isDisabled()` などで state を確認する。accessibilityIdentifier 経由の指定を諦めるトレードオフだが、Button が 1 つしか無い component なら structural test として十分機能する。
- **Text 内容の検証は `findAll(ViewType.Text.self)` で blocker を跨ぐ** (#106 PR #109 で確立): 上の `find(ViewType.Button.self)` は button **state** (isDisabled 等) 用。Text の**表示文字列**を読みたい場合、`find(viewWithAccessibilityIdentifier:)` / `find(ViewType.Text.self)` は AccessibilityImageLabel blocker で到達不可だが、**`findAll(ViewType.Text.self)` は blocker を跨いで到達可能な Text を全列挙できる** (ローカル実行で確認済み)。判定時の罠: 数字の有無を `contains("1")` だけで見ると、ローカライズされない兄弟 Text (例 `coinInfo` の `"10コイン"`) が "1" を含み、対象 row が不在でも通る false positive になる → 衝突する兄弟を `!hasSuffix("コイン")` 等で除外してから数字一致を見る。`String(localized:)` を test 側で再計算して exact match する案は test-bundle/locale 解決に過結合する (app-host & 同 locale でしか一致しない) ので、**数字一致 + 兄弟除外**の方が頑健。
- **未検証の traversal/lookup 機構に PASS が依存するテストは、assertion message に観測値を dump する** (#106 で確立): 「`findAll(ViewType.Text.self)` が本当に blocker を跨げるか」のように、テストの green が**まだ実証されていないライブラリ挙動**に依存する場合、`XCTAssertTrue(..., "rendered: \(texts)")` の形で実際に描画された値を失敗メッセージに含める。こうすると将来 red になったとき「機構が到達できなかった / 対象要素が描画されなかった / 述語ロジックがずれた」のどれが原因かを再実行なしで切り分けられる。advisor が #106 で指摘し、未検証の前提 (findAll が blocker を越える) を安全に検証できた起点。
- **Component 分離による blocker 回避** (#74 で確立した path): `RecordView` の `recordButtonView` を `RecordButtonBar` (`Presentation/Components/`) に切り出し、component 単独で View test を書く形を取った。親 View 側に NavigationStack + ScrollView + UIViewRepresentable の組み合わせが残っていても、component test はそれらの影響を受けない。BannerAdView の位置を維持しつつ structural test を確保したいケースで有効。
- **ViewInspector 0.10.2 + iOS 26 SDK で `find(viewWithAccessibilityIdentifier:)` が systematic に効かない回帰** (#84 PR #118 で確認): `Image(systemName:)` blocker が無くても、`ForEach` 外の素の Button ですら accessibilityIdentifier 解決が 0 件になる (`v3v4AccessibilityProperties` の reflection が iOS 26 SwiftUI 内部構造に解決しない)。回避策: (a) Button の **state** (`isDisabled`/`tap`) は `findAll(ViewType.Button.self)` を取得し**表示 Text** (例: day 番号 `"10"`、nav 矢印 `‹`/`›`) でフィルタして掴む、(b) **図形の有無/色** (記録ドット・選択リング等) は `findAll(ViewType.Shape.self)` + `fillShapeStyle(Color.self)` で `AccessibilityColors.successGreen` / `primaryBlue` と**定数参照で等価比較** (hex リテラル直書きは避ける)。識別子設計に依存するテストは iOS 26 simulator で red になるため、**新規 component test は最初から findAll ベース**で書く。`Image(systemName:)` を component から排除すれば `AccessibilityImageLabel` blocker も同時に消えるので、矢印等は Text にする (#84 RecordCalendarView の設計)。なお `findAll(ViewType.Shape.self)` のような未実証 traversal に PASS が依存する場合は上記 #106 ルール通り assertion message に観測値 (fills / button 数) を dump する。
- **`findAll(Text/Shape)` は custom subview の境界を跨いで traverse できる** (2026-08-23 #200 PR #204 で実証、iOS 26 + ViewInspector 0.10.2): TaskCardView の taskIcon を `TaskIconView` component へ抽出した後も、親 View への `findAll(ViewType.Text.self)` / `findAll(ViewType.Shape.self)` は component 内部の Text / Shape まで到達し、既存の親テストが無変更で green を維持した (抽出直後に親テスト単独実行で実証ゲートを通す手順も同 PR で確立)。component 抽出 refactor の plan では「親テストが壊れる前提の fallback 設計」を必須にしなくてよいが、**抽出直後に親テストを単独実行して実証ゲートを踏む**手順は残す (ViewInspector のバージョン更新で挙動が変わりうるため)。
- **ViewInspector 0.10.2 + iOS 26 では `accessibilityLabel()` も読めない** (2026-11-08 #280 PR #295): `Text(...).accessibilityLabel(...)` に対して `text.accessibilityLabel().string()` は `EmptyView does not have 'accessibilityLabel' modifier` を投げる (identifier の回帰と同じ種類)。読み上げ文は XCUITest で accessibility ツリーから読む (`app.staticTexts["<identifier>"].label`)。その assert に検出力があるかは、`.accessibilityLabel` を一時的に外す mutation で FAIL → 戻して GREEN を確かめる (#295 では `'1'` と読まれて FAIL)
- **`InspectableView.font()` は iOS 26 の `Image` でも読める** (2026-10-11 #151 提案3 PR #247): `.callout` と `.system(size:)` を区別できることを mutation で確認済み。Text は `attributes().font()` を使う。Image のフォントの回帰テストが書ける

## テストしやすい View の作り方

- **絵文字 / 可変サイズ Text のアイコンは固定 frame + `.overlay` / `.background` に入れず、ZStack + 別 frame の図形 + 非拘束 Text で組む** (2026-08-15 #177 PR #198 review で確立): `Text` は width 提案に従って truncate する (旧 `Image(systemName:)` は overflow するだけで消えなかった) ため、`.font(.title3)` 等のスケーリングフォントを固定 44pt 円の overlay や 32pt frame + background に入れると AX サイズの Dynamic Type で絵文字が切れる。TaskCardView の taskIcon (`ZStack { Circle().frame(...); Text(...).accessibilityHidden(true) }`) が参照パターンで、#198 で HelpRecordRow / TaskSelectionRow を同型へ統一済み。列揃え目的の固定幅は `.frame(width:)` でなく `.frame(minWidth:)` にする (TaskRowView)。
- **gesture / interaction closure 内の判定ロジックは pure 関数抽出でテスト可能にする** (#125 PR #127 で確立): View の gesture closure に埋め込まれた判定ロジック (スワイプ方向 → 次月/前月の mapping 等) は「ViewInspector で gesture を simulate できないから unit-test 範囲外」と即断しない。判定部分を ViewModel の pure 関数 (例 `handleHorizontalSwipe(translationWidth:)`) へ **buggy 方向のまま抽出する pure refactor → RED → 反転して GREEN** の順で進め、残る gesture plumbing (DragGesture → 関数呼び出しの配線) だけを untested にするのが正しい境界。特に date-nav (次月/前月) は本リポの反復弱点 (#112/#114/#115) なので、方向 mapping のテストは安価で高シグナル。「コード読み + 目視で間接担保」は逃げになりやすく、抽出すれば決定的にテストできる。
- **`@Environment(\.isEnabled)` など環境値駆動の見た目分岐は判定を static pure helper へ切り出す** (2026-08-08 #175 PR #189 で確立): ViewInspector は環境値を注入できないため、`@Environment(\.isEnabled)` を読んで色を決める `ButtonStyle` の分岐はそのままではテスト不能。上記 #125 の gesture pure-関数抽出と同じ要領で、判定部分を `SolidButtonStyle.background(for:isEnabled:)` (`Presentation/Views/Components/AppButtonStyle.swift:36`) のような static pure helper へ抽出し、**環境値の配線だけを untested に残す**のが正しい境界。「環境値だからテスト範囲外」と即断しない。

## XCUITest

- **XCUITest で `Toggle` を操作するときは「行」ではなく「スイッチ本体」を叩く** (2026-07-28 PR #183 で確立、#182 と合わせ**2 セッション連続で踏んだ**): `app.switches` は 1 つの `Toggle` につき **2 要素**を返す。(a) ラベル付きの**行**全体 (例 `label='効果音'`, `frame=(20, 746, 400, 52)`)、(b) ラベル無しの**スイッチ本体** (`frame=(339, 758, 63, 28)` = 行の右端)。`XCUIElement.tap()` は要素の**中心**を叩くため、`app.switches.element(boundBy: 0).tap()` は x≈220 の「ラベル文字の上」を押すことになり **List 上では値が変わらない**。`exists`/`isHittable` は true、`tap()` も throw しないので、**「タップは届いたのに値が変わらない」= 実装バグ**に見える。対処: 値の読み取りは行要素 (`element(boundBy:)` で locale 非依存) のまま、**タップだけ `row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()` で右端を狙う**。`element(boundBy: 2)` でスイッチ本体を直接掴む手もあるが、ツリーの形に依存するので座標指定の方が壊れにくい。**診断の型**: 症状が同じなので、原因を推測で decide せず `app.switches.count` と各要素の `label` / `frame` / `isHittable` を dump して切り分ける (print は xcodebuild の stdout に出ないので、**診断値を意図的な `XCTFail` のメッセージに載せて `xcrun xcresulttool get test-results tests` で回収**する)。PR #182 はこの罠でトグルの検証を諦め「⚠️ 未検証」のまま merge し、次セッションでも同じ罠で一度「実バグ」と誤判定した (実装は正常だった)。
- **AX サイズでは、画面外の `List` の行や `LazyVGrid` のカードが accessibility ツリーに出ない** (#261 / #265 / 2026-11-08 #280): `exists` / `isHittable` が false になり、`waitForExistence` は対象が画面外にある限り届かない。待つ前に、対象を見える範囲までスクロールする helper (`VerificationScreenshotUITests` の `revealButton` / `bringCardIntoWindow`) で寄せる。記録などの操作の後に画面が一番上へ戻ることもある (#280 の記録タブ)。要素が無い・タップが効かないときは、実装バグと決める前に要素の有無・`frame`・`isHittable` を dump する (上の Toggle と同じ診断の型)
- **撮影テスト・UI テストを足したら、既定サイズと AX 最大の両方で流してから「通った」と言う** (2026-11-08 #280): 既定サイズで通った `testCaptureRecordCountRow` が AX 最大では上の理由で落ちた。2 列のまま文字が一番大きい xxxLarge (AX ではない最大) も、レイアウトには一番きつい条件になる。条件の切り替えは `scripts/capture-verification-screenshots.sh --content-size <category>` で行う (手で `simctl ui` を叩くと、shutdown 中の端末では効かない)
