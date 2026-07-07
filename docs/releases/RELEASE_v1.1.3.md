# おてつだいコイン v1.1.3 リリース手順

このドキュメントは v1.1.3 (Build 78) を App Store Connect へ提出するための手順書です。`RELEASE_v1.1.2.md` をベースに、v1.1.2 提出時に踏んだ ITMS-90186 / ITMS-90062 reject の経緯を反映しました。

## 0. 前提条件

- ✅ `main` HEAD に v1.1.2 用のコミット (PR #62 / #68 / #70 / #72 / #77 / #79 等) + #89 (PR #94) v1.1.3 en i18n 修正 が反映済み
- ✅ ASC のチーム承認・契約・税務情報が有効
- ✅ Bundle ID `com.asapapalab.OtetsudaiCoin` が ASC 上で v1.1.1 として公開済み
- ✅ Build Number: **78** (v1.1.2 で upload した Build 77 から +1)
- ✅ Marketing Version: **1.1.3** (前回承認済み 1.1.1 より高い、reject された 1.1.2 train も bypass)
- ✅ ASC Age Rating で「広告」=「はい」設定済み (#86 対策、AdMob 統合済みのため必須)

> 🧨 **重要な学び (v1.1.2 提出時に発生した ITMS リジェクトの記憶 — 2026-05-28)**
>
> v1.1.2 として Build 77 をアップロードしたが、ASC 側で「1.1.2 が既に approved 済み」と判定され以下 2 件で reject されました:
>
> - **ITMS-90186**: `Invalid Pre-Release Train - The train version '1.1.2' is closed for new build submissions`
> - **ITMS-90062**: `CFBundleShortVersionString [1.1.2] must contain a higher version than the previously approved version [1.1.2]`
>
> 原因: `MARKETING_VERSION = 1.1.2` のまま reject されない build を出そうとした (v1.1.2 train は ASC 側で先に approved されており closed)。
>
> 教訓: ASC train が closed になったら **必ず `MARKETING_VERSION` を bump して新しい train を作る**。本リリースでは v1.1.3 / Build 78 へ bump し、§ 3 のチェックリストで再確認します。`release-version-bump-check.yml` の CI gating も継続。
>
> 注: v1.1.0 → v1.1.1 でも同種のリジェクトを 1 度踏んでいる (`RELEASE_v1.1.2.md` § 0 参照)。同じ罠を 2 回踏んだことになるため、`release-version-bump-check` skill の存在意義が再確認された。

## 1. App Store Connect での操作フロー

### 1.1 新バージョン作成

1. ASC → 「お手伝いコイン」 → iOS App
2. v1.1.2 の draft が残っている場合は **削除** (closed train なので submit 不可)
3. 「+ バージョンまたはプラットフォーム」 → iOS App → バージョン番号 `1.1.3` を入力
4. 「作成」をクリック

### 1.2 ビルド選択

「ビルド」セクションで Build 78 を選択。Xcode → Product → Archive → Distribute App → App Store Connect の流れで再アップロード後、TestFlight に並ぶまで通常 10〜30 分かかる。

### 1.3 メタデータ入力

| フィールド                       | v1.1.3 での扱い                                                                          |
|-------------------------------- |------------------------------------------------------------------------------------------|
| アプリ名 (ja)                    | 「おてつだいコイン」 (変更なし)                                                            |
| サブタイトル (ja)                 | 「子どもとつくる、お手伝い習慣」 (変更なし)                                                 |
| アプリ名 (en) / サブタイトル (en) | `RELEASE_v1.1.1_ASC_EN.md` § 1 / § 2 で確定したものを継続使用 (locale 確定済みなら変更不要) |
| プロモーションテキスト             | v1.1.2 ドラフトを継続流用可、または § 2.2 を使用                                            |
| 説明文                            | v1.1.1 から流用 (`RELEASE_v1.1.1_ASC_EN.md` § 3 の en も同様)                                |
| キーワード                        | 「おてつだい,お小遣い,記録,子供,家事,習慣,しつけ,家族」 (変更なし、en も § 4 を継続)        |
| サポート URL                      | <https://es0612.github.io/OtetsudaiCoin/>                                                |
| マーケティング URL                | (任意、未設定で可)                                                                        |
| ライセンス契約                     | (Apple 標準を使用)                                                                       |
| **このバージョンの新機能 (ja)**     | **§ 2.1 のドラフトを使用 (v1.1.2 の内容 + #89 en i18n 修正)**                              |
| **このバージョンの新機能 (en)**     | **§ 2.5 のドラフトを使用**                                                                |

### 1.4 スクリーンショット

`docs/screenshots/asc/v1.1.x/{ja,en}/` の最新スクショ (#89 修正反映後、b0c106c で再撮影済み) を使用。撮り直しが必要なら `./scripts/capture-asc-screenshots.sh` を実行。

### 1.5 App Privacy

v1.1.2 から変更なし。AdMob (Non-personalized) 申告内容はそのまま使用。

> ⚠️ **Age Rating の "Advertising" content descriptor は必ず "Yes" に設定**
>
> v1.1.2 提出時 (2026-05-23) に Age Rating "Advertising" が No のままで一度 reject されている (Issue #86)。v1.1.0 以降は **常に Advertising=Yes**。ASC → アプリ → 「App 情報」 → 「年齢制限指定」 → 「編集」 → 「広告」 → **「はい」** を選択 → 保存。

### 1.6 価格・配信地域

変更なし (無料 / 全地域)。

### 1.7 ATT / IDFA 申告

v1.1.1 / v1.1.2 と同じ。IDFA は「いいえ」のままで提出可。

### 1.8 エクスポートコンプライアンス

v1.1.1 / v1.1.2 と同じ。「使用しません (exempt)」を選択。

### 1.9 「審査へ提出」

すべての項目が緑チェックになったら「審査へ提出」をクリック。通常 24〜48 時間で結果が返る。

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja — **必須**

> v1.1.1 → v1.1.3 の差分。v1.1.2 は ASC 公開に至らなかったため、user 視点では v1.1.1 → v1.1.3 として What's New を構成する。

#### ドラフト A — 絵文字付き親しみ版 (推奨)

```text
バージョン 1.1.3 では、お手伝い記録をもっと素早く、もっと安心して使えるようにアップデートしました ✨

✨ 新機能
・お手伝いを複数選んで一括で記録できる「一括モード」を追加しました。お手伝いが終わってからまとめて記録したいときに便利です
・同じ日に同じお手伝いをすでに記録している場合、お手伝いタスクのカードに「すでに○件記録済み」と表示し、重複記録を防ぎやすくなりました

🐛 不具合修正
・お手伝い履歴や月別履歴のシートを初めて開いたときに、内容が表示されないことがある問題を修正しました

🌍 英語対応の強化
・アラートメッセージ、初期のお手伝いタスク名、件数表記、設定画面、お子様カードの英訳と表示崩れを修正し、英語環境でもより自然にご利用いただけるようになりました

引き続きおてつだいコインを楽しんでお使いください！
```

#### ドラフト B — シンプル箇条書き版

```text
バージョン 1.1.3 の更新内容:

・お手伝いを複数選んで一括で記録できる「一括モード」を追加
・同日同タスクの重複記録時に「すでに○件記録済み」の警告ラベルを表示
・お手伝い履歴・月別履歴のシート初回表示で内容が出ない不具合を修正
・アラート / 初期タスク名 / 設定画面 / お子様カードの英訳と表示崩れを修正
```

### 2.2 プロモーションテキスト (170 字、オプション、申請後も更新可)

v1.1.2 のものを流用可。

**ja**:

```text
お手伝いを複数選んで一括で記録できる「一括モード」を追加。同じ日の重複記録も視覚的に防げるようになり、お子様の頑張りをもっとスムーズに残せます。
```

**en**:

```text
New Bulk Mode lets you record several chores at once. Same-day duplicates now show an "already recorded" hint, so logging chores stays effortless.
```

Character count: **146 / 170 chars**.

### 2.3 説明文 (最新化案、必須ではない)

v1.1.0 の説明文 (`RELEASE_v1.1.0.md` § 2.3) を引き続き使用可。英語ロケール版は `RELEASE_v1.1.1_ASC_EN.md` § 3 を継続。

### 2.4 審査ノート (Review Notes、必要に応じて)

```text
v1.1.3 の主な変更点 (v1.1.1 → v1.1.3):
- New feature: 「一括モード」 — RecordView 上のトグルで複数のお手伝いタスクを選択し、一度に記録できます (#69)
- UX: 同日同タスクの重複記録時にタスクカードへ「すでに○件記録済み」を表示 (#73)
- Bug fix: お手伝い履歴 / 月別履歴シートの初回表示で空になる問題を修正 (#54)
- Localization: アラート文・初期タスク名・件数表記の英訳を追加 (#53 P2)、設定画面 / お子様カードの英訳と表示崩れを修正 (#89)

Note: v1.1.2 (Build 77) was uploaded earlier but rejected with ITMS-90186 / 90062 due to a missed version bump. This v1.1.3 (Build 78) submission resolves that by bumping MARKETING_VERSION.

If you would like to verify the English localization, please run the app with system language set to English.
```

### 2.5 What's New (en) — **必須**

> ⚠️ **絵文字は使用不可** (Issue #85): ASC 英語ロケーションは Description / What's New の絵文字を automated reject する。本 § のテキストは全て plain text。`§ 2.1` の ja draft は絵文字維持で OK。

```text
Version 1.1.3 makes recording chores faster and more reliable.

New
- Added Bulk Mode — pick multiple chores and record them in one go. Great for logging chores in batches after the kids are done.
- When a chore is already recorded for the same day, the task card now shows an "Already recorded N time(s)" badge so it's easy to avoid double-logging.

Bug fixes
- Fixed an issue where the chore history and monthly history sheets could appear empty the first time they were opened.

Improved English support
- Added English translations for alert messages, the default help task names, and count phrases (one / other variants).
- Fixed several truncated and untranslated labels in Settings and the child selection card so the UI reads more naturally in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it with your family!
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `main` HEAD に v1.1.3 用のコミットが反映済み (#89 / PR #94 まで含む)
- [x] **`MARKETING_VERSION` が `1.1.3` (前回承認済み `1.1.1` より高い、reject 済み `1.1.2` train も bypass) であること** ← ITMS-90062 対策
- [x] **`CURRENT_PROJECT_VERSION` が `78` (前回アップロード Build 77 より高い) であること** ← ITMS-90186 / 90478 対策
- [x] `release-version-bump-check.yml` (#55 で導入) が緑になっていること
- [ ] ユニットテストが green (`xcodebuild test -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17'`)
- [ ] iOS シミュレータで ja/en 両ロケール起動を目視確認

### App Store Connect

- [ ] 既存の v1.1.2 draft を削除 (closed train)
- [ ] 新バージョン `1.1.3` を作成
- [ ] Build 78 を選択
- [ ] 「このバージョンの新機能 (ja)」に § 2.1 のドラフトを貼り付け
- [ ] 「このバージョンの新機能 (en)」に § 2.5 のドラフトを貼り付け
- [ ] (任意) 一括モード / 重複警告 のスクショを撮り直し
- [ ] 審査ノートに § 2.4 を貼り付け
- [ ] **Age Rating で「広告」=「はい」になっていることを確認** ← #86 対策

### 提出

- [ ] すべて緑チェック → 「審査へ提出」

## 4. よくある reject 理由と対策

### 4.1 ITMS-90062 / ITMS-90186 (バージョン関連)

**症状**: 「previously approved version より version string が高くない」「train が closed」

**対策**: pbxproj の `MARKETING_VERSION` を bump する。v1.1.0 → v1.1.1 と v1.1.2 → v1.1.3 の **2 回** 同じ罠を踏んでいる。`release-version-bump-check.yml` (#55) が CI 側でも gating する。本リリースでは [[release-version-bump-check]] skill を release PR 作成時に必ず invoke する運用を再徹底。

### 4.2 「プライバシーポリシーが App の挙動と一致しない」

v1.1.0 / v1.1.1 / v1.1.2 と同じ対応。

### 4.3 「Kids カテゴリ要件を満たしていない」

v1.1.0 / v1.1.1 / v1.1.2 と同じ。アプリは Kids カテゴリには登録していないので通常は該当しない。

### 4.4 Age Rating の Advertising 設定漏れ (Issue #86)

詳細は `RELEASE_v1.1.2.md` § 4.4 を参照。v1.1.2 で既に対応済みの想定だが、ASC 上で No に戻っていないか提出前に再確認する。

### 4.5 英語ロケーションの絵文字 (Issue #85)

en Description / What's New に絵文字を入れない。本ドキュメント § 2.5 は plain text 準拠。

## 5. 完了後タスク

- [ ] App Store 公開後、`main` に `v1.1.3` annotated タグを作成・push (`git tag -a v1.1.3 -m "v1.1.3" && git push origin v1.1.3`)
- [ ] GitHub Release を作成 (タイトル: `v1.1.3`, body: § 2.1 ja ドラフトを流用、英文も合わせて記載すると◎)
- [ ] 対応 issue (#89 / その他 v1.1.2 で close 漏れの issue) を `gh issue close <N> --reason completed --comment "v1.1.3 でリリース"` で処理
- [ ] v1.1.1 用の GitHub Release を「Latest」マークから外し、v1.1.3 をマーク
- [ ] `release-retrospective` skill を実行 (v1.1.2 → v1.1.3 の reject と再提出フローの振り返り、特に **同じ ITMS reject を 2 回踏んだ理由** を skill/CI で更にどう塞ぐか検討)

## 6. 振り返り (Retrospective)

> 本セクションはリリース完了後に `release-retrospective` skill で生成される。マージ前は空欄のまま。
> 関連 PR の取り込み範囲: v1.1.2 で予定していた全 PR + **#94** (#89 en i18n + UI truncation 修正)
