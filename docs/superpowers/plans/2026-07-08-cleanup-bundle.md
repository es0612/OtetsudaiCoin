# クリーンアップ束 (#143 / #140 / #139 / #156) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** リポジトリのデッドコード・開発遺物・散在ドキュメントを整理し、README/LICENSE をリポジトリ実態に一致させる（大きな design/data トラック着手前の地ならし）。

**Architecture:** 4 つの独立した issue を 3 本の PR に束ねる。PR1=#143（Swift デッドコード削除）、PR2=#140（開発遺物削除 + steering 参照修正）、PR3=#139+#156（リリース文書移動 + README/LICENSE 修正、両者とも README を触るため 1 PR に集約して同一ファイル並行更新 conflict を回避）。各 PR は独立ブランチを `origin/main` から派生。

**Tech Stack:** Swift / SwiftUI (Xcode 16+, `PBXFileSystemSynchronizedRootGroup`), Markdown, git, gh CLI。

## Global Constraints

- **削除/移動タスクに TDD サイクルを強制しない。** deliverable は「ビルド + 全既存テスト green + grep で dangling ref ゼロ」。テストを新規に捏造しない（advisor 指摘）。
- **各 PR は `origin/main` 起点の新ブランチ。** 作業開始（最初の変更）前に `git fetch origin && git checkout main && git merge --ff-only origin/main && git checkout -b <branch>`（CLAUDE.md Git ルール）。
- **別目的ファイルを 1 PR に同梱しない。** PR1/PR2/PR3 は互いに素なファイル集合。README を触るのは PR3 のみ。
- **Markdown lint 準拠**（IDE が markdownlint 実行）: MD031/032/036/040/060/029/034 等を守る（memory: markdown lint compliance）。
- **`xcodebuild` の完了 exit を鵜呑みにしない。** background chain 実行では末尾 `echo` の 0 が報告されるので、log 末尾を `grep "^exit="` / `grep -F "** TEST FAILED"` / `Failing tests:` で確認してから green 判定（CLAUDE.md iOS テスト flake ルール）。
- **LICENSE copyright 名義 = `AsaPapaLab`**（ユーザー確定、公開ブランド。memory: publisher identity）。
- **Xcode project は `PBXFileSystemSynchronizedRootGroup`** のため、Swift ファイル削除で `project.pbxproj` 編集は不要（自動認識）。

---

## Task 1 (PR1 / #143): デッドコード削除

**⚠️ issue の前提を検証で修正済み:** issue は「SkeletonViews の 10 構造体中 8 個が参照 0」と記載するが、**残す `HomeViewSkeleton` が `SkeletonBox` / `SkeletonCircle` / `SkeletonTextLine` / `StatsCardSkeleton` / `ListItemSkeleton` を内部で使用**しているため、実削除可能は `ChildAvatarSkeleton` / `TaskCardSkeleton` / `RecordViewSkeleton` の **3 構造体 + 未使用 `extension View { skeleton / defaultSkeleton }`** のみ。8 個全削除はビルド破壊。「約 700 行削減」も過大で、実削減は大幅に小さい（PR description で訂正する）。

**Files:**
- Delete: `app/OtetsudaiCoin/Utils/NetworkOptimizer.swift`（195 行, 全削除。`NetworkOptimizer` / `NetworkError` enum / `NetworkCache` / `CachedResponse` / `NetworkStatusIndicator` / `networkOptimized()` ext。外部参照 0 を確認済み。`ErrorMessageConverter.convertNetworkError` は汎用 `Error` を取る無関係な private helper）
- Delete: `app/OtetsudaiCoin/Presentation/ViewModels/Base/ViewState.swift`（45 行, 全削除。外部参照 0）
- Delete: `app/OtetsudaiCoinTests/OtetsudaiCoinTests.swift`（37 行, 全削除。`testExample` / `testPerformanceExample` の Xcode テンプレート placeholder。`OtetsudaiCoinTests` クラス外部参照 0）
- Modify: `app/OtetsudaiCoin/Utils/SkeletonViews.swift`（`ChildAvatarSkeleton`(107-114) / `TaskCardSkeleton`(141-156) / `RecordViewSkeleton`(232-274) の 3 struct、および末尾の `extension View`(279-309) を削除。**残す**: `SkeletonBox` / `SkeletonCircle` / `SkeletonTextLine` / `StatsCardSkeleton` / `ListItemSkeleton` / `HomeViewSkeleton`）
- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`（`testNetworkStatusIndicatorKeysExist()` = 161-176 行 MARK コメント含め削除。検証対象キー "オフライン"/"モバイル"/"接続中" は NetworkOptimizer.swift のみで使用 → 削除で孤立するため、この test も削除する）

**孤立 xcstrings キーの扱い:** "オフライン"/"モバイル"/"接続中" は削除で孤立データ化するが、`Localizable.xcstrings` からの除去は本 PR スコープ外（xcstrings 編集は corruption リスクあり [[xcstrings-bulk-update]]）。PR description に「orphaned として残置、除去は任意の follow-up」と明記。

**Interfaces:**
- Consumes: なし（純削除）
- Produces: なし（後続タスク非依存）

- [ ] **Step 1: ブランチ作成**

```bash
git fetch origin && git checkout main && git merge --ff-only origin/main
git checkout -b chore/issue-143-dead-code
```

- [ ] **Step 2: 全削除ファイルを git rm**

```bash
git rm app/OtetsudaiCoin/Utils/NetworkOptimizer.swift \
       app/OtetsudaiCoin/Presentation/ViewModels/Base/ViewState.swift \
       app/OtetsudaiCoinTests/OtetsudaiCoinTests.swift
```

- [ ] **Step 3: SkeletonViews.swift から未使用 3 struct + extension を削除**

`ChildAvatarSkeleton`（"子供のアバター用スケルトン" コメント + struct 全体）、`TaskCardSkeleton`（"タスクカード用スケルトン" + struct）、`RecordViewSkeleton`（"記録画面用スケルトン" + struct）、および `// MARK: - Skeleton Modifier` 以下の `extension View { func skeleton..., func defaultSkeleton... }`（279-309 行）を削除。`SkeletonBox` / `SkeletonCircle` / `SkeletonTextLine` / `StatsCardSkeleton` / `ListItemSkeleton` / `HomeViewSkeleton` は残す。編集後の末尾は `HomeViewSkeleton` の閉じ `}` と `SkeletonViews` struct の閉じ `}` で終わる。

- [ ] **Step 4: LocalizationStringCatalogTests.swift から testNetworkStatusIndicatorKeysExist を削除**

161-176 行の `// MARK: - NetworkStatusIndicator のキー存在テスト` コメントと `func testNetworkStatusIndicatorKeysExist() { ... }` を削除。前後の test（`testPersistenceError...` と `testMonthlyRecordPaymentStatusKeysExist`）は残す。

- [ ] **Step 5: 残存参照ゼロを grep で確認**

```bash
grep -rn "NetworkOptimizer\|NetworkStatusIndicator\|NetworkCache\|networkOptimized\|\bViewState\b\|ChildAvatarSkeleton\|TaskCardSkeleton\|RecordViewSkeleton\|\.defaultSkeleton(\|\.skeleton(" \
  app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests --include="*.swift" \
  | grep -v "SkeletonViews.swift"
```

Expected: 出力ゼロ（`SkeletonViews.swift` 内の残存 struct 定義のみ除外済み。`HomeViewSkeleton` が使う `SkeletonBox` 等は同ファイル内なので grep 対象外）。

- [ ] **Step 6: ビルド + テスト実行（Swift 変更のため必須）**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  > /tmp/issue143-test.log 2>&1; echo "exit=$?" >> /tmp/issue143-test.log
grep -E "^exit=|\*\* TEST (SUCCEEDED|FAILED)|Failing tests:" /tmp/issue143-test.log
```

Expected: `** TEST SUCCEEDED **` と `exit=0`。`** TEST FAILED` / `exit=65` が出たら削除しすぎ（`HomeViewSkeleton` 依存など）を疑い、log を精査。

- [ ] **Step 7: コミット + push + PR**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(#143): デッドコード削除（NetworkOptimizer / ViewState / 未使用 Skeleton / placeholder test）

- NetworkOptimizer.swift 全削除（NetworkStatusIndicator 含む、外部参照 0）
- ViewState.swift 全削除（参照 0）
- OtetsudaiCoinTests.swift（Xcode テンプレート placeholder）削除
- SkeletonViews から ChildAvatarSkeleton/TaskCardSkeleton/RecordViewSkeleton + 未使用 extension 削除
- testNetworkStatusIndicatorKeysExist 削除（検証対象キーが削除ビューのみで使用）

issue 前提の訂正: 「8 skeleton struct 削除」は誤り。HomeViewSkeleton が 5 struct を
内部使用するため実削除は 3 struct。「約 700 行削減」も過大。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAHRjGLhUoEDnywpNumTDY
EOF
)"
git push -u origin chore/issue-143-dead-code
gh pr create --title "chore(#143): デッドコード削除" --body "<PR description: 下記メモ参照>"
```

PR description に含める: (a) issue 前提の訂正（8→3 struct、行数過大）、(b) 孤立 xcstrings キー "オフライン"/"モバイル"/"接続中" は残置・除去は任意 follow-up、(c) test suite green の証跡。

---

## Task 2 (PR2 / #140): 開発遺物・未使用ツール設定の削除

**Files:**
- Delete: `.serena/`（tracked 9 ファイル: `.gitignore` + `memories/*.md` 7 件 + `project.yml`）
- Delete: `.takt/`（tracked は `.gitignore` のみ）
- Delete: `CLAUDE_app.md`（cc-sdd 導入時の遺物、参照 0）
- Delete: `app_icon_designs.html`（アイコン試作 HTML、参照 0。#18 対応時は作り直す）
- Delete: `plans/luminous-wondering-hammock.md`（完了済み plan、tracked 1 件）
- Delete: `scripts/test-performance-report.md`（生成物スナップショット）
- Modify: `.kiro/steering/structure.md`（14 行目 `.serena/` 行、118 行目 `test-performance-report.md` 行を削除。この 2 箇所のみ dangling ref を確認済み。README/CLAUDE.md はクリーン）

**注:** `plans/` 配下の untracked ローカル plan（7 件）はスコープ外（git 管理外）。`.gitignore` への `plans/` 追加は本 PR では見送り（別判断）。`/kiro:steering` 全再生成もスコープ過剰、structure.md の targeted edit で dangling ref を解消。

**Interfaces:**
- Consumes: なし
- Produces: なし

- [ ] **Step 1: ブランチ作成**

```bash
git fetch origin && git checkout main && git merge --ff-only origin/main
git checkout -b chore/issue-140-dev-artifacts
```

- [ ] **Step 2: 遺物を git rm**

```bash
git rm -r .serena .takt
git rm CLAUDE_app.md app_icon_designs.html plans/luminous-wondering-hammock.md scripts/test-performance-report.md
```

- [ ] **Step 3: structure.md の dangling ref を削除**

`.kiro/steering/structure.md` の 14 行目（`├── .serena/ ...`）と 118 行目（`└── test-performance-report.md ...`）を削除。ツリー図の罫線整合（直前行が末尾要素なら `├──`→`└──` に調整）を確認。

- [ ] **Step 4: dangling ref ゼロを grep で確認**

```bash
grep -rn "\.serena\|\.takt\|CLAUDE_app\|app_icon_designs\|luminous-wondering-hammock\|test-performance-report" \
  README.md CLAUDE.md .kiro/ --include="*.md" 2>/dev/null | grep -v "\.git/"
```

Expected: 出力ゼロ（structure.md 修正後）。

- [ ] **Step 5: コミット + push + PR**

Swift 非該当のためビルド不要。markdown lint（structure.md）だけ確認。

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(#140): 開発遺物・未使用ツール設定を削除

- .serena/ .takt/（serena/takt 不使用、オーナー確認済み）
- CLAUDE_app.md / app_icon_designs.html / plans/luminous-wondering-hammock.md
- scripts/test-performance-report.md
- .kiro/steering/structure.md の dangling ref 2 行を削除

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAHRjGLhUoEDnywpNumTDY
EOF
)"
git push -u origin chore/issue-140-dev-artifacts
gh pr create --title "chore(#140): 開発遺物削除" --body "<grep clean 証跡 + 削除一覧>"
```

---

## Task 3 (PR3 / #139 + #156): リリース文書移動 + README/LICENSE 修正

**両 issue とも README を触るため 1 PR に集約。** README 編集は 1 回で #156（ライセンス/機能）+ #139（文書置き場 1 行）をまとめて行い、同一ファイル並行更新 conflict を構造的に回避。

**Files:**
- Move (`git mv`): `RELEASE_v1.1.0.md` / `RELEASE_v1.1.1.md` / `RELEASE_v1.1.1_ASC_EN.md` / `RELEASE_v1.1.2.md` / `RELEASE_v1.1.3.md` / `APP_STORE_SUBMISSION_GUIDE.md` → `docs/releases/`
- Modify: `CLAUDE.md`（136/137/139/140 行の `RELEASE_vX.Y.Z.md` / `RELEASE_vX.Y.Z_ASC_EN.md` 参照を `docs/releases/RELEASE_vX.Y.Z.md` 形式へ更新）
- Modify: `LICENSE`（`Copyright (c) 2025 shinya` → `Copyright (c) 2025 AsaPapaLab`）
- Modify: `README.md`（(a) §ライセンス "未定" → MIT + LICENSE ファイル参照、(b) §主な機能に #84 記録日カレンダー・#122/#130 タスク並べ替えを追記、(c) #139 の文書置き場 1 行を追加）

**inter-doc 参照は編集不要:** 移動する 6 文書は互いを bare filename（例「`RELEASE_v1.1.1.md` をベースに」）や `./RELEASE_v1.1.1.md` で参照しており、全て同じ `docs/releases/` へ移るため相対参照は valid のまま。`.github/` / `scripts/` に RELEASE 参照なし（確認済み）。

**Interfaces:**
- Consumes: なし
- Produces: なし

- [ ] **Step 1: ブランチ作成 + 移動先ディレクトリ**

```bash
git fetch origin && git checkout main && git merge --ff-only origin/main
git checkout -b docs/issue-139-156-repo-hygiene
mkdir -p docs/releases
```

- [ ] **Step 2: リリース文書を git mv（履歴保持）**

```bash
git mv RELEASE_v1.1.0.md RELEASE_v1.1.1.md RELEASE_v1.1.1_ASC_EN.md \
       RELEASE_v1.1.2.md RELEASE_v1.1.3.md APP_STORE_SUBMISSION_GUIDE.md docs/releases/
```

- [ ] **Step 3: CLAUDE.md の RELEASE パス参照を更新**

136/137/139/140 行の `` `RELEASE_vX.Y.Z.md` `` → `` `docs/releases/RELEASE_vX.Y.Z.md` ``、`` `RELEASE_vX.Y.Z_ASC_EN.md` `` → `` `docs/releases/RELEASE_vX.Y.Z_ASC_EN.md` `` に置換（テンプレート命名規約の置き場を新パスへ反映）。

- [ ] **Step 4: LICENSE 名義を AsaPapaLab へ**

`LICENSE` の `Copyright (c) 2025 shinya` を `Copyright (c) 2025 AsaPapaLab` に変更。

- [ ] **Step 5: README を編集（#156 + #139 を 1 回で）**

(a) §ライセンス（240-242 行）:

```markdown
## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
```

(b) §主な機能: 📝 お手伝い記録に「- 記録日をカレンダーから選択して過去日付を登録」を追記、📋 お手伝いタスク管理に「- ドラッグ操作でタスクの並べ替え」を追記。

(c) #139 文書置き場 1 行: §ライセンス直前あたり（または既存の適切な節）に「リリース手順書・ASC 提出ガイドは `docs/releases/` に配置」の 1 行を追加。

- [ ] **Step 6: 旧パス参照ゼロ + markdown lint 確認**

```bash
grep -rn "RELEASE_v\|APP_STORE_SUBMISSION_GUIDE" --include="*.md" --include="*.sh" --include="*.yml" . \
  | grep -v "\.git/" | grep -v "docs/releases/"
```

Expected: ルート直下パスを前提とした参照ゼロ（`docs/releases/` 内の inter-doc bare-filename 参照は同一ディレクトリなので valid、grep 結果に出るのは許容）。markdown lint（README/CLAUDE.md）を IDE 診断で確認。

- [ ] **Step 7: コミット + push + PR**

Swift 非該当のためビルド不要。

```bash
git add -A
git commit -m "$(cat <<'EOF'
docs(#139,#156): リリース文書を docs/releases/ へ移動 + README/LICENSE を実態に一致

- RELEASE_*.md / APP_STORE_SUBMISSION_GUIDE.md を docs/releases/ へ git mv（履歴保持）
- CLAUDE.md の RELEASE パス参照を docs/releases/ 形式へ更新
- LICENSE copyright を AsaPapaLab（公開ブランド）へ変更
- README: ライセンス記述 未定→MIT、機能一覧に記録日カレンダー/タスク並べ替えを追記、文書置き場を明記

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01HAHRjGLhUoEDnywpNumTDY
EOF
)"
git push -u origin docs/issue-139-156-repo-hygiene
gh pr create --title "docs(#139,#156): リリース文書整理 + README/LICENSE 修正" --body "<移動一覧 + 参照更新 + README diff 要約>"
```

---

## Self-Review

**1. Spec coverage:**

- #143: NetworkOptimizer/ViewState/OtetsudaiCoinTests 削除 ✅、SkeletonViews 未使用分削除 ✅（前提訂正込み）、test ターゲット grep ✅、build+test green ✅
- #140: 全 6 削除対象 ✅、dangling ref（structure.md）修正 ✅、grep 確認 ✅。`.gitignore plans/` と `/kiro:steering` は意図的スコープ外と明記 ✅
- #139: 6 文書移動（git mv 履歴保持）✅、CLAUDE.md 参照更新 ✅、README 1 行 ✅、旧パス参照 grep ✅
- #156: README ライセンス MIT ✅、LICENSE 名義 AsaPapaLab ✅、機能一覧更新 ✅

**2. Placeholder scan:** 各 step に具体コマンド・具体行番号・具体 diff 記載済み。TBD なし。

**3. Type consistency:** 純削除/移動/文書のため型整合の懸念なし。SkeletonViews は「残す 5 struct + HomeViewSkeleton」を全 step で一貫。

**逸脱リスク:** #143 の「issue 前提訂正（8→3 struct）」は plan 段階で確定済み。PR description に明記して reviewer が追えるようにする。
