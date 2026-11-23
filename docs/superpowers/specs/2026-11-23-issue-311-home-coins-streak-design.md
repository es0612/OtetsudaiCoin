# #311 ホームの「今月のコイン」と「連続記録」 — 設計（短い版）

ステータス: in-progress（判断 4 つはオーナー回答 2026-11-23。ブランチ fix/311-home-coins-streak。1.1.7 に入れる）

## 目的

ホームで子どもを選ぶと出る 2 枚のカード（`HomeView.swift:141-156`）は子どもが毎日見る数字。今は、今月分を払うと「今月のコイン」が増えなくなり、「連続記録」は朝と毎月 1 日に 0 に見える。子どもには「記録したら必ず増える／がんばりが途切れて見えない」、親には「月の途中で払ってもホームと月のまとめが食い違わない」状態にする。

## 今の作り（main 165ef58 で確認）

- 今月のコイン: `HomeViewModel.swift:188` `monthlyAllowance = payment?.amount ?? calculatedAllowance`。今月の支払い行が 1 行でもあれば、その 1 行の額を出す。行は `findByChildIdAndMonth` が `fetchLimit = 1`・並び順なしで返すので、追加払いで行が増えるとどの額が出るかも決まらない。カードの下の文字は「コイン獲得！」（en: coins earned!）で、稼ぎを名乗っている
- 連続記録: `HomeViewModel.swift:128` が今月の記録だけを渡し、`AllowanceCalculator.calculateConsecutiveDays`（`:16-44`）は最新の記録日が今日でないと 0。計算を使っているのはホームだけ

## ゴール / 非ゴール / アンチゴール

- ゴール
  1. 「今月のコイン」は常に今月稼いだコイン（支払いの有無・行数に関係なく、記録すれば増える）
  2. 「連続記録」は、今日まだ記録していなくても昨日まで続いていればその日数を出す（今日記録すれば +1、最後の記録が一昨日以前なら 0）
  3. 「連続記録」は月・年をまたいで数える
- 非ゴール
  - 使われていない `payMonthlyAllowance` / `recordAllowancePayment` / `isCurrentMonthPaid` と今月の支払いの取得の削除（テストの書き換えを伴う整理なので別 issue。Claude の判断）
  - カードの見た目・文言（¥ / コイン表記は #155）
- アンチゴール
  - 月のまとめの数字（稼ぎ・支払い済み・支払い状態）が変わる
  - ja / en の文言が変わる

## アプローチ

| 案 | 内容 | 判断 |
| --- | --- | --- |
| ① 全記録を取る（採用・オーナー決定） | 連続日数だけ `helpRecordRepository.findByChildId` で子どもの全記録から数える。今月のコインは今の `findByChildIdInCurrentMonth` のまま | 月のまとめ・履歴・リマインダー通知と同じ取り方。新しい API なし。取得が 1 回増える（家庭単位の記録数は少なく問題ない見込み・未実測） |
| ② 直近 N 日だけ取る | `findByDateRange` で直近 60 日などを取り、子どもで絞る | N 日を超える連続を数え切れない |
| ③ 新しい取得メソッド | 「この日以降のこの子の記録」を repository に足す | protocol・Core Data・テスト用の実装まで広がり、1.1.7 のバグ修正としては広い |

## 決めたこと

1. 今月のコイン: 稼ぎ（オーナー決定）。`monthlyAllowance` は `calculatedAllowance`（= `currentMonthEarnings`）を出す
2. 連続記録の数え方（オーナー決定）: 記録のある日のうち最新が今日なら今日から、昨日なら昨日から、さかのぼって途切れるまで数える。それ以外は 0
3. 月・年をまたぐ（オーナー決定）: 案 ①
4. `calculateConsecutiveDays(records:today:)` に `today: Date = Date()` を足す（Claude の判断。月・年の境目のテストを実行日に左右されず書くため）。テスト用の `MockAllowanceCalculator` の override も合わせる
5. `isCurrentMonthPaid` と今月の支払いの取得はそのまま残す（非ゴールの別 issue で消す）

## 物差し（テスト）

- 今月 300 稼ぎ・今月の支払い 2 行（200 と 50）がある状態で、表示が 300。その後 50 記録すると 350（支払いの 1 行・合計のどれが漏れても 200 / 50 / 250 になり、稼ぎと一致しない fixture。合計が稼ぎと同じ 300 になる組み合わせは使わない）
- 連続（`today` を固定）: 10/30〜11/2 を毎日記録 → today=11/2 で 4、today=11/3（未記録）で 4、today=11/4 で 0。12/30〜1/1 を毎日 → today=1/1 で 3（年またぎ）
- 既存 `testCalculateConsecutiveDaysWithoutToday`（昨日だけ記録 → 0）は仕様変更で 1 になる。テスト名と期待値を変え、意図をコメントに残す
- ViewModel: 先月の記録がリポジトリにあるとき、それが連続日数の計算に渡る（`MockAllowanceCalculator` で受け取った records を確かめる）
- 月のまとめの既存テストが変わらず通る（アンチゴール）

## builder に任せること

- ViewModel のテストの置き場所・名前、モックの `findByChildId` の数え方（`findCallCount` を使う既存テストを壊さないこと）
- 日付 fixture の作り方は project skill `running-xcodebuild-tests-and-date-fixtures` に従う
