---
name: running-xcodebuild-tests-and-date-fixtures
description: Use when running or judging `xcodebuild test` results in OtetsudaiCoin — the tail of the log shows no `** TEST SUCCEEDED **` / `** TEST FAILED **` line, a background run reports exit 0, a grep count of "failed" looks wrong, a test fails only in parallel runs or intermittently, or measuring the effect of a build-setting change on warnings — and when writing or fixing tests whose fixtures depend on today's date, month or year boundaries (start of month, December to January), or a service that reads `Date()` internally — including when implementing calendar or month-navigation features, which need a year-boundary test.
---

# OtetsudaiCoin のテストの流し方と、日付に依存する fixture

## Overview

`xcodebuild test` の成否は**判定行 (`** TEST …`) とログで読む**。末尾の数行や、harness が報告する exit code では判断しない。落ちたテストは、regression と決める前に単独で流し直し、間欠的なら再現率を測る。日付を使う fixture は、このリポで何度も flake を生んだ (#112 / #114 / #115) ので、実行日に依存しない形で書く。

もとは CLAUDE.md の「iOS テスト flake 切り分け」節 (#233 で移した)。Swift Testing (`@Test`) の落とし穴はグローバル skill `xcodebuild-swift-testing` にある (このリポは XCTest)。

## Quick Reference

| 場面 | すること |
| --- | --- |
| 結果の判定 | ログをファイルに保存し、`grep -E -A6` で判定行と `Failing tests:` を抜き出す (下の推奨形) |
| background 実行の完了 | harness の exit ではなく、ログの `exit=` 行と判定行を読む |
| 失敗の詳細 | `xcrun xcresulttool get test-results tests --path <xcresult>` |
| テストの件数 | `xcrun xcresulttool get test-results summary --path <xcresult>` (grep で数えない) |
| 落ちたテスト | `-only-testing:` で単独に流す → 通れば並列実行の flake |
| 間欠的な失敗 | wait を足す前に N 回流して再現率を測る |
| ビルド設定の影響 | 専用 `-derivedDataPath` の clean build で、設定なしとの差分を取る |
| 相対日付の fixture | 当月 15 日に固定する。RED は月初 1〜5 日で確かめる |
| 年境界のナビ | 起点を「前年 12 月」に固定する |
| `Date()` を内部で読むサービス | 実際の当月初 / 前年 12 月にアンカーし、「前進」を assert する |

## テストの流し方と判定

- **`xcodebuild test` の結果判定は `| tail -N` ではなく `grep -E '\*\* TEST'` で判定行を直接抽出する** (2026-07-20 PR #179 検証時に確立): unit 全体のような大きい suite では、成功時も末尾がテストケース行 (`Test case ... passed`) で埋まり `tail -15` に `** TEST SUCCEEDED **` が入らないことがある。判定行が見えず再実行する無駄 (フルスイート 1 回分) が出るので、最初から `xcodebuild test ... 2>&1 | grep -E "\*\* TEST|Failing tests" | tail -5` の形で判定文言を抽出する。個別 `-only-testing:` のような小さい実行では `tail -20` でも届くが、統一しておくと安全。**`-A6` を必ず付ける** (2026-08-08 PR #189 検証時に補強): 失敗テスト名は `Failing tests:` の**次行以降**に出るため、`-A` 無しの grep では「FAILED とだけ分かって名前が取れず、名前を取るためだけにフルスイートをもう 1 回回す」無駄が出る (実際に発生)。推奨形: `xcodebuild test ... > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` — ログをファイル保存しておけば再実行なしで任意の詳細を掘れる。
- **background で `xcodebuild test` を chain 実行したら、報告される完了 exit code を鵜呑みにしない**: `xcodebuild ... > log 2>&1; echo "exit=$?"` を background 実行すると、harness が報告する**完了 exit は chain 末尾の `echo` の 0** になり、xcodebuild の real exit (65 = `** TEST FAILED **`) を隠す。「exit 0」通知を信じて緑判定すると失敗を見逃す。必ず log 末尾の `exit=` 行を `grep "^exit="` で読むか、`grep -F "** TEST FAILED"` / `Failing tests:` で結果を確認してから判定する。なお `find(viewWithAccessibilityIdentifier:)` 系の失敗詳細はストリーム log に出ないことがあるので、`.xcresult` を `xcrun xcresulttool get test-results tests --path <xcresult>` で開いて failure message を取る (`AccessibilityImageLabel` blocker 等の真因はここでしか見えない)。
- 並列 simulator run で UI テスト・load 系テストが flaky に落ちることがある。regression と断定する前に該当テストを `xcodebuild test -only-testing:` で isolated 再実行し、PASS すれば parallel flake として扱う（本修正と無関係な既知問題として切り分け可能）。
- **ビルド設定変更 (warning 系フラグ等) の影響計測は、専用 `-derivedDataPath` の clean build で行う** (2026-08-13 #154 PR #197 で確立): `SWIFT_STRICT_CONCURRENCY=targeted` の影響を測ろうと通常の `xcodebuild build` を流したら **warning 1 件 (無関係な AppIntents note のみ)** で「影響ゼロ」と誤判定しかけた。直前のテスト実行でモジュールがキャッシュ済みだと Swift ファイルが再コンパイルされず、**新しい警告フラグが一切適用されない**。正しい手順: (a) `xcodebuild build-for-testing ... -derivedDataPath <scratch>/dd-<条件名>` で条件ごとに**まっさらな DerivedData** を使い (テストターゲットまで含めて計測できる)、(b) 設定なしの baseline も同じ方法で取り、(c) `comm -13 <(sort baseline) <(sort after)` で**差分だけ**を抽出する。実測では baseline 16 件 → targeted 25 件 (新規 9 件 = 実質 3 箇所) と判明した。pbxproj へ書いた設定が全ターゲットへ効いているかは `xcodebuild -target <各ターゲット> -showBuildSettings | grep <設定名>` で個別確認する (project レベルに 1 度書けば継承されるが、確認は 3 ターゲット分行う)。
- **件数は grep で数えず、xcresult の summary で読む** (#233、2026-10 に 3 回): `grep -c "Test case .*failed"` はテスト名に `failed` を含む**通過**テスト (例 `test_recordBulkHelp_partialFailure_failedRemain`) まで数える。行の形も実行のしかたで変わる (並列: `Test case '<Class>.<test>()' passed on '<device>'`、並列なし (`-parallel-testing-enabled NO` や UI テスト): `Test Case '-[<Target>.<Class> <test>]' failed (34.093 seconds).`)。さらに並列の clone の出力が混ざって行頭が欠けることがある (#264 の merge 後に grep で 557 件、summary では 558 件)。合否は上の `** TEST` / `Failing tests:` 行で判定し、件数が要るときは `xcrun xcresulttool get test-results summary --path <xcresult>` の `totalTestCount` / `passedTests` / `failedTests` を読む。zsh では `--include=*.swift` などのグロブをクォートする
- **間欠的な失敗は、wait や retry を足す前に同じ条件で N 回流して再現率を測る** (#265): 再現が 0/N なら wait を足さず、回数と条件を issue に書いて `validating` のまま残す。推測で wait を足すと、原因が分からないまま「直った」ように見える。#265 は 6 回流して再現 0 だったため、wait を足さずに済んだ

## 日付に依存する fixture

- **相対日付 fixture (`now ± N日`) は月初/年初に決定的 flake を生む → 固定安全日にピン留めする**: テストで `calendar.date(byAdding: .day, value: -5, to: now)` のような相対日付で fixture を作ると、実行日が月初 1〜5 日のとき `now - 5日` が**前月**へ回り込み、当月フィルタ系テスト (`filterForChildInCurrentMonth` 等) が期待件数とずれて**毎月決定的に fail** する (#112)。プロダクトコードは正常で **test 側の前提が誤り**。修正は当月内の固定日 (例 day 15 = 全月に存在し、year boundary も `isDate(equalTo:toGranularity:.month)` 比較で安全) にピン留めして実行日非依存にする。**RED 確認は再現窓 (月初 day 1〜5) に当たる日付で行う** — 安全日 (月の半ば) で `xcodebuild test` すると RED が再現せず「直したつもり」を見逃す (PR #114 は today=6-02 = day 2 で RED 観測)。test-only かつ低優先なら injected clock (プロダクト API 変更) はスコープ過剰、test 1 ファイルの固定日クランプで決定性を担保できる (PR #114)。
- **カレンダー / 月ナビ系の機能を実装したら年境界 (Dec↔Jan) を跨ぐ nav テストを必ず1件足す。起点は「前年12月」固定にする**: date math はこのリポの反復弱点 (#112/#114/#115) で、年境界テストは安価かつ高シグナルな予防線 (#57 では plan に追加)。ただし year-boundary nav テストの起点を「today から直近の12月へ遡る」方式にすると、**12月に実行した日だけ起点=当月になり `goToNextMonth` の未来月ガード (`candidate > currentMonthStart`) で Jan へ進めず、test 自身が決定的に flake る** (#112/#114 と同根の run-date 依存)。起点は `DateComponents(year: currentYear-1, month: 12, day: 1)` (前年12月) に固定すると、次月=今年1月が必ず現在月以下になり future-guard を通過して実行日非依存になる (assert は `month==1, year==currentYear`)。#57 plan の naive 版 December flake を advisor が catch した起点。
- **内部で `Date()` を直接読む (`now` 注入不可の) サービスの月境界テストは、fixture を「実際の当月初 / 前年12月」にアンカーし、月上限ではなく「前進」を assert する** (#153 PR #158): `MonthlyResetService.checkAndPerformMonthlyReset()` は production が `let now = Date()` を内部で読むため、上記「相対日付ピン留め」ルール (#112/#114/#115) の naive 版 (テストが `now` を選ぶ前提) が使えない。手順: (a) fixture を production と同じ方法で導出した `currentMonthStart` や `DateComponents(year: currentYear-1, month: 12, day: 15)` にアンカーして実行日非依存にする、(b) 更新判定は `XCTAssertGreaterThan(stored, pastAnchor)` (前進) で行い `stored < nextMonthStart` 等の**月上限 assert は避ける** (テストの `Date()` と production の `Date()` が月末 midnight を straddle すると落ちる)、(c) `now` を **`await` の前に確定**して `currentMonthStart` を導出すれば `stored (= production now) >= currentMonthStart` が rollover 越えでも成立、(d) test-only 低優先なら clock 注入 (プロダクト API 変更) は scope 過剰。相補的な same-month=不変 / previous-month=前進 の対で vacuous pass を排除し、characterization では「reset が発火したこと」も明示 assert する (削除0件だけ見ると reset 未発火でも green になる罠)。二段レビューが (b)(c) の straddle と「発火未検証の vacuous test」を catch した起点。
