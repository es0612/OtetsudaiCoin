---
inclusion: manual
---

# Issue Triage Rules (OtetsudaiCoin 固有)

このファイルは `daily-issue-triage` skill が動いた際に **手動参照** されるプロジェクト固有ルール集です。汎用スキルでは扱わない OtetsudaiCoin の語彙・運用規約をここに集約します。

`daily-issue-triage` を呼び出された Claude は、最初にこのファイルを読んでから tabulation・scope 確認に進んでください。

## 優先度の語彙

セッション内で P0/P1/P2 と呼ばれることがあります。意味は:

| ラベル | 意味 | 例 |
| --- | --- | --- |
| **P0** | 即対応 / リリースブロッキング | アプリがクラッシュする / 起動できない / ストア審査リジェクト |
| **P1** | 次リリースで必須 | 主要画面の表示バグ / 新機能のローカライズ漏れ / アクセシビリティ不足 |
| **P2** | 保留可能 / 別バージョンで検討 | デザイン要件未定の UI 改善 / 汎用プレースホルダの i18n 整備 |

ユーザーから「P0 / P1 / P2」と言われたらこの定義で受け取る。`gh issue` の label には現状この prefix はないので、優先度は会話で明示される運用。

## リリースバージョン規約

セマンティックバージョニング (`vMAJOR.MINOR.PATCH`):

- **PATCH** (例: `1.1.0` → `1.1.1`): バグ修正のみ
- **MINOR** (例: `1.1.x` → `1.2.0`): 後方互換のある機能追加 / 大きめの改善
- **MAJOR** (例: `1.x.x` → `2.0.0`): 互換性のない変更 (アプリレベルでは UI/UX フルリニューアル相当)

リリース手順書は `RELEASE_vX.Y.Z.md` を毎リリース新規作成。前バージョンの md は残す。

**重要**: リリース PR では `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` の bump を必ず確認。これは `release-version-bump-check` skill の領域。

## ラベル運用

リポジトリで使われているラベル (`gh label list`):

- `bug` — バグ修正系
- `enhancement` — 新機能・改善
- `documentation` — ドキュメント・リリース手順
- `question` — 仕様確認 / 議論
- `duplicate` / `wontfix` / `invalid` — 標準

優先度や release マイルストーンはラベル化されていない。会話で扱う。

## 保留タスクの運用

**保留・将来検討タスクは memory ではなく GitHub Issue として登録する**。これは恒久的なプロジェクト運用ルール (`feedback_deferred_tasks_as_issues` memory も参照)。

triage 中に「これは v1.1.2 で検討」「デザイン要件が固まったら着手」のような保留判断をする際は:

1. AskUserQuestion で「Issue 化しますか?」を提案 (default Yes)
2. `gh issue create` で登録 (背景・判断材料・関連 PR を本文に明記)
3. memory には書かない

## 関連スキル

OtetsudaiCoin 用に整備された domain skill。triage の後段で活用する:

| skill | 出番 |
| --- | --- |
| `release-version-bump-check` | リリース PR の bump 漏れチェック / ITMS リジェクト対応 |
| `xcstrings-bulk-update` | i18n 系 issue で xcstrings を更新する場合 |
| `ios-simulator-app-verification` | UI バグ修正後のスクショ検証 |
| `ios-simulator-locale-testing` | i18n 修正後の ja/en スクショ比較 |

triage 中はこれらを**呼ばない**で、後段 (writing-plans / 実装フェーズ) で必要に応じて呼ぶ。

## このプロジェクトの triage で特に気にすること

- **App Store 連動**: バージョン / リリース系 issue は App Store の審査・承認状態と紐づく。「v1.1.1 提出済み」のような状態を確認してから着手判断する
- **ローカライゼーション**: i18n は P0/P1/P2 で分割可能。「全部やる」より「画面別に分割」する方が PR が小さく保てる
- **UI/UX 系**: デザイン決定待ちのものは無理にコード着手しない。要件整理ドキュメント (e.g. Figma 依頼向け) を作るところで一旦止める
- **ITMS リジェクト**: バージョン関連の reject は緊急。triage 順序を変えて先頭に持ってくる
