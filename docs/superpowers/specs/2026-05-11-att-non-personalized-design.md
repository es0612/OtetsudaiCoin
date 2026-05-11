# ATT 対応方針（Non-personalized 広告で初回リリース）— 設計書

Issue: #22
作成日: 2026-05-11

## 背景

#10（PR #17）で AdMob バナー広告を導入。iOS 14+ では広告トラッキング（IDFA）利用時に App Tracking Transparency (ATT) の許可ダイアログ表示が必須。本プロジェクトでは、初回リリースに向けて **Non-personalized 広告（IDFA を利用しない）** のみで運用する方針を採る。

`plans/partitioned-baking-dawn.md` の Phase 1 検討結果。

## 方針判断

**採用: 案A（Non-personalized のみ）**

理由:

- 家庭での親子利用が主なターゲット層であり、起動直後の「トラッキング許可」ダイアログは UX 上違和感が大きい
- 初回リリース時は DL 数が伸びる前で、ATT/UMP 周りの不備がストアレビュー低下に直結しやすい
- 将来 DAU が伸びてからパーソナライズ広告へ切り替え可能（後方互換）

## 実装スコープ

### 1. AdMob リクエストに `npa=1` を付与

`BannerAdView.swift` で `Request` を作る際に `Extras` を `register` し、`additionalParameters` に `["npa": "1"]` を渡す。

GoogleMobileAds SDK 12.x の Swift API:

```swift
let extras = Extras()
extras.additionalParameters = ["npa": "1"]
let request = Request()
request.register(extras)
bannerView.load(request)
```

### 2. Privacy Manifest を追加

`PrivacyInfo.xcprivacy` をプロジェクトに追加し、以下を明示:

- `NSPrivacyTracking = false`（トラッキングしない）
- `NSPrivacyTrackingDomains = []`
- `NSPrivacyCollectedDataTypes = []`（アプリ本体は IDFA 等を収集しない。AdMob SDK 側の宣言は別途 SDK 同梱の Privacy Manifest が担う）
- `NSPrivacyAccessedAPITypes` … 該当 API 利用に対するリーズンコード（UserDefaults 等）

### 3. やらないこと

- `Info.plist` への `NSUserTrackingUsageDescription` 追加 → ATT ダイアログを呼ばないため不要
- `ATTrackingManager.requestTrackingAuthorization` の呼び出し
- UMP SDK（`UserMessagingPlatform`）の利用 → GDPR consent form を出さない（Non-personalized なら不要）

## 関連ファイル

- `app/OtetsudaiCoin/Presentation/Components/BannerAdView.swift` — `Request` 生成箇所
- `app/OtetsudaiCoin/Info.plist` — トラッキング関連キーは追加しない
- `app/OtetsudaiCoin/PrivacyInfo.xcprivacy` — 新規追加

## 検証

- 単体テスト: `Extras` の `additionalParameters` に `npa=1` が含まれることを検証（`BannerAdView` のロジック切り出しが必要）
- ビルド: Debug / Release 両方で警告なくビルドできること
- 実機: バナー広告が表示されること（テスト ID 環境）

## 将来の Personalized 切替に向けた TODO

- UMP SDK 統合（GDPR consent form）
- `ATTrackingManager.requestTrackingAuthorization` の起動時呼び出し
- `Info.plist` の `NSUserTrackingUsageDescription`（日英ローカライズ）
- `PrivacyInfo.xcprivacy` の `NSPrivacyTracking = true` 化と `NSPrivacyTrackingDomains` 設定

## 実装タスク

- [ ] `Request` 生成ロジックを `BannerAdView` から抽出し、テスト可能な関数に切り出す
- [ ] `Extras` で `npa=1` を付与する実装
- [ ] テストを追加（`additionalParameters` に `npa=1` が含まれる）
- [ ] `PrivacyInfo.xcprivacy` を新規追加
- [ ] Xcode プロジェクトに `PrivacyInfo.xcprivacy` を含める（手動ステップが必要な場合はユーザー依頼）
- [ ] `xcodebuild test` 全 PASS 確認
- [ ] コミット → PR 作成
