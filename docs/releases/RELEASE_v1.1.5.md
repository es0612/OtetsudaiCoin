# v1.1.5 リリース手順書

このドキュメントは v1.1.5 を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」だけを人が押します。

## 0. 前提条件

- ASC で公開中: **1.1.4** (2026-09-28 公開)。2026-10-18 に `scripts/release-status.sh` (iTunes Lookup API、JP / US) で実測
- 基準タグ: `v1.1.4` (最新タグと一致)
- Marketing Version: **1.1.5** (承認済み 1.1.4 の train を閉じるため #236 で bump 済み)
- Build Number: pbxproj は **124** (Xcode Cloud の採番の下限)。提出するのは **build 135** (Xcode Cloud、#266 の merge commit `6f4e261` から 2026-10-18 15:58 に開始)。TestFlight の 1.1.5 には 124〜134 も「提出準備完了」で並んでいるが、いずれも #266 より前の commit のビルドなので使わない
- ASC Age Rating で「広告」=「はい」(#86、AdMob 統合済みのため必須)
- 今回のテーマ: **大きな文字サイズ (アクセシビリティサイズ) とダークモードでの見やすさ**。データ構造 (Core Data モデル) の変更は無い

> 着手前に公開中の version を実測する (CLAUDE.md「公開中の version を実測」ルール):
>
> ```bash
> /bin/bash scripts/release-status.sh
> ```

## 1. App Store Connect での作業 (`asc-submission-prep`)

| 手順 | 担当 | 備考 |
| --- | --- | --- |
| dry-run で差分表を作る | Claude | 書き込み 0 件 |
| 差分表の一括 OK | 人 | 表に無い書き込みはしない |
| バージョン `1.1.5` の作成 | Claude (OK 後) | 作成したバージョンは消せない |
| What's New (ja / en) の入力 | Claude (OK 後) | § 2 の文面 |
| ビルドの紐付け | Claude (OK 後) | バージョン 1.1.5・build 135 (提出準備完了になってから) |
| App Privacy・輸出コンプライアンス・年齢制限の確認 | **人** | 申告なので Claude は回答しない |
| 「審査用に追加」→「審査へ提出」 | **人** | |

### 1.1 スクリーンショット

変更しない。今回の変更は AX サイズ (アクセシビリティの大きな文字) とダークモードでだけ見た目が変わり、ASC スクショ (既定サイズ・light) には影響しない。

### 1.2 変更しない項目

アプリ名・サブタイトル・説明文・キーワード・プロモーションテキスト・サポート URL・価格・配信地域・スクリーンショットは変更しない。

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja

> 対象は 1.1.4 (公開中) → 1.1.5 の差分。
>
> ⚠️ **ja でも絵文字は使えない** (2026-09-27 実測)。見出しは【】で表す。

```text
バージョン 1.1.5 では、大きな文字サイズとダークモードでの見やすさを改善しました

【改善】
・iPhone の文字サイズを大きくしているときも、チュートリアルの説明やお手伝いの名前が途中で切れずに読めるようになりました
・大きな文字サイズのとき、記録画面のお手伝いを 1 列で表示し、記録ボタンまわりをすっきりさせて一覧を広く使えるようにしました
・履歴画面とスプラッシュ画面の文字やアイコンが、文字サイズの設定に合わせて大きくなるようになりました
・ダークモードで、月のまとめの数字が背景に沈んで読みにくかった問題を修正しました

【不具合修正】
・チュートリアルで、選んだお手伝いの「記録する」ボタンが画面の外に隠れることがある問題を修正しました

引き続きおてつだいコインを楽しんでお使いください！
```

### 2.2 審査ノート (Review Notes)

```text
v1.1.5 の主な変更点 (公開中の v1.1.4 からの差分):
- Dynamic Type のアクセシビリティサイズ (設定 > アクセシビリティ > 画面表示とテキストサイズ > さらに大きな文字) での表示改善 (チュートリアル・記録画面・履歴画面)
- ダークモードでのコントラスト改善

This app does not require sign-in. No children are pre-registered (default chores are); please add a child from the Home screen or the Settings tab to try recording chores.
If you would like to verify the English localization, please run the app with the system language set to English.
```

### 2.3 What's New (en)

> ⚠️ **plain text only, no emojis** (#85)。

```text
Version 1.1.5 improves readability with larger text sizes and in Dark Mode.

Improvements
- With larger accessibility text sizes, the tutorial and chore names are no longer cut off.
- With larger text sizes, the recording screen shows chores in a single column and keeps the record button area compact, so more of the list fits on screen.
- Text and icons on the History and splash screens now scale with your text size setting.
- Fixed numbers on the Monthly Summary that were hard to read in Dark Mode.

Fixes
- Fixed an issue in the tutorial where the Record button for the selected chore could be hidden off screen.

Thank you for using Otetsudai Coin!
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `MARKETING_VERSION` = `1.1.5` (公開中 1.1.4・基準タグ v1.1.4 より高い。pbxproj 6 箇所すべて) ← ITMS-90186 / 90062 対策
- [x] `CURRENT_PROJECT_VERSION` = `124` (Xcode Cloud が採番するので下限。実ビルドは 135) ← ITMS-90478 対策
- [ ] `release-version-bump-check.yml` が green
- [x] main でユニットテストが green (#266 の 3eea2a3 で 565/565。xcresult の summary で確認)
- [ ] ja / en 両方のロケールで起動を確認

### App Store Connect

- [x] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK (2026-10-18)
- [x] バージョン `1.1.5` を作成、ビルドを紐付け (build **135**。輸出コンプライアンス等のダイアログは出なかった)
- [x] What's New (ja § 2.1 / en § 2.3)・審査ノート (§ 2.2) を入力。プロモーションテキストは新バージョンで ja / en とも空になっていたため、1.1.4 の値 (v1.1.4 手順書 § 2.2 と一致) を入れ直した。すべて保存後に再読み込みして全文一致を確認
- [x] 年齢制限: 「広告」=「はい」(2026-10-18 に読み取りで確認)。ソーシャルメディア関連の 2 問は、公開中 1.1.4 の閲覧ダイアログでは未回答に見えたが、オーナーの判断では回答済み (人)
- [ ] App Privacy・輸出コンプライアンスを確認 (人) ※ 提出時に警告・ダイアログは出なかった (内容の確認は未実施)

### 提出

- [x] 「審査用に追加」→「審査へ提出」(2026-10-18 18:48 頃、オーナーの承認を受けて Claude が操作。提出物は「iOSアプリ 1.1.5 (135)」の 1 件のみ。ASC の状態は「1.1.5 審査待ち」)

## 4. 完了後タスク

- [ ] **承認されたら**すぐ `git tag -a v1.1.5 -m "v1.1.5" <ビルド元 commit> && git push origin v1.1.5` (ビルド元は build 135 の `6f4e261`) (承認前にタグを打たない)
- [ ] **承認されたら**、次の version (1.1.6) への bump PR を他の PR より先に merge する (Xcode Cloud の train closed 対策、#235)
- [ ] 公開後に `scripts/release-status.sh` で 1.1.5 を実測
- [ ] GitHub Release を作成 (§ 2.1 / § 2.3)
- [ ] `release-retrospective` skill で振り返り (§ 5)
