# fastlane metadata delivery — SETUP

このリポジトリの fastlane は **App Store Connect (ASC) のテキストメタデータのみ**を投入するために使います。
バイナリ (ipa) は **Xcode Cloud が所有**しており、fastlane ではビルド・アップロードしません。

> スキル参照: グローバルスキル `asc-metadata-delivery`（仕組み）+ `release-version-bump-check`（upload 前のローカル検査）。

## 0. これは何のためか（#50 Phase 1）

ASC の **英語 (English U.S.) ロケーション**を追加するためのメタデータ scaffold です。
日本語ロケーションは既に live のため、本リポジトリには **`metadata/en-US/` のドラフトのみ**を同梱しています
（ja・copyright・category・URL などの非英語/非ローカライズ項目は live ASC から download して取得します。後述の download-first を参照）。

英語ドラフトの出典: リポジトリ root の `RELEASE_v1.1.1_ASC_EN.md`。

## 1. 前提ツール

- fastlane（macOS, Homebrew 版で可: `fastlane --version` で確認。本 scaffold は 2.228.0 で検証）。
- ASC 認証情報（下記 §2）。

## 2. 認証情報（コミットしない）

`fastlane/.env`（gitignore 済み）に設定します。いずれか:

#### (A) Apple ID + App-Specific Password

```ini
FASTLANE_USER=<ASC ログインに使う Apple ID メール>
FASTLANE_PASSWORD=<App-Specific Password (appleid.apple.com で発行)>
```

#### (B) App Store Connect API Key（推奨・2FA 不要）

```ini
# .env に key ファイルパス等を置くか、lane 実行時に --api_key_path で渡す
APP_STORE_CONNECT_API_KEY_PATH=/absolute/path/to/AuthKey_XXXX.p8
```

> `apple_id`（ログイン identity）は `Appfile` にハードコードしていません（個人メール混入と
> 「どのメールでログインするか」の曖昧さを避けるため）。必ず `.env` の `FASTLANE_USER` で指定してください。

## 3. Appfile の team_id（必要なら）

`fastlane/Appfile` は `app_identifier`（= `com.asapapalab.OtetsudaiCoin`）のみコミットしています。
複数チームに所属していて `deliver` がチームを自動解決できない場合のみ、`Appfile` の
`team_id` / `itc_team_id` をコメント解除して埋めてください（developer.apple.com の Membership で確認）。

## 4. 投入フロー（**順序厳守**・人間が手実行）

> ⚠️ **安全性**: `upload_to_app_store` は `submit_for_review:false` でも metadata を
> **live ASC の editable バージョンに stage（書き込み）します**。`false` は「審査に出さない」だけで
> 「ASC に書かない」ではありません。投入系コマンドは **CI / subagent では絶対に自動実行しない**でください。

### 4-1. 🚧 HARD GATE: 先に download してから編集する

**いきなり `upload_metadata` を実行しないでください。** 先に live ASC の現状を取得します:

```bash
cd <repo root>
fastlane deliver download_metadata
```

理由（footgun）: `deliver` は metadata ディレクトリに**存在するロケールの各フィールド**を ASC へ書き込みます。
`copyright` / `primary_category` / `support_url` などローカルに無いフィールドを **空で上書き**してしまう恐れがあります。
download すると live の現在値（ja ロケール・copyright・category など）が `metadata/` に埋まり、上書き事故を防げます。
本 scaffold が同梱する `metadata/en-US/` は download では取得されません（en ロケールはまだ ASC に無いため）＝**共存します**。

### 4-2. 内容を確認・編集

- `metadata/en-US/*.txt`（本 scaffold の英語ドラフト）を spot-review。
- download で取得した `metadata/ja/*.txt` 等が意図通りか確認。

### 4-3. upload 前のローカル検査（precheck では拾えない穴を潰す）

`release-version-bump-check` skill を使い、**upload 前に**以下をローカルで検査:

- **英語ロケールの emoji 禁止**（#85）: `metadata/en-US/` の Description / What's New に絵文字があると ASC が silent reject。
  本 scaffold の英語ドラフトは絵文字なし（`¥` `—` は絵文字ではなく通貨/ダッシュ記号で OK）。
- **version bump**（ITMS-90186 / 90062）: 本フローは metadata-only なので通常は無関係ですが、
  もし同セッションでバイナリも更新するなら `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` の bump を確認。
- **Age Rating「広告」= はい**（AdMob 統合のため。ASC UI で手動確認）。

### 4-4. stage（書き込み）→ precheck

```bash
fastlane upload_metadata
```

この lane は `upload_to_app_store`（stage）→ `precheck`（ASC 側 staged コピーを検証）の順で走ります。
`force` を付けていないため、**書き込み前に deliver の HTML プレビュー**が出ます。内容を必ず確認してから進めてください。
`precheck` は placeholder / curse words / unreachable URL 等を ASC 側 editable に対して検査します。

### 4-5. 人間が ASC UI で submit

precheck まで緑なら、**ASC UI で「審査へ提出」を人間が行います**（lane は自動提出しません）。

## 5. ⚠️ 人間が確認すべき未検証ポイント（このリポジトリでは検証不能）

1. **en ロケールの新規作成**: `upload_to_app_store` が **en-US ロケーションを新規作成するか、既存ロケールの更新のみか**は
   このリポジトリ側では検証できません。`deliver` が en を新規作成しない挙動だった場合は、
   **先に ASC UI で English (U.S.) ロケーションを Add してから** `upload_metadata` を実行してください
   （ASC → My Apps → おてつだいコイン → (バージョン) → Localizations → Add Language: English (U.S.)）。
2. **download-first の遵守**: §4-1 の HARD GATE を飛ばすと非ローカライズ項目を空で上書きする恐れがあります。

## 6. スクリーンショットは deliver 管理外（#50 §1.5 は未完）

`upload_metadata` lane は `skip_screenshots: true` です（live スクショの誤削除を防ぐため）。
英語ロケール用スクショ (`docs/screenshots/asc/v1.1.x/en/` に撮影済み) の ASC 反映は、
**ASC UI での手動アップロード**、または将来 `screenshots_path` を設定した別 deliver 実行で行ってください。
→ **#50 Phase 1 §1.5（英語スクショの ASC 反映）は本 scaffold では完了しません**。別途対応。

## 7. ディレクトリ構成

```text
fastlane/
├── Appfile                     # app_identifier のみ（team_id は任意）
├── Fastfile                    # upload_metadata lane (stage → precheck)
├── SETUP.md                    # この文書
├── .env                        # 認証情報（gitignore・各自作成）
└── metadata/
    ├── en-US/                  # 英語ドラフト（本 scaffold が同梱）
    │   ├── name.txt
    │   ├── subtitle.txt
    │   ├── description.txt
    │   ├── keywords.txt
    │   ├── promotional_text.txt
    │   ├── release_notes.txt
    │   ├── support_url.txt
    │   └── privacy_url.txt
    ├── ja/                     # download_metadata で live から取得（コミットしない運用）
    ├── copyright.txt           # 同上（download で取得）
    ├── primary_category.txt    # 同上（download で取得）
    └── review_information/
        ├── notes.txt           # ログイン不要の説明（コミット可）
        └── demo_user.txt 等    # 機微情報 → gitignore
```
