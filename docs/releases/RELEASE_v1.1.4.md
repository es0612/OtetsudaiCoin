# v1.1.4 リリース手順書

このドキュメントは v1.1.4 を App Store Connect (ASC) へ提出するための手順書です。ASC への入力は `asc-submission-prep` skill (Chrome 経路) で行い、「審査へ提出」だけを人が押します。追跡 issue: #225。

## 0. 前提条件

- ASC で公開中: **1.1.2** (ビルド 72、2026-05-24 公開)。2026-09-27 に iTunes Lookup API と ASC 配信タブで実測
- **1.1.3 は一度も提出していない** (`v1.1.3` タグと `RELEASE_v1.1.3.md` はあるが、ASC にバージョンレコードが無い)。1.1.3 用の変更は本リリースにすべて含める
- Marketing Version: **1.1.4** (公開中 1.1.2 より高く、CI gate の基準タグ `v1.1.3` よりも高い)
- Build Number: pbxproj は **119** (TestFlight 上の 1.1.3 ビルドの最新 118 から +1)。Xcode Cloud は独自に採番するので、実際に紐付けるビルド番号は TestFlight で確認する
- ASC Age Rating で「広告」=「はい」(#86、AdMob 統合済みのため必須)

> 着手前に公開中の version を実測する (CLAUDE.md「公開中の version を実測」ルール):
>
> ```bash
> curl -s "https://itunes.apple.com/lookup?id=6747692379&country=jp" | jq -r '.results[0] | .version, .currentVersionReleaseDate'
> ```

## 1. App Store Connect での作業 (`asc-submission-prep`)

| 手順 | 担当 | 備考 |
|---|---|---|
| dry-run で差分表を作る | Claude | 書き込み 0 件 |
| 差分表の一括 OK | 人 | 表に無い書き込みはしない |
| バージョン `1.1.4` の作成 | Claude (OK 後) | 作成したバージョンは消せない |
| What's New (ja / en)・プロモーションテキストの入力 | Claude (OK 後) | § 2 の文面 |
| en スクショの反映 | Claude (OK 後) | § 1.1 |
| ビルドの紐付け | Claude (OK 後) | バージョン 1.1.4・提出準備完了の最新ビルド |
| 年齢制限の新しい質問 (ソーシャルメディア関連)・App Privacy・輸出コンプライアンス | **人** | 申告なので Claude は回答しない。輸出コンプライアンスは従来どおり「使用しません (exempt)」、ATT / IDFA は「いいえ」 |
| 「審査用に追加」→「審査へ提出」 | **人** | |

### 1.1 スクリーンショット

- `./scripts/capture-asc-screenshots.sh` で ja / en の 3 画面を撮り直した (#218 で撮影時は light 固定)。出力は `docs/screenshots/asc/v1.1.x/{ja,en}/`
- **ja**: ASC にはデザイン済みのマーケティング画像 (黄色背景 + 見出し付き) が入っているため、生のスクショでは置き換えない
- **en**: ASC では ja 6.9" の画像を流用している (en 用は未登録、#50)。en の生スクショを登録するかどうかは差分表の確認時に決める

### 1.2 変更しない項目

アプリ名・サブタイトル・説明文・キーワード・サポート URL・価格・配信地域は変更しない。en の説明文とキーワードは `fastlane/metadata/en-US/` と ASC の内容が一致している (2026-09-27 に字数で確認)。

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja

> 対象は 1.1.2 (公開中) → 1.1.4 の差分。1.1.2 で案内済みの「一括モード」「重複記録の警告」は含めない。
>
> ⚠️ **ja でも絵文字は使えない (2026-09-27 実測)**: ✨🎨🐛 を含めると ASC が「このフィールドには1つ以上の無効な文字が含まれています」で保存を拒否した。🎨 を外しても ✨🐛 で同じエラー (v1.1.1 では ✨🐛🌍 が通っていた)。見出しは【】で表す。下の文面は ASC に保存した版。

```text
バージョン 1.1.4 では、お手伝いの記録をもっと楽しく、見やすくするアップデートをまとめてお届けします

【新機能】
・お手伝いに絵文字アイコンを付けられるようになりました。お手伝いの追加・編集画面で好きな絵文字を選べます
・お手伝いの並び順を自由に入れ替えられるようになりました。「よく使う順」ボタンで一発で並べ替えることもできます
・記録画面にカレンダーを追加しました。記録した日がひと目で分かります
・「月のまとめ」画面をリニューアルし、カレンダーとお小遣いの支払いを 1 つの画面で確認できるようになりました
・記録やお手伝いを選んだときに、振動で手ごたえが伝わるようになりました。設定画面の「サウンドと触覚」で効果音と振動をそれぞれオン/オフできます

【デザインの改善】
・アプリ全体の色をオレンジを基調にしたデザインに刷新し、お子様のアイコンの色も 12 色から選べるようになりました
・ダークモードと大きな文字サイズでの見やすさを改善しました

【不具合修正と改善】
・記録画面でタブを切り替えると、選択していた内容がリセットされる問題を修正しました
・通知の設定に失敗したときに、お知らせを表示するようにしました
・英語表示で、お手伝いの名前や日付・時刻の表記が日本語のままになる問題を修正しました
・お小遣いの支払い履歴の保存方式を改善しました

引き続きおてつだいコインを楽しんでお使いください！
```

### 2.2 プロモーションテキスト (170 字以内、申請後も更新可)

**ja**:

```text
お手伝いに絵文字アイコンを付けて、記録をもっと楽しく。記録画面のカレンダーで、がんばった日がひと目で分かります。
```

**en** (plain text, no emojis):

```text
Give each chore its own emoji and see every recorded day on the new calendar. Recording chores is now more fun and easier to follow.
```

### 2.3 審査ノート (Review Notes)

```text
v1.1.4 の主な変更点 (公開中の v1.1.2 からの差分):
- タスクの絵文字アイコンと絵文字ピッカー
- タスクの並べ替え (ドラッグ / よく使う順)
- 記録画面のカレンダー、月のまとめ画面の刷新
- 触覚フィードバックの追加と、効果音・触覚の ON/OFF トグル (設定画面)
- 配色の刷新、ダークモード / Dynamic Type の改善
- 英語表示の改善

This app does not require sign-in. No children are pre-registered (default chores are); please add a child from the Home screen or the Settings tab to try recording chores.
If you would like to verify the English localization, please run the app with the system language set to English.
```

### 2.4 What's New (en)

> ⚠️ **plain text only, no emojis** (#85)。

```text
Version 1.1.4 brings a round of updates that make recording chores more fun and easier to follow.

New
- Chores can now have emoji icons. Pick any emoji when you add or edit a chore.
- Reorder your chores freely, or sort them by how often they are used with one tap.
- The recording screen now has a calendar, so you can see at a glance which days have records.
- The Monthly Summary screen has been redesigned to show the calendar and allowance payments together.
- Added haptic feedback when you record or select chores. Sound effects and haptics can each be turned on or off under Sound & Haptics in Settings.

Design
- Refreshed the app's colors around a warm orange theme, with 12 new avatar colors for your children.
- Improved readability in Dark Mode and with larger text sizes.

Fixes and improvements
- Fixed an issue where switching tabs reset the selection on the recording screen.
- The app now shows a message when setting up a notification fails.
- Fixed chore names, dates and times that stayed in Japanese when the app is used in English.
- Improved how allowance payment history is stored.

Thank you for using Otetsudai Coin!
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `MARKETING_VERSION` = `1.1.4` (公開中 1.1.2・基準タグ v1.1.3 より高い) ← ITMS-90062 対策
- [x] `CURRENT_PROJECT_VERSION` = `119` (TestFlight 最新 118 より高い) ← ITMS-90186 / 90478 対策
- [ ] `release-version-bump-check.yml` が green
- [ ] ユニットテストが green
- [ ] **Core Data の上書きインストール確認 (必須)**: 1.1.2 (model **v1**、支払い履歴は **UserDefaults**) をインストールしたシミュレータで、お子様・お手伝い・記録・支払いのデータを作る → 1.1.4 のビルドを上書きインストールして起動 → (a) クラッシュしない、(b) お子様・記録・支払い履歴が消えていない、(c) お手伝いに絵文字アイコンが表示される (v4 の icon 属性)、を目視確認する。v1 → v4 の 3 段移行 (#122 v2 / #142 v3 / #148 v4) と、支払い履歴の UserDefaults → Core Data 移行 (#142) の初出荷
- [ ] ja / en 両方のロケールで起動を確認

### App Store Connect

- [ ] `asc-submission-prep` の dry-run 差分表を確認し、一括 OK
- [ ] バージョン `1.1.4` を作成、ビルドを紐付け
- [ ] What's New (ja § 2.1 / en § 2.4)・プロモーションテキスト (§ 2.2)・審査ノート (§ 2.3) を入力
- [ ] 年齢制限: 「広告」=「はい」、ソーシャルメディア関連の新しい質問に回答 (人)
- [ ] App Privacy・輸出コンプライアンスを確認 (人)

### 提出

- [ ] 「審査用に追加」→「審査へ提出」(人)

## 4. 完了後タスク

- [ ] **承認されたら**すぐ `git tag -a v1.1.4 -m "v1.1.4" && git push origin v1.1.4` (承認前にタグを打たない。v1.1.3 はタグだけ先行して出荷と誤認された)
- [ ] GitHub Release を作成 (§ 2.1 / § 2.4)
- [ ] #225 を close、#50 の残り (en スクショ・What's New) を反映できていれば #50 も close
- [ ] `release-retrospective` skill で振り返り

## 5. 振り返り (Retrospective)

> リリース完了後に `release-retrospective` skill で記入する。
