# Issue #147: ブランドカラー確立と青→紫グラデーション廃止 — Design Doc

- 日付: 2026-07-18
- 対象 Issue: #147(優先度: 高)
- 前提: #146 デザイントークン基盤(AppRadius / AppSpacing / AppShadow)は merge 済み(PR #169)
- 決定プロセス: superpowers:brainstorming + visual companion でパレット 3 案・ボタン形状 3 案を視覚比較し、ユーザーが選択

## ゴール

「お手伝い × コイン × 親子」の世界観に合う温かいブランドカラー体系を確立し、「AI 生成 UI」の印象源である青→紫グラデーションを全廃する。

受け入れ条件(issue より):

- 青→紫グラデが全廃され、全ボタンがブランドカラー体系に従う
- before/after スクショを PR に添付(ja のみで OK)

## 決定事項

### 1. パレット: 「オレンジ × ティール」(案 C)

スプラッシュ画面(orange→yellow)を原点とした温色軸 + 補色ティールの役割分担。

| トークン | 値(暫定) | 用途 |
| --- | --- | --- |
| `brandPrimary` | `#E8590C` | メイン CTA、AccentColor、進捗バー |
| `brandPrimaryDark` | `#C2410C` | 押下状態・ダークモード調整 |
| `brandSecondary` | `#099268` | 記録・保存など成功系アクション |
| `brandAccent` | `#FFD43B` | コイン表現・お祝いアクセント |
| `brandSurfaceWarm` | `#FFF4E6` | 温色の淡背景 |

- 置き場所: `Utils/AccessibilityColors.swift` に `// MARK: - Brand Colors` セクションを追加(#146 の役割宣言「色は AccessibilityColors が担当」に従う)
- **コントラスト検証**: 実装時に既存 `contrastRatio(with:)` で白文字とのコントラストを検証する。ボタンラベルは 17pt semibold = WCAG large text 基準で最低 3:1、可能なら 4.5:1 を目標に微調整(例: `#099268` が不足するなら `#087F5B` へ)。最終 hex は検証結果で確定し、本 doc の値は暫定
- semantic color(successGreen / errorRed / warningOrange 系)は現状維持

### 2. ボタンスタイル: ソフト角丸単色(案 C)

`GradientButtonStyle.swift` を `AppButtonStyle.swift` に置換する。

- 新 `SolidButtonStyle`(ButtonStyle 準拠):
  - 形状: `RoundedRectangle(cornerRadius: AppRadius.xLarge)`(20pt ソフト角丸)
  - 地色: 単色 + 白文字(`.headline` semibold 維持)
  - 押下: scale 0.95 アニメーション維持
  - 影: `AppShadow.cardElevated` 準拠(グローなし)
  - disabled: グレー地 + opacity 0.6(現行踏襲)
- プリセット: `.primary`(brandPrimary)/ `.success`(brandSecondary)/ `.destructive`(errorRed)
- View extension: `primaryButton()` / `successButton()` / `destructiveButton()`
- **削除**: `accentGradientButton` / `CompactGradientButtonStyle`(全ターゲット参照ゼロを grep 確認のうえ削除)

### 3. 呼び出し 11 箇所の置換マッピング

| 現行 | 箇所 | 新スタイル |
| --- | --- | --- |
| `primaryGradientButton` | TaskListActionButtons:19 / HelpHistoryView:193 / MonthlySummaryView:217 / SettingsView:94 / ChildFormView:108 / HelpRecordEditView:133 / StateBasedContent:80 | `primaryButton()`(orange) |
| `successGradientButton` | RecordButtonBar:25 / TaskManagementView:209 / RecordTutorialView:324 | `successButton()`(teal) |
| `warningGradientButton` | HelpRecordEditView:145(削除ボタン) | `destructiveButton()`(errorRed) |

### 4. Tutorial 2 画面の統一

- 背景グラデ(ChildTutorialView:19 / RecordTutorialView:28): 青系 → **温色グラデ(orange→yellow の淡トーン、スプラッシュ同系)**。ブランドグラデは温色のみ許容というルールにする
- アイコン円(ChildTutorialView:91,187 / RecordTutorialView:114,357): 単色化(orange / teal)
- 進捗バー(ChildTutorialView:170): brandPrimary 単色

### 5. AccentColor asset

空(=システム青)の `Assets.xcassets/AccentColor` に brandPrimary `#E8590C` を設定。ダークモード variant は明るめ(`#FF7A2E` 系)。リンク・トグル等の OS 標準 UI がブランド色に揃う。

### 6. アバタープリセット刷新(本 PR に含む)

- `ChildManagementViewModel.themeColors`: ネオン 25 色 → パレット調和の 12 色程度(中彩度 warm 中心 + 識別用 cool 数色)にキュレーション
- `ChildFormView.selectedThemeColor` デフォルト: `#3357FF`(青)→ 新プリセットの先頭色
- サンプルデータ色の更新: ContentView:149-150 / SampleDataService:25-26 / HelpRecordEditView:213(太郎・花子)
- **既存ユーザーの保存済み themeColor は migration しない**(`Color(hex:)` は任意 hex を解釈可能で表示は壊れない)

### 7. スコープ外

- 子どもテーマ色由来のグラデ(HomeView:88 / MonthlySummaryView:99 / HelpHistoryView:302)— per-child の意匠として維持。プリセット刷新で自然に調和する
- `SkeletonViews` の shimmer グラデ(ニュートラル色)
- `SplashScreenView`(既に orange→yellow でブランド原点)
- ダークモード全画面監査は #151 に委ねる(本 PR は AccentColor の dark variant と新規色の semantic 対応まで)

## テスト・検証戦略

1. **unit test**: `SolidButtonStyle` のプリセット色・disabled 判定を struct レベルで assert(新規 `AppButtonStyleTests.swift`、既存テスト命名 convention に揃える)
2. **既存テスト更新**: `ChildManagementViewModelTests` の色リスト参照を新プリセットに追随
3. **削除シンボルの grep**: `accentGradientButton` / `CompactGradientButtonStyle` / `gradientButtonStyle` を app / Tests / UITests 全ターゲットで残存ゼロ確認(CLAUDE.md 削除ルール)
4. **視覚検証**: `scripts/capture-asc-screenshots.sh` で before(HEAD)/ after(working tree)を撮影し assistant が一次目視 → PR に before/after 添付(ja)。スクショ出力(`docs/screenshots/asc/`)は目視後 `git checkout --` で discard(別目的ファイル同梱禁止ルール)
5. ViewInspector 制約(iOS 26 で `find(viewWithAccessibilityIdentifier:)` 不能)に従い、View 側の検証が必要な場合は `findAll` ベースで書く

## 実装順序(概要)

1. Brand Colors 追加 + コントラスト検証(unit test で担保)
2. `AppButtonStyle.swift` 新設(TDD)→ 呼び出し 11 箇所置換 → `GradientButtonStyle.swift` 削除
3. Tutorial 統一 + AccentColor asset
4. アバタープリセット刷新 + サンプルデータ色更新
5. 全体テスト green 確認 → 視覚検証(before/after)

詳細タスク分割は writing-plans で行う。
