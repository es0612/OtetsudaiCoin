# おてつだいコイン v1.1.1 リリース手順

このドキュメントは v1.1.1 (Build 48 想定) を App Store Connect へ提出するための手順書です。`RELEASE_v1.1.0.md` をベースに更新しています。

## 0. 前提条件

- ✅ `main` HEAD に v1.1.1 用のコミット (バージョン bump + #44/#45/#43 対応) が反映済み
- ✅ ASC のチーム承認・契約・税務情報が有効
- ✅ Bundle ID `com.asapapalab.OtetsudaiCoin` が ASC 上で v1.1.0 として公開済み
- ✅ Build Number: 48
- ✅ Marketing Version: 1.1.1

> 🧨 **重要な学び (v1.1.0 → v1.1.1 で発生した ITMS リジェクト)**
>
> v1.1.0 が審査通過後、同じ `MARKETING_VERSION = 1.1.0` のまま Build 47 をアップロードしたところ次の 2 件で reject されました:
>
> - **ITMS-90186**: `The train version '1.1.0' is closed for new build submissions`
> - **ITMS-90062**: `CFBundleShortVersionString [1.1.0] must contain a higher version than the previously approved version [1.1.0]`
>
> 教訓: **新しい変更を出すときは必ず `MARKETING_VERSION` を bump する**。リリース手順書を v1.1.1 として独立させ、提出前チェックリストにも「pbxproj の MARKETING_VERSION / CURRENT_PROJECT_VERSION が前回 ASC で承認済みの値より上がっているか」を必須項目として残します。

## 1. App Store Connect での操作フロー

### 1.1 新バージョン作成

1. ASC → 「お手伝いコイン」 → iOS App
2. 「+ バージョンまたはプラットフォーム」 → iOS App → バージョン番号 `1.1.1` を入力
3. 「作成」をクリック

### 1.2 ビルド選択

「ビルド」セクションで Build 48 を選択 (TestFlight で配信済みのもの)。Xcode → Product → Archive → Distribute App → App Store Connect の流れで再アップロード後、TestFlight に並ぶまで通常 10〜30 分かかる。

### 1.3 メタデータ入力

| フィールド | v1.1.1 での扱い |
| --- | --- |
| アプリ名 | 「おてつだいコイン」 (変更なし) |
| サブタイトル | 「子どもとつくる、お手伝い習慣」 (変更なし) |
| プロモーションテキスト | v1.1.0 と同じで可、または § 2.2 のドラフトを使用 |
| 説明文 | v1.1.0 から流用、または § 2.3 のドラフトを使用 |
| キーワード | 「おてつだい,お小遣い,記録,子供,家事,習慣,しつけ,家族」 (変更なし) |
| サポート URL | <https://es0612.github.io/OtetsudaiCoin/> |
| マーケティング URL | (任意、未設定で可) |
| ライセンス契約 | (Apple 標準を使用) |
| **このバージョンの新機能** | **§ 2.1 のドラフトを使用 (v1.1.1 用に書き直し)** |

### 1.4 スクリーンショット

v1.1.0 のスクショを基本流用可。今回の v1.1.1 では UI レイアウト自体に大きな変化はないため撮り直し不要。**ただし英語ロケール用のスクショを新規追加すると◎**:

- 推奨: 6.7 inch (iPhone 15 Pro Max / 17 Pro Max) のホーム画面 (英語ロケール) を 1 枚追加
- 撮影手順:
  - `xcrun simctl launch <SIM_ID> com.asapapalab.OtetsudaiCoin -AppleLanguages '(en)' -AppleLocale en_US`
  - 起動後にホーム画面で `xcrun simctl io <SIM_ID> screenshot path/to/en_home.png`

### 1.5 App Privacy

v1.1.0 から変更なし。AdMob (Non-personalized) 申告内容 (Identifier、Diagnostics 等) はそのまま使用。

### 1.6 価格・配信地域

変更なし (無料 / 全地域)。

### 1.7 ATT / IDFA 申告

v1.1.0 と同じ。AdMob は SDK 同梱だが personalized ads off の運用なので IDFA は「いいえ」のままで提出可。

### 1.8 エクスポートコンプライアンス

v1.1.0 と同じ。「使用しません (exempt)」を選択。

### 1.9 「審査へ提出」

すべての項目が緑チェックになったら「審査へ提出」をクリック。通常 24〜48 時間で結果が返る。

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — **必須**

> ASC では 4000 字制限。最初の 170 字程度が App Store の更新欄で「もっと見る」前に表示されるため、要点を冒頭に配置。

#### ドラフト A — 絵文字付き親しみ版 (推奨)

```text
バージョン 1.1.1 では、ホーム画面の安定性と英語対応を強化しました ✨

🐛 不具合修正
・ホーム画面を初回表示したときに、お子様のカードや統計がうまく表示されないことがある問題を改善しました
・設定画面の「バージョン」欄に古い番号が出ていた問題を修正し、現在のバージョン (1.1.1) が正しく表示されるようになりました

🌍 英語対応の強化
・タブラベル (ホーム / 記録 / 設定)、月の振り返り画面、設定画面の各セクション、通知設定、リマインダー通知の本文を英語環境でも自然に表示できるよう翻訳を追加・改善しました

引き続きおてつだいコインを楽しんでお使いください！
```

#### ドラフト B — シンプル箇条書き版

```text
バージョン 1.1.1 の更新内容:

・ホーム画面の初回表示で空表示になることがある不具合を修正
・設定画面のバージョン番号表示を修正 (現在のバージョンを正しく表示)
・タブ・月の振り返り・設定・通知関連の英語対応を強化
```

### 2.2 プロモーションテキスト (170 字、オプション、申請後も更新可)

v1.1.0 のものを流用可。差し替える場合は以下のドラフト。

```text
ホーム画面の起動時の表示を安定化し、英語表示にもしっかり対応。海外暮らしのご家族や英語で育児するご家庭でも、お子様と一緒にお手伝い習慣を続けられます。
```

### 2.3 説明文 (最新化案、必須ではない)

v1.1.0 の説明文 (`RELEASE_v1.1.0.md` § 2.3) を引き続き使用可。英語ロケールユーザー向けの加筆を行う場合は、英訳ローカリゼーションを ASC の「ローカリゼーション」セクションに追加し、英語版の説明文・キーワード・スクショを別途登録する。

### 2.4 審査ノート (Review Notes、必要に応じて)

v1.1.0 のノートに以下を追記すると審査時の混乱を避けやすい:

```text
v1.1.1 の主な変更点:
- Bug fix: ホーム画面初回表示の空表示対策 (HomeView の .task 化)
- Bug fix: 設定画面のバージョン表示を Bundle.main から動的取得するよう修正
- Localization: タブラベル、月の振り返り画面、設定画面、通知関連の英訳を追加。英語ロケールでも自然な表示になります。

If you would like to verify the English localization, please run the app with system language set to English.
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `main` HEAD に v1.1.1 用のバージョン bump コミット
- [x] **`MARKETING_VERSION` が `1.1.1` (前回承認済みの `1.1.0` より高い) であること** ← ITMS-90062 対策
- [x] **`CURRENT_PROJECT_VERSION` が `48` (前回 reject された Build 47 より高い) であること** ← ITMS-90186 対策
- [x] ユニットテストが green (`xcodebuild test -scheme OtetsudaiCoin`)。`LocalizationStringCatalogTests/testAllKeysHaveEnglishTranslation` の P2 範囲漏れ 20 件は既知で別 issue
- [x] iOS シミュレータで ja/en 両ロケール起動を目視確認

### App Store Connect

- [ ] 新バージョン `1.1.1` を作成
- [ ] Build 48 を選択
- [ ] 「このバージョンの新機能」に § 2.1 のドラフトを貼り付け
- [ ] (任意) 英語ロケール用スクショを追加
- [ ] 審査ノートに § 2.4 を貼り付け

### 提出

- [ ] すべて緑チェック → 「審査へ提出」

## 4. よくある reject 理由と対策

### 4.1 ITMS-90062 / ITMS-90186 (バージョン関連)

**症状**: 「previously approved version より version string が高くない」「train が closed」

**対策**: pbxproj の `MARKETING_VERSION` を bump する。新リリース毎に必ず上げる。CI でチェックする hook を入れるのも一案。

### 4.2 「プライバシーポリシーが App の挙動と一致しない」

v1.1.0 と同じ対応 (`PRIVACY_POLICY.md` を最新化、ASC の App Privacy セクションで AdMob (Non-personalized) を申告)。

### 4.3 「Kids カテゴリ要件を満たしていない」

v1.1.0 と同じ。アプリは Kids カテゴリには登録していないので通常は該当しない。万一指摘されたら「年齢レーティング 4+」「Made for Kids」フラグを確認。

## 5. 完了後タスク

- [ ] App Store 公開後、`main` に `v1.1.1` annotated タグを作成・push
- [ ] GitHub Release を作成 (タイトル: `v1.1.1`, body: § 2.1 ドラフトを流用)
- [ ] 対応 issue (#44/#45/#43) のうちまだクローズされていないものを `gh issue close <N> --reason completed --comment "v1.1.1 でリリース"` で処理
- [ ] (任意) v1.1.0 用の GitHub Release を「Latest」マークから外し、v1.1.1 をマーク

## 付録: バージョン bump 漏れ防止のための運用案

今回のリジェクトの根本原因は「PR 単位でリリース版とリンクするときに pbxproj の version 反映を忘れた」こと。再発防止策として:

1. **リリース PR のテンプレに「pbxproj version 確認」チェック項目を入れる**
2. **CI で `MARKETING_VERSION` が前回タグの値より大きいかを check** (GitHub Action で `git describe --tags --abbrev=0` の値と pbxproj を比較)
3. **作業用スキル (xcstrings-bulk-update に並ぶ「release-version-bump skill」) として手順を残す**
