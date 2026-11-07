# v1.1.6 リリース手順書

このドキュメントは v1.1.6 を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」だけを人が押します。

## 0. 前提条件

- ASC で公開中: **1.1.5** (2026-10-19 公開)。2026-10-25 に `scripts/release-status.sh` (iTunes Lookup API、JP / US) で実測
- 基準タグ: `v1.1.5` (最新タグと一致)
- Marketing Version: **1.1.6** (承認済み 1.1.5 の train を閉じるため #271 で bump 済み。pbxproj 6 箇所)
- Build Number: pbxproj は **136** (Xcode Cloud の採番の下限)。提出するのは **build 140** (Xcode Cloud、#281 の merge commit `86cee5d` から 2026-10-25 10:13 に開始)。TestFlight の 1.1.6 には 136〜139 も「提出準備完了」で並んでいるが、いずれも #281 より前の commit のビルドなので使わない
- ASC Age Rating で「広告」=「はい」(#86、AdMob 統合済みのため必須)
- 今回のテーマ: **新しいアプリアイコン (コインの手渡し) と、記録画面のお手伝いカードの並び**。データ構造 (Core Data モデル) の変更は無い

> 着手前に公開中の version を実測する (CLAUDE.md「公開中の version を実測」ルール):
>
> ```bash
> /bin/bash scripts/release-status.sh
> ```

### 1.1.5 (build 135 = `6f4e261`) からの変更

| PR | issue | 内容 |
| --- | --- | --- |
| #272 | #265 | 大きな文字サイズ (AX) の記録画面で、お手伝いカードの幅を列いっぱいにそろえる |
| #275 | #18 | アプリアイコンを A1 (コインの手渡し) に差し替え、ダーク／ティンテッドに対応 |
| #276 | #151 | スプラッシュ画面を新しいアイコンとブランド色に揃え、ダークは暗い暖色にする |
| #281 | #277 | 記録画面のお手伝いカードを、通常の文字サイズでも幅と行の高さにそろえる |

## 1. App Store Connect での作業 (`asc-submission-prep`)

| 手順 | 担当 | 備考 |
| --- | --- | --- |
| dry-run で差分表を作る | Claude | 書き込み 0 件 |
| 差分表の一括 OK | 人 | 表に無い書き込みはしない |
| バージョン `1.1.6` の作成 | Claude (OK 後) | 作成したバージョンは消せない |
| What's New (ja / en) の入力 | Claude (OK 後) | § 2 の文面 |
| ビルドの紐付け | Claude (OK 後) | バージョン 1.1.6・build 140 |
| App Privacy・輸出コンプライアンス・年齢制限の確認 | **人** | 申告なので Claude は回答しない |
| 「審査用に追加」→「審査へ提出」 | **人** | |

### 1.1 スクリーンショット

変更しない。ASC スクショの 3 枚 (home / record / settings) のうち、record は初期表示でカレンダーが画面を占め、お手伝いカードは写らない (committed の `docs/screenshots/asc/v1.1.x/ja/02-record.png` (iPhone 17 Pro Max) を 2026-10-25 に目視: カレンダーの下に「今日のお手伝い」の見出しが少し出るだけ。#281 の検証撮影 (iPhone 17 Pro) でも `02-record` は status bar 以外の差分なし)。アイコンはスクショに写らず、ストアのアイコンはビルドから反映される。

### 1.2 変更しない項目

アプリ名・サブタイトル・説明文・キーワード・プロモーションテキスト・サポート URL・価格・配信地域・スクリーンショットは変更しない。

> v1.1.5 では、新バージョンを作るとプロモーションテキストが ja / en とも空になっていた (v1.1.5 手順書 § 3)。dry-run で空なら 1.1.5 の値を入れ直す。

### 1.3 dry-run の結果 (2026-10-25、書き込み 0 件)

| 項目 | ロケール | ASC 現在値 | リポ値 | 分類 | 入力元 |
| --- | --- | --- | --- | --- | --- |
| バージョン | - | なし (サイドバーは「1.1.5 配信準備完了」のみ) | 1.1.6 | create-version | pbxproj `MARKETING_VERSION` |
| ビルド | - | (バージョンが無いので未紐付け) | build 140 (1.1.6、提出準備完了、`86cee5d`) | update | TestFlight / Xcode Cloud |
| What's New | ja / en | (バージョン作成後に読む) | § 2.1 / § 2.3 | update | この手順書 |
| 審査ノート | - | (バージョン作成後に読む) | § 2.2 | update | この手順書 |
| プロモーションテキスト | ja / en | (バージョン作成後に読む) | 1.1.5 の値 (下に控え) | 空なら update | 1.1.5 の ASC 値 |
| App Review 連絡先 | - | (バージョン作成後に読む) | - | 空なら人が入力 | - |
| 年齢制限「広告」 | - | 1.1.5 で「はい」(2026-10-18 読み取り) | はい | バージョン作成後に再確認 | #86 |

- 年齢制限は、編集中のバージョンが無いと「編集」(ウィザードの入口) しか出ないため、dry-run では開いていない
- ASC スクショは変更しない (§ 1.1)

1.1.5 のプロモーションテキスト (2026-10-25 に配信中バージョンの画面から読み取り。新バージョンで空なら、この値を入れ直す):

```text
お手伝いに絵文字アイコンを付けて、記録をもっと楽しく。記録画面のカレンダーで、がんばった日がひと目で分かります。
```

```text
Give each chore its own emoji and see every recorded day on the new calendar. Recording chores is now more fun and easier to follow.
```

## 2. 文言ドラフト

> ⚠️ What's New はアイコンのダーク版・ティンテッド版に触れている。**§ 3 の「実機 (TestFlight) のホーム画面で、ダーク版・ティンテッド版が出る」を確かめるまで、§ 2.1 / § 2.3 を ASC に書き込まない**。出なかったら文面からその一文を外す。

### 2.1 このバージョンの新機能 (What's New) — ja

> 対象は 1.1.5 (公開中) → 1.1.6 の差分。
>
> ⚠️ **ja でも絵文字は使えない** (2026-09-27 実測)。見出しは【】で表す。

```text
バージョン 1.1.6 では、アプリのアイコンが新しくなりました

【新しくなったところ】
・アプリアイコンを、大人から子どもへコインを手渡すデザインに変えました。ダークモードと、色をそろえるホーム画面の設定にも対応しています
・起動したときの画面を、新しいアイコンと同じ温かい色合いにしました

【改善】
・記録画面のお手伝いカードの幅と高さをそろえ、きれいに並ぶようにしました
・大きな文字サイズのときも、記録画面のお手伝いカードが同じ幅で並ぶようにしました

引き続きおてつだいコインを楽しんでお使いください！
```

### 2.2 審査ノート (Review Notes)

```text
v1.1.6 の主な変更点 (公開中の v1.1.5 からの差分):
- アプリアイコンの変更 (ライト / ダーク / ティンテッド)
- スプラッシュ画面の配色変更
- 記録画面のお手伝いカードのレイアウト調整 (幅と行の高さをそろえる)

This app does not require sign-in. No children are pre-registered (default chores are); please add a child from the Home screen or the Settings tab to try recording chores.
If you would like to verify the English localization, please run the app with the system language set to English.
```

### 2.3 What's New (en)

> ⚠️ **plain text only, no emojis** (#85)。

```text
Version 1.1.6 brings a new app icon.

New
- A new app icon showing a coin handed from a parent to a child. It supports Dark Mode and tinted Home Screen icons.
- The launch screen now uses the same warm colors as the new icon.

Improvements
- Chore cards on the recording screen now line up with the same width and height.
- With larger text sizes, chore cards on the recording screen also share the same width.

Thank you for using Otetsudai Coin!
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `MARKETING_VERSION` = `1.1.6` (公開中 1.1.5・基準タグ v1.1.5 より高い。pbxproj 6 箇所すべて) ← ITMS-90186 / 90062 対策
- [x] `CURRENT_PROJECT_VERSION` = `136` (Xcode Cloud が採番するので下限。実ビルドは TestFlight で確かめる) ← ITMS-90478 対策
- [ ] `release-version-bump-check.yml` が green
- [ ] main でユニットテストが green (#281 の merge 後の main で確かめる)
- [ ] ja / en 両方のロケールで起動を確認
- [x] 実機 (TestFlight) のホーム画面で、新しいアイコンのダーク版・ティンテッド版が出る (#18 の close 条件 2) ※ 2026-10-25、build 140 でオーナーが確認

### App Store Connect

- [x] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK (2026-10-25。What's New は実機確認の後に回す、とオーナー判断)
- [x] バージョン `1.1.6` を作成、ビルドを紐付け (build **140**。輸出コンプライアンス等のダイアログは出なかった。再読み込みでビルド欄 140 / 1.1.6 を確認)
- [x] 審査ノート (§ 2.2) を入力し、再読み込みして全文一致を確認 (1.1.5 の文面が引き継がれていたので置き換えた。ロケール共通の欄)
- [x] プロモーションテキストは新バージョンで ja / en とも空だったため、1.1.5 の値 (§ 1.3) を入れ直し、再読み込みして全文一致を確認
- [x] App Review の連絡先は 4 項目とも引き継がれていた
- [x] What's New (ja § 2.1 / en § 2.3) を入力し、再読み込みして全文一致を確認 (2026-10-25、実機確認の後。「無効な文字」エラーなし)
- [x] 年齢制限: 「広告」=「はい」(人) ※ 2026-10-25 にオーナーが編集ウィザードで確認。 2026-10-25 時点の ASC では「詳細を表示」が国・地域ごとの結果 (4+) だけを出し、回答は「年齢制限指定を編集」のウィザードの中にしか無いため、Claude は読んでいない。アプリ単位の設定で、2026-10-18 に「はい」を確認済み
- [x] App Privacy・輸出コンプライアンスを確認 (人) ※ App Privacy は 5 か月前の公開内容 (デバイス ID・ユーザーに関連付けない・サードパーティ広告) のまま。輸出コンプライアンスは `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (pbxproj) のためダイアログなし

### 提出

- [x] 「審査用に追加」→「審査へ提出」(2026-10-25 16:35 頃、オーナーのチャットでの依頼を受けて Claude が操作。提出物は「iOSアプリ 1.1.6 / 1.1.6 (140)」の 1 件のみ、質問ダイアログなし。再読み込みでサイドバー「1.1.6 審査待ち」を確認)

## 4. 完了後タスク

次の 2 つは **bump PR の merge → タグの push** の順で行う (v1.1.5 手順書 § 4 / PR #273)。

- [x] **承認されたら**、次の version (1.1.7) への bump PR を他の PR より先に merge する (Xcode Cloud の train closed 対策、#235) ※ 2026-11-07、PR #287 (`b43546a`) で 1.1.7 / build 141 (TestFlight の最新は build 140 を ASC で確認)。公開から 12 日遅れ。その間に main へ merge した PR は 0 件
- [x] bump PR の merge 後すぐ `git tag -a v1.1.6 -m "v1.1.6" <ビルド元 commit> && git push origin v1.1.6` (承認前にタグを打たない) ※ 2026-11-07、`86cee5d` (build 140 のビルド元) に打って push。`release-status.sh` の判定が `ok` (基準タグと最新タグが一致)
- [x] 公開後に `scripts/release-status.sh` で 1.1.6 を実測 ※ 2026-11-07、公開中 1.1.6 (JP / US とも 2026-10-26)
- [x] App Store の掲載ページに新しいアイコンが出ることを確かめ、#18 を close (#18 の close 条件 1) ※ 2026-11-07、iTunes Lookup の `artworkUrl512` で A1 を確認して close
- [x] GitHub Release を作成 (§ 2.1 / § 2.3) ※ 2026-11-07、[v1.1.6](https://github.com/es0612/OtetsudaiCoin/releases/tag/v1.1.6) (Latest)。v1.1.5 の GitHub Release は作られていない
- [x] `release-retrospective` skill で振り返り ※ 2026-11-07、§ 5

## 5. 振り返り (Retrospective)

> 2026-11-07 に `release-retrospective` skill で記入。対象は公開中だった 1.1.5 → 1.1.6 の期間 (`v1.1.5..v1.1.6`) と、公開後の後片付け (#287〜#289)。
> 対象 PR: **#271〜#285 の 10 本**と、公開後の 3 本。v1.1.5 の振り返りは書かれていないため、v1.1.5 の期間 (#265〜#270) はここでは扱わない。
> ステータス: 公開は **done** (JP / US とも iTunes Lookup で 1.1.6、`currentVersionReleaseDate` は 2026-10-25T21:26:48Z)。

### 数字で見るこのサイクル

| 指標 | 値 |
| --- | --- |
| 前回の公開 → 今回の公開 | 2026-10-19 → 2026-10-26 (**7 日**。1.1.4 のサイクルは 126 日) |
| 出した変更 | feat / fix のコミット **4 件** (#272 / #275 / #276 / #281) |
| 提出 → 公開 | 2026-10-25 07:36Z → 21:26Z (約 14 時間、reject なし) |
| 公開 → 後片付け (bump・タグ) | 2026-10-26 → 2026-11-07 (**12 日**。その間に main へ merge した PR は 0 件だったので、却下メールは出ていない) |
| CLAUDE.md のサイズ (1.1.4 の振り返り時 → 現在) | 214 行 / 73 KB → **160 行 / 72.6 KB** (#233 の方針で、新しい学びは追記せず #233 に記録している) |

### 良かった点

- **小さく速く出せた**: 1.1.4 の振り返りで「126 日・104 件を 1 回で出した」ことを反省した次のサイクルで、1.1.5 → 1.1.6 を 7 日・4 件で出した。What's New も 4 行で済んだ
- **#273 の物差しを達成した**: 完了後タスクを「bump の merge → タグの push」の順にした結果、2026-11-07 の main への push 3 回とタグ push 1 回で、Train Open Check はすべて success。失敗メールは 0 通
- **アイコンの「人の作業」を Claude が仕上げた**: #18 は、asset catalog の編集と Gemini での再生成で、ダーク版・ティンテッド版まで対応できた (#274 / #275)。オーナーの作業は実機での目視 1 回 (build 140) だけになった
- **配信後のずれをトリアージが拾った**: `daily-issue-triage` の Step 0 の 6 (配信後の後片付け) が、12 日遅れの bump とタグを表の先頭に出した。この Step を入れたときの物差し「次のリリース後のトリアージで、このずれが表に出ること」を初めて満たした

### 詰まった点 / 失敗

- **公開後の後片付けが 12 日止まった**: 手順書 § 4 にも #18 のコメントにも手順は書いてあったが、承認の通知を受けて動く仕組みがなく、次のトリアージまで誰も動かなかった。今回は間に `app/` の変更がなかったので無傷だった
- **v1.1.5 の後片付けも一部抜けていた**: v1.1.5 の GitHub Release と振り返りは作られていない (2026-11-07 に気づいた)。`release-status.sh` はタグと公開中のバージョンしか見ないので、GitHub Release の抜けはどの仕組みにも拾われない。v1.1.5 の Release は 2026-11-07 に作成した (公開から 19 日後)。v1.1.5 の振り返りは、時間がたっているので書かない
- **§ 3 の 3 項目が、v1.1.4 に続いて未チェックのまま提出した**: 「`release-version-bump-check.yml` が green」「main でユニットテストが green」「ja / en 両方で起動」。前の 2 つは PR 側に証拠がある (PR #271 で pass、PR #281 のブランチで 571 件 green) が、手順書に転記されていない。ja / en の起動は記録がない。v1.1.4 の振り返りの「未確認事項」と同じ項目が、2 回続けて残った

### 想定外の発見

- **#283 の案 B は、本文に書かれた事故そのものを見逃す設計だった**: 撮影の前後で設定を比べる案だったが、事故では相手のセッションが撮影中に外観と文字サイズを戻していた。実装前に気づき、5 秒ごとの見張りに変えた (PR #288、#233 の候補 J)
- **LeafTimer 側は自分専用の名前の Simulator を使い始めている** (`leaftimer-188-*`・`LeafTimer-Store-*`)。#283 の案 C (端末を分ける) は、相手側で一部進んでいた
- **auto mode の分類器の判定が操作ごとに違った**: `gh pr merge` は 1 回目に拒否され、オーナーがチャットで許可した後は通った。`gh release create` は v1.1.6 では通り、v1.1.5 では「Create Public Surface」で拒否された

### 未確認事項

- ja / en 両方のロケールでの起動 (§ 3)。公開済みの 1.1.6 を実機で開いて確かめる

### 次サイクルへの遺産 (Action items)

| 学び | 行き先 | 状態 |
| --- | --- | --- |
| 完了後タスクは bump の merge → タグの push の順 | 手順書テンプレ (#273) | done (失敗メール 0 通) |
| 配信後の後片付けのずれを Step 0 で拾う | `daily-issue-triage` Step 0 の 6 | done (今回、表の先頭に出た) |
| UI の寸法を変える issue は、外形と中身の論点を 1 回の質問にまとめる | #233 の候補 I | done (記録のみ) |
| issue の案を事故の時系列に当ててから実装する。長い外部処理は偽コマンドで再現する | #233 の候補 J | done (記録のみ) |
| usage を固定の行範囲で読まない | #233 の候補 F → PR #288 | done |
| 撮影中に Simulator の設定が書き換わったら止める | #283 → PR #288 | done (2026-11-07、本物の撮影 5 回 × light / dark で誤停止 0 / 10。既定サイズのみ、AX サイズは未計測) |
| GitHub Release の抜けを拾う仕組みがない | `release-status.sh` に 1 行 (PR #291) + `daily-issue-triage` Step 0 に 1 文 | in-progress (PR #291 レビュー待ち) |
| § 3 の未チェックが 2 回続いた | Issue #290 (v1.1.7 の手順書で、CI の項目を証拠リンク欄にする) | idea |
| v1.1.5 の GitHub Release | [v1.1.5](https://github.com/es0612/OtetsudaiCoin/releases/tag/v1.1.5) を作成 (1 回目は分類器が拒否し、オーナーの許可の後に再試行) | done |
| 公開系の操作が分類器に拒否されたら、closed 質問で「自分でやる／1 回だけ再試行を許可」を聞く | グローバル CLAUDE.md の merge ルールを更新 | done |
