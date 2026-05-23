# おてつだいコイン v1.1.2 リリース手順

このドキュメントは v1.1.2 (Build 53 想定) を App Store Connect へ提出するための手順書です。`RELEASE_v1.1.1.md` をベースに更新しています。

## 0. 前提条件

- ✅ `main` HEAD に v1.1.2 用のコミット (PR #62 / #68 / #70 / #72 / #77 / #79 等) が反映済み
- ✅ ASC のチーム承認・契約・税務情報が有効
- ✅ Bundle ID `com.asapapalab.OtetsudaiCoin` が ASC 上で v1.1.1 として公開済み
- ✅ Build Number: **53** (v1.1.2 のひとつ前のアップロード Build 52 から +1)
- ✅ Marketing Version: **1.1.2** (前回承認済み 1.1.1 より高い)
- ✅ ASC Age Rating で「広告」=「はい」設定済み (#86 対策、AdMob 統合済みのため必須)

> 🧨 **重要な学び (前リリース v1.1.0 → v1.1.1 で発生した ITMS リジェクトの記憶)**
>
> v1.1.0 承認後、同じ `MARKETING_VERSION = 1.1.0` のまま Build 47 をアップロードして次の 2 件で reject されました:
>
> - **ITMS-90186**: `The train version '1.1.0' is closed for new build submissions`
> - **ITMS-90062**: `CFBundleShortVersionString [1.1.0] must contain a higher version than the previously approved version [1.1.0]`
>
> 教訓: **新しい変更を出すときは必ず `MARKETING_VERSION` を bump する**。本リリース手順書では v1.1.2 への bump と Build 53 への bump を § 3 のチェックリストに必須項目として残しています。CI でも `release-version-bump-check.yml` が pbxproj の値を gating します。

## 1. App Store Connect での操作フロー

### 1.1 新バージョン作成

1. ASC → 「お手伝いコイン」 → iOS App
2. 「+ バージョンまたはプラットフォーム」 → iOS App → バージョン番号 `1.1.2` を入力
3. 「作成」をクリック

### 1.2 ビルド選択

「ビルド」セクションで Build 53 を選択 (TestFlight で配信済みのもの)。Xcode → Product → Archive → Distribute App → App Store Connect の流れで再アップロード後、TestFlight に並ぶまで通常 10〜30 分かかる。

### 1.3 メタデータ入力

| フィールド                       | v1.1.2 での扱い                                                                          |
|-------------------------------- |------------------------------------------------------------------------------------------|
| アプリ名 (ja)                    | 「おてつだいコイン」 (変更なし)                                                            |
| サブタイトル (ja)                 | 「子どもとつくる、お手伝い習慣」 (変更なし)                                                 |
| アプリ名 (en) / サブタイトル (en) | `RELEASE_v1.1.1_ASC_EN.md` § 1 / § 2 で確定したものを継続使用 (locale 確定済みなら変更不要) |
| プロモーションテキスト             | v1.1.1 のものを流用可、または § 2.2 のドラフトを使用                                        |
| 説明文                            | v1.1.1 から流用 (`RELEASE_v1.1.1_ASC_EN.md` § 3 の en も同様)                                |
| キーワード                        | 「おてつだい,お小遣い,記録,子供,家事,習慣,しつけ,家族」 (変更なし、en も § 4 を継続)        |
| サポート URL                      | <https://es0612.github.io/OtetsudaiCoin/>                                                |
| マーケティング URL                | (任意、未設定で可)                                                                        |
| ライセンス契約                     | (Apple 標準を使用)                                                                       |
| **このバージョンの新機能 (ja)**     | **§ 2.1 のドラフトを使用**                                                                |
| **このバージョンの新機能 (en)**     | **§ 2.5 のドラフトを使用 (Phase 2 of #50 — リリース手順への英訳組み込み、初実践)**         |

### 1.4 スクリーンショット

v1.1.1 のスクショを基本流用可。今回 v1.1.2 で大きな UI 構造変化は無いが、以下は撮り直すと◎:

- **一括モード ON 時の RecordView** (新機能、#69) — 「一括モード」トグルの ON 状態と複数選択 indicator を含む構図
- **重複記録警告ラベル** (#73) — タスクカードに「すでに○件記録済み」が表示されている状態

英語ロケール用スクショは未着手 (#50 § 1.5 で deferred)。今リリースでも別 PR で対応するか継続 defer。

### 1.5 App Privacy

v1.1.1 から変更なし。AdMob (Non-personalized) 申告内容はそのまま使用。なお #49 で AdMob バナーが RecordView スクロール末端にも追加されたが、申告対象データ (識別子) は不変なので Privacy 申告自体に変更は不要。

> ⚠️ **Age Rating の "Advertising" content descriptor は必ず "Yes" に設定**
>
> v1.1.2 提出時 (2026-05-23) に「AdMob を統合しているのに Age Rating の Advertising が No」で automated reject (Issue #86)。AdMob を組み込んだ v1.1.0 以降は **常に Advertising=Yes**。設定箇所は ASC → アプリ → 「App 情報」 → 「年齢制限指定」 → 「編集」 → 「広告」 → **「はい」** を選択 → 保存。Age Rating 結果が 4+ → 4+ (変更なし) でも申告自体は更新する必要がある。

### 1.6 価格・配信地域

変更なし (無料 / 全地域)。

### 1.7 ATT / IDFA 申告

v1.1.1 と同じ。IDFA は「いいえ」のままで提出可。

### 1.8 エクスポートコンプライアンス

v1.1.1 と同じ。「使用しません (exempt)」を選択。

### 1.9 「審査へ提出」

すべての項目が緑チェックになったら「審査へ提出」をクリック。通常 24〜48 時間で結果が返る。

## 2. 文言ドラフト

### 2.1 このバージョンの新機能 (What's New) — ja — **必須**

> ASC では 4000 字制限。最初の 170 字程度が App Store の更新欄で「もっと見る」前に表示されるため、要点を冒頭に配置。

#### ドラフト A — 絵文字付き親しみ版 (推奨)

```text
バージョン 1.1.2 では、お手伝い記録をもっと素早く、もっと安心して使えるようにアップデートしました ✨

✨ 新機能
・お手伝いを複数選んで一括で記録できる「一括モード」を追加しました。お手伝いが終わってからまとめて記録したいときに便利です
・同じ日に同じお手伝いをすでに記録している場合、お手伝いタスクのカードに「すでに○件記録済み」と表示し、重複記録を防ぎやすくなりました

🐛 不具合修正
・お手伝い履歴や月別履歴のシートを初めて開いたときに、内容が表示されないことがある問題を修正しました

🌍 英語対応の強化
・アラートメッセージ、初期のお手伝いタスク名、件数表記などの細かい英訳を追加し、英語環境でもより自然にご利用いただけるようになりました

引き続きおてつだいコインを楽しんでお使いください！
```

#### ドラフト B — シンプル箇条書き版

```text
バージョン 1.1.2 の更新内容:

・お手伝いを複数選んで一括で記録できる「一括モード」を追加
・同日同タスクの重複記録時に「すでに○件記録済み」の警告ラベルを表示
・お手伝い履歴・月別履歴のシート初回表示で内容が出ない不具合を修正
・アラートや初期タスク名など、英語表示を拡充
```

### 2.2 プロモーションテキスト (170 字、オプション、申請後も更新可)

v1.1.1 のものを流用可。差し替える場合は以下のドラフト。

**ja**:

```text
お手伝いを複数選んで一括で記録できる「一括モード」を追加。同じ日の重複記録も視覚的に防げるようになり、お子様の頑張りをもっとスムーズに残せます。
```

**en** (v1.1.2 用、`RELEASE_v1.1.1_ASC_EN.md` § 5 の v1.1.1 版から差し替える場合):

```text
New Bulk Mode lets you record several chores at once. Same-day duplicates now show an "already recorded" hint, so logging chores stays effortless.
```

Character count: **146 / 170 chars**. 24 chars headroom.

> en promo は ASC submission 後でも編集可。v1.1.1 版 (`Stable home screen + English UI support…`) をそのまま継続する選択肢も有効 — 直近の v1.1.1 features が新規 / 復帰ユーザーには未だ訴求になるため。PO 判断。

### 2.3 説明文 (最新化案、必須ではない)

v1.1.0 の説明文 (`RELEASE_v1.1.0.md` § 2.3) を引き続き使用可。英語ロケール版は `RELEASE_v1.1.1_ASC_EN.md` § 3 を継続。

### 2.4 審査ノート (Review Notes、必要に応じて)

```text
v1.1.2 の主な変更点:
- New feature: 「一括モード」 — RecordView 上のトグルで複数のお手伝いタスクを選択し、一度に記録できます (#69)
- UX: 同日同タスクの重複記録時にタスクカードへ「すでに○件記録済み」を表示 (#73)
- Bug fix: お手伝い履歴 / 月別履歴シートの初回表示で空になる問題を修正 (#54)
- Localization: アラート文・初期タスク名・件数表記の英訳を追加 (#53 P2 完了)

If you would like to verify the English localization, please run the app with system language set to English.
```

### 2.5 What's New (en) — **必須** (Phase 2 of #50 — リリース手順への英訳組み込み、初実践)

> Phase 2 of Issue #50: "v1.1.2 以降は What's New 英訳をリリース手順に組み込む" 方針の初実装。
> 用語は xcstrings (`Localizable.xcstrings`) の en 訳と一致させること。今回の確認結果:
>
> - 「一括モード」→ `Bulk Mode` (UI 表示)
> - 「すでに %lld 件記録済み」→ `Already recorded %lld time(s)` (one/other plural)
> - ⚠️ **絵文字は使用不可** (Issue #85): ASC 英語ロケーションは Description / What's New の絵文字を automated reject する。本 § のテキストは全て plain text。`§ 2.1` の ja draft は絵文字維持で OK (実績あり)。

```text
Version 1.1.2 makes recording chores faster and more reliable.

New
- Added Bulk Mode — pick multiple chores and record them in one go. Great for logging chores in batches after the kids are done.
- When a chore is already recorded for the same day, the task card now shows an "Already recorded N time(s)" badge so it's easy to avoid double-logging.

Bug fixes
- Fixed an issue where the chore history and monthly history sheets could appear empty the first time they were opened.

Improved English support
- Added English translations for alert messages, the default help task names, and count phrases (one / other variants), so the app feels more natural in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it with your family!
```

## 3. 提出前チェックリスト

### コード / プロジェクト

- [x] `main` HEAD に v1.1.2 用のコミットが反映済み
- [x] **`MARKETING_VERSION` が `1.1.2` (前回承認済みの `1.1.1` より高い) であること** ← ITMS-90062 対策
- [x] **`CURRENT_PROJECT_VERSION` が `53` (前回アップロード Build 52 より高い) であること** ← ITMS-90186 / 90478 対策
- [x] `release-version-bump-check.yml` (#55 で導入) が緑になっていること
- [x] ユニットテストが green (`xcodebuild test -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 17'` を 2026-05-23 にローカル実行、全件 PASS / 0 failures)
- [ ] iOS シミュレータで ja/en 両ロケール起動を目視確認

### App Store Connect

- [ ] 新バージョン `1.1.2` を作成
- [ ] Build 53 を選択
- [ ] 「このバージョンの新機能 (ja)」に § 2.1 のドラフトを貼り付け
- [ ] **「このバージョンの新機能 (en)」に § 2.5 のドラフトを貼り付け** ← Phase 2 of #50 必須項目
- [ ] (任意) 一括モード / 重複警告 のスクショを撮り直し
- [ ] 審査ノートに § 2.4 を貼り付け
- [ ] **Age Rating で「広告」=「はい」になっていることを確認** ← #86 対策 (AdMob 統合済みのため必須)

### 提出

- [ ] すべて緑チェック → 「審査へ提出」

## 4. よくある reject 理由と対策

### 4.1 ITMS-90062 / ITMS-90186 (バージョン関連)

**症状**: 「previously approved version より version string が高くない」「train が closed」

**対策**: pbxproj の `MARKETING_VERSION` を bump する。v1.1.0 → v1.1.1 で踏んだので本リリースでは予防的に v1.1.2 / Build 53 を確認。`release-version-bump-check.yml` (#55) が CI 側でも gating する。

### 4.2 「プライバシーポリシーが App の挙動と一致しない」

v1.1.0 / v1.1.1 と同じ対応。

### 4.3 「Kids カテゴリ要件を満たしていない」

v1.1.0 / v1.1.1 と同じ。アプリは Kids カテゴリには登録していないので通常は該当しない。

### 4.4 Age Rating の Advertising 設定漏れ (Issue #86)

**症状**: 提出直後に automated review から

> An automated analysis of the submission indicates the app may include advertising but you did not select "Yes" for the "Advertising" content descriptor on the Age Rating selection in App Store Connect.

というメッセージで reject される (resolution center 経由)。

**根本原因**: AdMob (Google Mobile Ads SDK) のような広告 SDK を統合しているのに、ASC の Age Rating で "Advertising" content descriptor が "No" のまま。Apple の automated check が SDK 静的解析で広告統合を検知し、Age Rating 申告と齟齬があるとブロックする。

**対策**:

1. ASC → アプリ → 「App 情報」 → 「年齢制限指定」 → 「編集」
2. 「広告」 (Advertising) の項目を **「はい」** に設定 → 保存
3. 結果として Age Rating が 4+ から変動するケースは稀 (広告だけでは年齢上がらない)
4. 設定変更だけで再提出可。build の再アップロードや version bump は不要 (metadata-only fix)

**予防**: § 3 の提出前チェックリストに「Age Rating Advertising=Yes 確認」項目を追加済み。AdMob を組み込んだ v1.1.0 以降は常に Yes を維持する。

## 5. 完了後タスク

- [ ] App Store 公開後、`main` に `v1.1.2` annotated タグを作成・push (`git tag -a v1.1.2 -m "v1.1.2" && git push origin v1.1.2`)
- [ ] GitHub Release を作成 (タイトル: `v1.1.2`, body: § 2.1 ja ドラフトを流用、英文も合わせて記載すると◎)
- [ ] 対応 issue (#54 / #49 / #53 / #69 / #73 / #74) のうちまだクローズされていないものを `gh issue close <N> --reason completed --comment "v1.1.2 でリリース"` で処理
- [ ] (任意) v1.1.1 用の GitHub Release を「Latest」マークから外し、v1.1.2 をマーク
- [ ] `release-retrospective` skill を実行 (#50 の Phase 2 効果検証、What's New 英訳フローの初実践を振り返り)

## 6. 振り返り (Retrospective)

> 本セクションはリリース完了後に `release-retrospective` skill で生成される。マージ前は空欄のまま。
> 関連 PR の取り込み範囲: **#62 / #64 / #67 / #68 / #70 / #72 / #77 / #79** (ユーザー向け + マネタイズ + テスト改善)
