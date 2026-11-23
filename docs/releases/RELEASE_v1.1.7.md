# v1.1.7 リリース手順書

このドキュメントは v1.1.7 を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」は人が押すか、人のチャットでの依頼を受けて Claude が押します。

## 0. 前提条件

- ASC で公開中: **1.1.6** (2026-10-26 公開)。2026-11-23 に `scripts/release-status.sh` (iTunes Lookup API、JP / US) で実測。前回公開から 28 日
- 基準タグ: `v1.1.6` (最新タグと一致。GitHub Release もあり)
- Marketing Version: **1.1.7** (承認済み 1.1.6 の train を閉じるため #287 で bump 済み。pbxproj 6 箇所)
- Build Number: pbxproj は **141** (Xcode Cloud の採番の下限)。提出するのは **build {未定}** (Xcode Cloud、#317 と #310(a) の PR を merge した後の main の commit から。TestFlight の最新ビルドは ASC にログインしてから確かめる)
- ASC Age Rating で「広告」=「はい」(#86、AdMob 統合済みのため必須)
- 今回のテーマ: **支払いのおまけ (#279) と、英語表示の翻訳の仕上げ**。**Core Data のモデルが v4 → v5 に変わる** (#279 でおまけの欄を追加。軽量マイグレーション。v4 のストアがそのまま開けることは PR #297 のテストで確認済み)

> 着手前に公開中の version を実測する (CLAUDE.md「公開中の version を実測」ルール):
>
> ```bash
> /bin/bash scripts/release-status.sh
> ```

### 1.1.6 (build 140 = `86cee5d`) からの変更

利用者に見える変更だけを並べる (docs / CI / テストだけの PR は除く)。

| PR | issue | 内容 |
| --- | --- | --- |
| #297 | #279 | 月のまとめの支払いに、おまけ (額 + 褒め言葉スタンプ 4 種から 1 つ) を付けられる。払った瞬間の演出と「もらったおまけ」欄 |
| #318 | #311 | ホームの「今月のコイン」を今月稼いだ額にし、連続記録を昨日までの日数で月・年をまたいで数える |
| #305 | #301 | 履歴の期間切り替え・空状態とホームの未払いバナーを英語表示で翻訳 |
| #315 | #308 | 集計カードと未払いバナーを英語表示で翻訳し、期間の重複と案内文を直す |
| #316 | #308 | チュートリアルと子どもフォームの文言を英語表示で翻訳 |
| #295 | #280 | 記録画面のお手伝いカードで、記録済みの件数をコインと同じ行に置き、隣のカードとコインの高さをそろえる |
| #294 | #151 | 起動画面の背景を Splash にそろえ、Splash のアニメーションを「視差効果を減らす」に従わせる |
| {PR} | #317 | (作業中) 英語表示の記録チュートリアルで、お手伝いカードの名前が 1 行で切れるのを直す |
| {PR} | #310 | (作業中) 子どもの削除の確認文が名前だけになるのを直し、お手伝い・子どもの削除で「これまでの記録 N 件も消える」ことを伝える |

内部の変更 (利用者には見えない): #321 (#319 使われていない支払い処理の削除)、#322 (#313 テストの待ち方)、#325 (#306 CI のチェック)。

## 1. App Store Connect での作業 (`asc-submission-prep`)

| 手順 | 担当 | 備考 |
| --- | --- | --- |
| dry-run で差分表を作る | Claude | 書き込み 0 件 |
| 差分表の一括 OK | 人 | 表に無い書き込みはしない |
| バージョン `1.1.7` の作成 | Claude (OK 後) | 作成したバージョンは消せない |
| What's New (ja / en) の入力 | Claude (OK 後) | § 2 の文面 |
| ビルドの紐付け | Claude (OK 後) | バージョン 1.1.7・build {未定} |
| App Privacy・輸出コンプライアンス・年齢制限の確認 | **人** | 申告なので Claude は回答しない |
| **§ 3 の空欄が 0 件であることを確かめる** | Claude | 下のコマンドが `ok: ... (§ 3 の空欄 0 件 ...)` と出す。`warn:` で空欄が出たら「審査へ提出」に進まず、その項目を人に見せる (#290) |
| 「審査用に追加」→「審査へ提出」 | **人** (チャットでの依頼があれば Claude) | |

提出前の空欄チェック (`### 提出` より前の § 3 で、未チェックの項目と空の証拠欄を、ファイルの行番号つきで出す):

```bash
/bin/bash scripts/release-doc-check.sh docs/releases/RELEASE_v1.1.7.md
```

同じ script を CI (`release-doc-check.yml`) が手順書を変える PR で流す。「### 提出」が `[x]` なのに空欄がある PR は失敗する (#306)。ただし CI が止められるのは提出を**記録する** PR で、提出そのものではない。提出の前に止めるのは、上の表のこの手順。

### 1.1 スクリーンショット

変更しない (予定)。ASC の画像は「デザイン画像」で、ホーム・記録・設定の初期表示。今回の変更 (おまけ・英語の翻訳・削除の確認文) はどれも初期表示には出ない。en の画像を en 専用にするのは #231 で別に扱う

### 1.2 変更しない項目

アプリ名・サブタイトル・説明文・キーワード・プロモーションテキスト・サポート URL・価格・配信地域・スクリーンショット (ja / en とも)

> 新バージョンを作るとプロモーションテキストが ja / en とも空になることがある (v1.1.5・v1.1.6 で発生)。dry-run で空なら前の版の値を入れ直す。

### 1.3 dry-run の結果 (未実施、書き込み 0 件)

> 2026-11-23 時点で ASC はログアウト中。ログイン後に `asc-submission-prep` の dry-run で埋める。

| 項目 | ロケール | ASC 現在値 | リポ値 | 分類 | 入力元 |
| --- | --- | --- | --- | --- | --- |
| バージョン | - | | 1.1.7 | create-version | pbxproj `MARKETING_VERSION` |
| ビルド | - | | build {未定} | update | TestFlight / Xcode Cloud |
| What's New | ja / en | | § 2.1 / § 2.3 | update | この手順書 |
| 審査ノート | - | | § 2.2 | update | この手順書 |
| プロモーションテキスト | ja / en | | 前の版の値 | 空なら update | 前の版の ASC 値 |
| 年齢制限「広告」 | - | | はい | バージョン作成後に再確認 | #86 |

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja

> 対象は 1.1.6 (公開中) → 1.1.7 の差分。
>
> ⚠️ **ja でも絵文字は使えない** (2026-09-27 実測)。見出しは【】で表す。

```text
バージョン 1.1.7 では、お小遣いを渡すときに「おまけ」を付けられるようになりました

【新しくなったところ】
・月のまとめからお小遣いを支払うときに、おまけの額と褒め言葉のスタンプを付けられるようにしました。渡した瞬間にスタンプとおまけの額が大きく表示され、あとから月のまとめで見返せます

【改善】
・ホームの「今月のコイン」を、今月がんばって稼いだコインの数にしました
・連続記録の日数を、月や年をまたいでも数え続けるようにしました
・英語表示で、履歴・月のまとめ・チュートリアル・子どもの登録画面などに日本語が残っていたところを翻訳しました
・英語表示のチュートリアルで、お手伝いの名前が途中で切れないようにしました
・子どもやお手伝いを削除するときの確認で、これまでの記録も一緒に消えることを件数でお知らせするようにしました
・記録画面のお手伝いカードで、記録済みの件数とコインを同じ行にそろえました
・起動画面の色をそろえ、「視差効果を減らす」の設定ではアニメーションを控えめにしました

引き続きおてつだいコインを楽しんでお使いください！
```

### 2.2 審査ノート (Review Notes)

```text
v1.1.7 の主な変更点 (公開中の v1.1.6 からの差分):
- 月のまとめの支払いに、任意の「おまけ」(額と褒め言葉スタンプ) を付けられる機能を追加。おまけを付けない支払いは従来どおりボタン 1 回
- ホームの「今月のコイン」と連続記録日数の計算を修正
- 英語表示の翻訳漏れの修正 (履歴・月のまとめ・チュートリアル・子どもの登録)
- 子ども・お手伝いを削除するときの確認文の修正

To try the new bonus feature: add a child, record a chore on the Record tab, open the child's monthly summary from the Home screen, and choose "Pay with a bonus".

This app does not require sign-in. No children are pre-registered (default chores are); please add a child from the Home screen or the Settings tab to try recording chores.
If you would like to verify the English localization, please run the app with the system language set to English.
```

### 2.3 What's New (en)

> ⚠️ **plain text only, no emojis** (#85)。

```text
Version 1.1.7 lets you add a bonus when you hand over allowance.

New
- When paying allowance from the monthly summary, you can add a bonus amount and a praise stamp. The stamp and bonus are shown in a big way at the moment of payment, and you can look back at them in the monthly summary.

Improvements
- "Coins this month" on the Home screen now shows the coins earned this month.
- The streak now keeps counting across months and years.
- Translated the remaining Japanese text in English mode, including history, the monthly summary, the tutorial, and the child registration screen.
- In the English tutorial, chore names are no longer cut off.
- When deleting a child or a chore, the confirmation now tells you how many past records will also be deleted.
- On the recording screen, the recorded count now sits on the same line as the coins.
- The launch screen colors are now consistent, and animations are reduced when Reduce Motion is on.

Thank you for using Otetsudai Coin!
```

## 3. 提出前チェックリスト

> 各項目は「担当・取り方・証拠」の 3 点で書く。証拠を書いてから `- [x]` にする。v1.1.3〜v1.1.6 の 4 版で、「`release-version-bump-check.yml` が green」「ユニットテストが green」「ja / en で起動」のどれかが未チェックのまま提出された (ja / en は 4 版連続。#290)。
> 提出の直前に、§ 1 の作業表にあるコマンド (`scripts/release-doc-check.sh`) を流し、§ 3 の空欄が 0 件であることを確かめる。やらずに提出する項目は、チェックを付けずに項目の行へ `未実施: <理由>` と書く。

### コード / プロジェクト

- [ ] `MARKETING_VERSION` = `1.1.7` (公開中・基準タグより高い。pbxproj 6 箇所すべて) ← ITMS-90186 / 90062 対策
  - 担当: Claude
  - 取り方: `/bin/bash scripts/release-status.sh` と `grep -c 'MARKETING_VERSION = 1.1.7;' app/OtetsudaiCoin.xcodeproj/project.pbxproj`
  - 証拠:
- [ ] `CURRENT_PROJECT_VERSION` が TestFlight の最新ビルド以上 ← ITMS-90478 対策
  - 担当: Claude
  - 取り方: pbxproj の値と、TestFlight (ASC) の最新ビルド番号を並べる。Xcode Cloud が採番するので pbxproj は下限
  - 証拠:
- [ ] `release-version-bump-check.yml` が green
  - 担当: Claude
  - 取り方: bump PR の `gh pr checks 287` で `Verify version bump` が pass。短時間の pass は skip のことがあるので、`gh run view {run id} --log | grep -E 'HEAD :|BASE :|check passed'` で比較の行まで写す
  - 証拠:
- [ ] ビルド元の commit でユニットテストが green
  - 担当: Claude (この workflow はユニットテストを流さないので、ローカルで流す)
  - 取り方: 提出する build のビルド元 commit で `xcodebuild test ... > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` (skill `running-xcodebuild-tests-and-date-fixtures` の形)
  - 証拠:
- [ ] ja / en 両方のロケールで起動する
  - 担当: Claude (Simulator。`ios-simulator-locale-testing` skill で `-AppleLanguages` を起動ごとに切り替える)
  - 取り方: ビルド元 commit を ja / en で起動し、各ロケールで最初に見えた画面のスクショを Read で目視する。証拠には日付・端末・commit と、各ロケールで見えた文言を書く (例「ja: ホームに『おてつだいコイン』／en: ホームに『Otetsudai Coin』」)
  - 証拠:

### App Store Connect

- [ ] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK (人)
- [ ] バージョン `1.1.7` を作成、ビルドを紐付け (build {未定})
- [ ] 審査ノート (§ 2.2) を入力し、再読み込みして全文一致を確認
- [ ] プロモーションテキストが空なら前の版の値を入れ直し、再読み込みして全文一致を確認
- [ ] What's New (ja § 2.1 / en § 2.3) を入力し、再読み込みして全文一致を確認 (「無効な文字」エラーなし)
- [ ] 年齢制限: 「広告」=「はい」(人)
- [ ] App Privacy・輸出コンプライアンスを確認 (人)

### 提出

- [ ] 「審査用に追加」→「審査へ提出」({日時}、{誰が操作したか}。提出物の一覧と、再読み込み後のサイドバーの状態)

## 4. 完了後タスク

次の 2 つは **bump PR の merge → タグの push** の順で行う (v1.1.5 手順書 § 4 / PR #273)。

- [ ] **承認されたら**、次の version への bump PR を他の PR より先に merge する (Xcode Cloud の train closed 対策、#235)
- [ ] bump PR の merge 後すぐ `git tag -a v1.1.7 -m "v1.1.7" {ビルド元 commit} && git push origin v1.1.7` (承認前にタグを打たない)
- [ ] 公開後に `scripts/release-status.sh` で 1.1.7 を実測する
- [ ] GitHub Release を作成 (§ 2.1 / § 2.3)
- [ ] `release-retrospective` skill で振り返り

## 5. 振り返り (Retrospective)

{`release-retrospective` skill で記入}
