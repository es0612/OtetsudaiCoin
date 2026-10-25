# v1.1.6 リリース手順書

このドキュメントは v1.1.6 を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」だけを人が押します。

## 0. 前提条件

- ASC で公開中: **1.1.5** (2026-10-19 公開)。2026-10-25 に `scripts/release-status.sh` (iTunes Lookup API、JP / US) で実測
- 基準タグ: `v1.1.5` (最新タグと一致)
- Marketing Version: **1.1.6** (承認済み 1.1.5 の train を閉じるため #271 で bump 済み。pbxproj 6 箇所)
- Build Number: pbxproj は **136** (Xcode Cloud の採番の下限)。提出するビルドは、#277 (PR #281) の merge commit 以降に Xcode Cloud が作ったものを TestFlight で確かめてから書く: **build TBD**
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
| ビルドの紐付け | Claude (OK 後) | バージョン 1.1.6・#281 の merge 以降のビルド (提出準備完了になってから) |
| App Privacy・輸出コンプライアンス・年齢制限の確認 | **人** | 申告なので Claude は回答しない |
| 「審査用に追加」→「審査へ提出」 | **人** | |

### 1.1 スクリーンショット

変更しない。ASC スクショの 3 枚 (home / record / settings) のうち、record は初期表示でカレンダーが画面を占め、お手伝いカードは写らない (#281 の検証撮影で `02-record` は status bar 以外の差分なし)。アイコンはスクショに写らず、ストアのアイコンはビルドから反映される。

### 1.2 変更しない項目

アプリ名・サブタイトル・説明文・キーワード・プロモーションテキスト・サポート URL・価格・配信地域・スクリーンショットは変更しない。

> v1.1.5 では、新バージョンを作るとプロモーションテキストが ja / en とも空になっていた (v1.1.5 手順書 § 3)。dry-run で空なら 1.1.5 の値を入れ直す。

## 2. 文言ドラフト

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
- [ ] 実機 (TestFlight) のホーム画面で、新しいアイコンのダーク版・ティンテッド版が出る (#18 の close 条件 2)

### App Store Connect

- [ ] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK
- [ ] バージョン `1.1.6` を作成、ビルドを紐付け
- [ ] What's New (ja § 2.1 / en § 2.3)・審査ノート (§ 2.2) を入力し、再読み込みして全文一致を確認
- [ ] 年齢制限: 「広告」=「はい」
- [ ] App Privacy・輸出コンプライアンスを確認 (人)

### 提出

- [ ] 「審査用に追加」→「審査へ提出」(人)

## 4. 完了後タスク

次の 2 つは **bump PR の merge → タグの push** の順で行う (v1.1.5 手順書 § 4 / PR #273)。

- [ ] **承認されたら**、次の version (1.1.7) への bump PR を他の PR より先に merge する (Xcode Cloud の train closed 対策、#235)
- [ ] bump PR の merge 後すぐ `git tag -a v1.1.6 -m "v1.1.6" <ビルド元 commit> && git push origin v1.1.6` (承認前にタグを打たない)
- [ ] 公開後に `scripts/release-status.sh` で 1.1.6 を実測
- [ ] App Store の掲載ページに新しいアイコンが出ることを確かめ、#18 を close (#18 の close 条件 1)
- [ ] GitHub Release を作成 (§ 2.1 / § 2.3)
