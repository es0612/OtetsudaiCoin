# vX.Y.Z リリース手順書

<!--
このテンプレの使い方 (#290):
- 新しい手順書は、前の版の手順書ではなくこのファイルを写して作る (`cp docs/releases/RELEASE_TEMPLATE.md docs/releases/RELEASE_vX.Y.Z.md`)
- `X.Y.Z` / `{...}` を埋め、このコメントは消す
- § 3 は「チェックボックス + 担当 + 取り方 + 証拠」の形を崩さない。CI が自動で確かめない項目は、証拠を書くまで `- [x]` にしない
-->

このドキュメントは vX.Y.Z を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」は人が押すか、人のチャットでの依頼を受けて Claude が押します。

## 0. 前提条件

- ASC で公開中: **{公開中の version}** ({公開日})。{実測日} に `scripts/release-status.sh` で実測
- 基準タグ: `v{公開中の version}` (最新タグと一致するか)
- Marketing Version: **X.Y.Z** ({bump した PR})
- Build Number: pbxproj は **{N}** (Xcode Cloud の採番の下限)。提出するのは **build {N}** (Xcode Cloud、{ビルド元 commit} から)
- ASC Age Rating で「広告」=「はい」(#86、AdMob 統合済みのため必須)
- 今回のテーマ: {1 行}

> 着手前に公開中の version を実測する (CLAUDE.md「公開中の version を実測」ルール):
>
> ```bash
> /bin/bash scripts/release-status.sh
> ```

### {公開中の version} (build {N} = `{commit}`) からの変更

| PR | issue | 内容 |
| --- | --- | --- |
| #{N} | #{N} | {内容} |

## 1. App Store Connect での作業 (`asc-submission-prep`)

| 手順 | 担当 | 備考 |
| --- | --- | --- |
| dry-run で差分表を作る | Claude | 書き込み 0 件 |
| 差分表の一括 OK | 人 | 表に無い書き込みはしない |
| バージョン `X.Y.Z` の作成 | Claude (OK 後) | 作成したバージョンは消せない |
| What's New (ja / en) の入力 | Claude (OK 後) | § 2 の文面 |
| ビルドの紐付け | Claude (OK 後) | バージョン X.Y.Z・build {N} |
| App Privacy・輸出コンプライアンス・年齢制限の確認 | **人** | 申告なので Claude は回答しない |
| **§ 3 の空欄が 0 件であることを確かめる** | Claude | 下のコマンドの出力が 0 行。1 行でも出たら「審査へ提出」に進まず、その項目を人に見せる (#290) |
| 「審査用に追加」→「審査へ提出」 | **人** (チャットでの依頼があれば Claude) | |

提出前の空欄チェック (`### 提出` より前の § 3 で、未チェックの項目と空の証拠欄を、ファイルの行番号つきで出す):

```bash
awk '/^## 3\./{f=1;next} /^### 提出/{f=0} f && (/^- \[ \]/ || /証拠: *$/) {print NR": "$0}' \
    docs/releases/RELEASE_vX.Y.Z.md
```

v1.1.6 の手順書に流すと、未チェックのまま提出した 3 項目 (136〜138 行) が出る。

### 1.1 スクリーンショット

{変更する / しない と、その根拠 (撮影で確かめた画面)}

### 1.2 変更しない項目

{アプリ名・サブタイトル・説明文・キーワード・プロモーションテキスト・サポート URL・価格・配信地域・スクリーンショットのうち、変えないもの}

> 新バージョンを作るとプロモーションテキストが ja / en とも空になることがある (v1.1.5・v1.1.6 で発生)。dry-run で空なら前の版の値を入れ直す。

### 1.3 dry-run の結果 ({日付}、書き込み 0 件)

| 項目 | ロケール | ASC 現在値 | リポ値 | 分類 | 入力元 |
| --- | --- | --- | --- | --- | --- |
| バージョン | - | | X.Y.Z | create-version | pbxproj `MARKETING_VERSION` |
| ビルド | - | | build {N} | update | TestFlight / Xcode Cloud |
| What's New | ja / en | | § 2.1 / § 2.3 | update | この手順書 |
| 審査ノート | - | | § 2.2 | update | この手順書 |
| プロモーションテキスト | ja / en | | 前の版の値 | 空なら update | 前の版の ASC 値 |
| 年齢制限「広告」 | - | | はい | バージョン作成後に再確認 | #86 |

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja

> 対象は {公開中の version} (公開中) → X.Y.Z の差分。
>
> ⚠️ **ja でも絵文字は使えない** (2026-09-27 実測)。見出しは【】で表す。

```text
バージョン X.Y.Z では、{1 行}

【新しくなったところ】
・{内容}

【改善】
・{内容}

引き続きおてつだいコインを楽しんでお使いください！
```

### 2.2 審査ノート (Review Notes)

```text
vX.Y.Z の主な変更点 (公開中の v{公開中の version} からの差分):
- {内容}

This app does not require sign-in. No children are pre-registered (default chores are); please add a child from the Home screen or the Settings tab to try recording chores.
If you would like to verify the English localization, please run the app with the system language set to English.
```

### 2.3 What's New (en)

> ⚠️ **plain text only, no emojis** (#85)。

```text
Version X.Y.Z {1 line}.

New
- {item}

Improvements
- {item}

Thank you for using Otetsudai Coin!
```

## 3. 提出前チェックリスト

> 各項目は「担当・取り方・証拠」の 3 点で書く。証拠を書いてから `- [x]` にする。v1.1.3〜v1.1.6 の 4 版で、「`release-version-bump-check.yml` が green」「ユニットテストが green」「ja / en で起動」のどれかが未チェックのまま提出された (ja / en は 4 版連続。#290)。
> 提出の直前に § 1 の空欄チェックを流し、出力が 0 行であることを確かめる。

### コード / プロジェクト

- [ ] `MARKETING_VERSION` = `X.Y.Z` (公開中・基準タグより高い。pbxproj 6 箇所すべて) ← ITMS-90186 / 90062 対策
  - 担当: Claude
  - 取り方: `/bin/bash scripts/release-status.sh` と `grep -c 'MARKETING_VERSION = X.Y.Z;' app/OtetsudaiCoin.xcodeproj/project.pbxproj`
  - 証拠:
- [ ] `CURRENT_PROJECT_VERSION` が TestFlight の最新ビルド以上 ← ITMS-90478 対策
  - 担当: Claude
  - 取り方: pbxproj の値と、TestFlight (ASC) の最新ビルド番号を並べる。Xcode Cloud が採番するので pbxproj は下限
  - 証拠:
- [ ] `release-version-bump-check.yml` が green
  - 担当: Claude
  - 取り方: bump PR の `gh pr checks {PR}` で `Verify version bump` が pass。短時間の pass は skip のことがあるので、`gh run view {run id} --log | grep -E 'HEAD :|BASE :|check passed'` で比較の行まで写す
  - 証拠:
- [ ] ビルド元の commit でユニットテストが green
  - 担当: Claude (この workflow はユニットテストを流さないので、ローカルで流す)
  - 取り方: 提出する build のビルド元 commit で `xcodebuild test ... > "$LOG" 2>&1; grep -E -A6 '\*\* TEST|Failing tests:' "$LOG"` (CLAUDE.md「iOS テスト flake 切り分け」の形)
  - 証拠:
- [ ] ja / en 両方のロケールで起動する
  - 担当: Claude (Simulator。`ios-simulator-locale-testing` skill で `-AppleLanguages` を起動ごとに切り替える)
  - 取り方: ビルド元 commit を ja / en で起動し、各ロケールで最初に見えた画面のスクショを Read で目視する。証拠には日付・端末・commit と、各ロケールで見えた文言を書く (例「ja: ホームに『おてつだいコイン』／en: ホームに『Otetsudai Coin』」)
  - 証拠:

### App Store Connect

- [ ] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK (人)
- [ ] バージョン `X.Y.Z` を作成、ビルドを紐付け (build {N})
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
- [ ] bump PR の merge 後すぐ `git tag -a vX.Y.Z -m "vX.Y.Z" {ビルド元 commit} && git push origin vX.Y.Z` (承認前にタグを打たない)
- [ ] 公開後に `scripts/release-status.sh` で X.Y.Z を実測する
- [ ] GitHub Release を作成 (§ 2.1 / § 2.3)
- [ ] `release-retrospective` skill で振り返り

## 5. 振り返り (Retrospective)

{`release-retrospective` skill で記入}
