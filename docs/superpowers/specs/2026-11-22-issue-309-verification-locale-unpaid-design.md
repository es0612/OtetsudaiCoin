# #309 検証撮影 script で en と未払いバナーを撮る — 設計（短い版）

ステータス: idea（設計はオーナー承認済み 2026-11-22。実装は未着手）

## 目的

#308（英語表示で String を受け取る部品が翻訳されない・未払いの月の重複・案内文）の確認を、作業ツリーだけの一時 UITest を組まずに `scripts/capture-verification-screenshots.sh` の 1 コマンドで撮れるようにする。PR #305（#301）の目視では一時変更を 2 つ組み、#308 でももう一度必要になる。

## ゴール / 非ゴール / アンチゴール

- ゴール: `--locale en` で全シーンを英語表示で撮れる。未払いバナー（子ども 1 人・2 人）と履歴の空状態を一時変更なしで撮れる
- 非ゴール: ASC 用の `capture-asc-screenshots.sh` / `ASCScreenshotUITests` は触らない。#308 の不具合そのものは直さない（撮るだけ）
- アンチゴール: 既定（ja・引数なし）の出力が変わる（シーン数・ファイル名・出力パス）。検証用のデータが永続ストアに残る

## 物差し

- #308 の確認（en のホーム子ども選択後・履歴・チュートリアル・未払いバナー 2 人）を、一時変更なしで script 1 コマンドで撮れる
- 既定（ja）の出力が、変更前と比べて新シーン 31〜33 の追加以外は同じシーン数・同じファイル名

## アプローチ

| 案 | 内容 | 判断 |
| --- | --- | --- |
| A（採用） | script が `TEST_RUNNER_VERIFY_LOCALE=<ja/en>` を付けて xcodebuild を流し、UITest が `ProcessInfo.processInfo.environment["VERIFY_LOCALE"]` で起動引数の言語を切り替える | テストを 1 本のまま外から条件を切り替えられる |
| B | 言語ごとに UITest クラスを分ける | 14 テストの重複になる |
| C | script が起動引数を書き換える | xcodebuild から UITest の `launchArguments` へ渡す口がない |

## 決めたこと

1. **script**: `--locale ja|en|both`（既定 ja）。appearance のループの内側に locale のループを置く。出力先は ja が今のまま `docs/screenshots/verification/<appearance>/`、en が `docs/screenshots/verification/en/<appearance>/`（ja のフォルダの中に入れ子にしない。Claude の判断）。`capture-meta.txt` に locale を書く
2. **UITest**: 3 つの起動ヘルパー（`launchMainApp` / `launchTutorialApp` / `launchTutorialAppWithChildren`）の `-AppleLanguages` / `-AppleLocale` を 1 か所の helper から引く。環境変数が無いときは ja（今と同じ）
3. **アプリ（`#if DEBUG`）**: 起動引数 `--seed-unpaid-records 1|2`。`--in-memory-store` と一緒のときだけ効く。`ContentView.setupInitialData()` のデフォルトタスク作成の後で（記録にお手伝いの ID が要るため。子どもの作成はそれより前）、先頭 1 人（または 2 人）に先月と 2 か月前の記録を 3 件ずつ保存し、`notifyHelpRecordUpdated()` を呼ぶ。判定は testable な static helper にする（`shouldSeedSampleChildren` と同じ形）
4. **シーン**: `verify-31-home-unpaid-one`（1 人）、`verify-32-home-unpaid-two`（2 人。#308 §2 の月の重複が写る）、`verify-33-history-empty`（履歴で「今週」をタップした空状態）
5. en でも全シーンを撮る（#308 の 2 本目のチュートリアルでも使う）

## 分かった前提

- `MonthlyResetService.checkAndPerformMonthlyReset()` は日付を更新するだけで記録を消さない（`:37`）。#309 本文の「月末リセットの後に置かないと消える恐れ」は当てはまらないので、投入の位置に順番の制約はない
- 未払いの検出（`UnpaidAllowanceDetectorService`）は今月を飛ばすので、記録は先月以前に置く

## builder に任せること

- 記録に使うお手伝い（デフォルトタスクのどれか）と日付の具体値（月の境界を避けて 10 日など）
- 履歴の「今週」セグメントのタップ方法（ja/en で文言が違うので identifier か位置で引く）
