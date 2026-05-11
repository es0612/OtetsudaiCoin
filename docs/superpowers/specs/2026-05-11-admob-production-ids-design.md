# AdMob 本番化と環境別 ID 管理 — 設計書

Issue: #21
作成日: 2026-05-11

## 背景

PR #17 で AdMob バナー広告を導入した際、Google 公式のテスト ID をハードコードした状態でリリースを迎えそうな状況。リリース前に **本番 ID への差し替え + 開発/本番の事故防止** が必要。Issue #21 で求められた対応。

## 方針

`xcconfig` 新設ではなく、本プロジェクトが既に使っている **build settings 直書きスタイル**（`INFOPLIST_KEY_*` のパターン）に合わせる。

具体的には、`OtetsudaiCoin` ターゲットの Debug / Release それぞれの `buildSettings` に、AdMob 用ビルド変数 2 つを per-configuration で追加する:

| Configuration | `GAD_APPLICATION_IDENTIFIER` | `GAD_BANNER_AD_UNIT_ID` |
| --- | --- | --- |
| Debug | テスト ID (`ca-app-pub-3940256099942544~1458002511`) | テスト ID (`ca-app-pub-3940256099942544/2934735716`) |
| Release | 本番 ID | 本番 ID |

そして `Info.plist` で `$(...)` 形式で参照する。

### 採用しなかった案: `Config/*.xcconfig` 新設

| 観点 | xcconfig 新設 | buildSettings 直書き（採用） |
| --- | --- | --- |
| pbxproj 編集量 | 大（PBXFileReference + baseConfigurationReference） | 小（既存 buildSettings に追記） |
| プロジェクト整合性 | 既存スタイルと混在 | 既存 `INFOPLIST_KEY_*` パターンと一致 |
| 拡張性 | 高（他の env 別設定も追加しやすい） | 中（同方式で十分対応可能） |
| リスク | pbxproj 構造変更のリスク中 | 低 |

将来 env 別設定が増えた段階で xcconfig 化を検討する。

## 実装スコープ

### 1. project.pbxproj の編集

`OtetsudaiCoin` ターゲットの Debug 構成（line 428 付近、ID `D5F61D932DFE693E00C8C1E9`）の `buildSettings` に以下を追加:

```text
GAD_APPLICATION_IDENTIFIER = "ca-app-pub-3940256099942544~1458002511";
GAD_BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/2934735716";
```

Release 構成（line 458 付近、ID `D5F61D942DFE693E00C8C1E9`）に本番 ID を:

```text
GAD_APPLICATION_IDENTIFIER = "ca-app-pub-9706471521661305~1877276767";
GAD_BANNER_AD_UNIT_ID = "ca-app-pub-9706471521661305/5964695582";
```

`G` 始まりなので、既存の `GENERATE_INFOPLIST_FILE` の直前に追加（アルファベット順を維持）。

### 2. Info.plist の更新

`GADApplicationIdentifier` を `$(GAD_APPLICATION_IDENTIFIER)` に変更し、新たに `GADBannerAdUnitID` キーを追加して `$(GAD_BANNER_AD_UNIT_ID)` を参照。

### 3. AdConstants.swift のリファクタ

- `testBannerAdUnitID` → `bannerAdUnitID` にリネーム
- 値を Bundle.main の Info.plist から読み取る形に変更

```swift
import Foundation

enum AdConstants {
    static var bannerAdUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String ?? ""
    }
}
```

### 4. BannerAdView.swift の更新

`AdConstants.testBannerAdUnitID` → `AdConstants.bannerAdUnitID` の参照リネーム。

## 検証

- **単体テスト**: AdConstants がテスト ID 値を返すこと（テスト実行は Debug 構成のため）
- **Debug ビルド**: ビルド成果物 `.app/Info.plist` の `GADApplicationIdentifier` がテスト ID、`GADBannerAdUnitID` もテスト ID
- **Release ビルド**: ビルド成果物 `.app/Info.plist` の両 ID が本番値
- **既存テスト**: BannerAdView 関連 5 件 + AppDelegate / Domain 系すべて PASS

## セキュリティ

- 本番 ID は AdMob 管理画面で発行されたものだが、AdMob ID は **公開しても直接的なセキュリティリスクはない**（広告配信先の特定はできるが、収益詐取等は不可能）
- ただし慎重を期して、Issue コメントには貼らない
- pbxproj / Info.plist の git コミットには本番 ID が含まれる（前提として OK）

## 関連ファイル

- `app/OtetsudaiCoin.xcodeproj/project.pbxproj` — buildSettings 追記
- `app/OtetsudaiCoin/Info.plist` — `$(...)` 変数参照に変更
- `app/OtetsudaiCoin/Utils/AdConstants.swift` — リネーム + Bundle 読み取り
- `app/OtetsudaiCoin/Presentation/Components/BannerAdView.swift` — 参照リネーム

## 実装タスク

- [ ] project.pbxproj の Debug / Release buildSettings に `GAD_*` 変数を追加
- [ ] Info.plist を更新
- [ ] AdConstants をリファクタ + Bundle 読み取りテスト追加
- [ ] BannerAdView の参照を更新
- [ ] Debug ビルド検証
- [ ] Release ビルド検証
- [ ] 全テスト PASS 確認
- [ ] コミット → PR
