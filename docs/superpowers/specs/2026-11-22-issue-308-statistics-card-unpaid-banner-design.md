# #308 PR 1 集計カードと未払いバナーの英語表示 — 設計（短い版）

ステータス: in-progress（設計はオーナー承認済み 2026-11-22。ブランチ fix/308-statistics-card-unpaid-banner）

## 目的

US ストアで公開中の 1.1.6 で、英語表示なのに日本語のまま出る文言と、未払いバナーの誤りを 1.1.7 で直す（#308 は P1）。この PR は #308 の §1 のうち集計カード、§2、§3 を扱う。チュートリアル（§1 の残り）は PR 2。

## ゴール / 非ゴール / アンチゴール

- ゴール
  - `StatisticsCard`（ホーム 2 枚・履歴 3 枚）の見出しと単位が、en で英語になる
  - 未払いバナーの期間で、同じ年月が 1 回だけ出る
  - 未払いバナーの案内文が、実際の行き先（月のまとめ）を指す（ja / en とも）
- 非ゴール: 金額の単位（¥ / コイン）の統一（#155）。`Text(String変数)` を検出する lint（#306）。AX サイズで文字が切れる件（#151）。数が 1 のときの英語の単数形
- アンチゴール: ja の表示が変わる（案内文の書き直しを除く）

## アプローチ

| 案 | 内容 | 判断 |
| --- | --- | --- |
| (a)（採用・オーナー決定） | `StatisticsCard` の `title` / `subtitle` を `LocalizedStringKey` にする。呼び出し側のリテラルはそのまま | 呼び出し 5 か所を変えずに翻訳が効く |
| 呼び出し側で `String(localized:)` | 5 か所すべてに書く | 書き忘れが再発しやすい |
| 数を渡して複数形の訳を引く | 部品の形を変える | 範囲が広がる（オーナー確認で見送り） |

## 決めたこと

1. `StatisticsCard.title` / `subtitle` を `LocalizedStringKey` にする
2. en の訳を足す（Claude の判断。数に左右されない言い回し）: 「コイン獲得！」→ `coins earned!`、「日連続！」→ `day streak!`、「コイン/回」→ `coins per chore`
3. 案内文を書き直す。古いキー 2 つは消す
   - ja: `%@の未支払いのお小遣いが%lldコインあります。月のまとめから支払えます。` / `%lld人の子供に未支払いのお小遣いが合計%lldコインあります。月のまとめから支払えます。`
   - en: `%@ has %lld coins of unpaid allowance. You can pay from the Monthly Summary.` / `%lld children have unpaid allowances totaling %lld coins. You can pay from the Monthly Summary.`（「Monthly Summary」は既存の「月のまとめ」の訳に揃える）
4. `HomeViewModel.unpaidPeriodsText` で年月の重複を除き、新しい順に並べる

## 物差し

- en で撮ったホーム（06・31・32）と記録のある履歴（33）に、日本語の文言が 0 件（子どもの名前を除く）
- 32（未払い 2 人）の期間が「October 2026, September 2026」の 2 つだけ
- ja の 06・33 は before と見た目が同じ。31・32 は案内文と期間だけが変わる

## builder に任せること

- テストの置き場所（`StatisticsCard` のテストは今は無い）
- xcstrings の編集方法（`xcstrings-bulk-update` skill に従う）
