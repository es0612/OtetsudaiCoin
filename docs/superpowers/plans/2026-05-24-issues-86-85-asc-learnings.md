# Issues #86 + #85: ASC リリース learning 反映 docs PR

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v1.1.2 リリースサイクルで踏んだ 2 つの ASC reject パターン (Age Rating "Advertising"=No → reject / 英語ロケーション Description・What's New に絵文字 → reject) を、次回以降のリリースで自動的に避けられるよう CLAUDE.md / `release-version-bump-check` skill / RELEASE doc に learning として反映する。

**Architecture:** docs/learning only — Swift コード変更なし。`main` 起点で `docs/release-learnings-asc` ブランチを切り、4 commit (RELEASE_v1.1.2.md 更新 / en draft 絵文字除去 / skill 更新 / CLAUDE.md 更新) で 1 PR にまとめる。ASC UI 側の Age Rating "Advertising"=Yes 切替はユーザーが ASC 上で別途実施 (PR merge とは independent)。

**Tech Stack:** Markdown (CommonMark + markdownlint MD031/032/040/060/029 準拠) のみ。

---

## Out of Scope (明示)

- **ASC UI 操作**: Age Rating で "Advertising" を Yes に切替えるのはユーザーが ASC 上で実施。PR には docs 反映のみ。
- **v1.1.2 本体の build 再アップロード**: pbxproj 触らない (Build 53 のまま、metadata 更新の話)。
- **Issue #50 Phase 2 の進行**: v1.1.2 が ASC 受理されてから次セッションで対応 (本 plan では着手しない)。
- **新 skill 作成**: `release-version-bump-check` skill の scope を「リリース提出前 ITMS reject 予防全般」に少し拡張する形で取り込む (新 skill `asc-submission-checklist` は分離しない)。skill name は変えない。

## File Map

| ファイル | 役割 | 触る箇所 |
| --- | --- | --- |
| `RELEASE_v1.1.2.md` | v1.1.2 提出手順書 | § 1.5 (Age Rating 注意併記) / § 2.5 (en What's New 絵文字除去) / § 3 (ASC チェックリストに Age Rating 項目追加) / § 4 (新 § 4.4 Age Rating reject 追加) |
| `RELEASE_v1.1.1_ASC_EN.md` | v1.1.1 ASC 英語 draft | § 3 Description (✅×6 / 🎯🏆📱🔒 除去) / § 6 What's New (✨🐛🌍 除去) / § 0 冒頭に "plain text only" 注意書き追加 |
| `~/.claude/skills/release-version-bump-check/SKILL.md` | 個人 global skill | description 拡張 / 新章「Other ASC pre-submission gotchas」追加 (Age Rating + en locale 絵文字 NG) |
| `CLAUDE.md` (project root) | プロジェクト指示 | 新節「ASC 提出時の落とし穴 (リリースで踏んだ learning)」を追加 (Age Rating + en 絵文字の 2 件) |

## ブランチ作成 (Task 0)

- [ ] **Step 1: 起点確認**

```bash
git status
git log --oneline -1
```

Expected:
- branch: `main`
- HEAD: `129491f` (= origin/main 最新)

- [ ] **Step 2: feature ブランチ作成**

```bash
git checkout -b docs/release-learnings-asc
```

Expected: `Switched to a new branch 'docs/release-learnings-asc'`

---

## Task 1: RELEASE_v1.1.2.md に Age Rating 反映 (Issue #86)

**Files:**
- Modify: `RELEASE_v1.1.2.md` (§ 1.5 / § 3 / § 4)

### 背景

Apple から 2026-05-23 にリジェクトメール受領 (Issue #86):

> An automated analysis of the submission indicates the app may include advertising but you did not select "Yes" for the "Advertising" content descriptor on the Age Rating selection in App Store Connect.

AdMob バナーを v1.1.0 以降に統合済み (#49 で RecordView 末尾にも追加) なのに ASC の Age Rating 設定で "Advertising" content descriptor が "Yes" になっていなかったため automated check で reject された。

### 編集内容

- [ ] **Step 1: § 1.5 App Privacy に Age Rating 注意を併記**

`RELEASE_v1.1.2.md` の § 1.5 (現状: AdMob Non-personalized 申告は変更なし) の末尾に **新段落** を追加:

```markdown
> ⚠️ **Age Rating の "Advertising" content descriptor は必ず "Yes" に設定**
>
> v1.1.2 提出時 (2026-05-23) に「AdMob を統合しているのに Age Rating の Advertising が No」で automated reject (Issue #86)。AdMob を組み込んだ v1.1.0 以降は **常に Advertising=Yes**。設定箇所は ASC → アプリ → 「App 情報」 → 「年齢制限指定」 → 「編集」 → 「広告」 → **「はい」** を選択 → 保存。Age Rating 結果が 4+ → 4+ (変更なし) でも申告自体は更新する必要がある。
```

- [ ] **Step 2: § 3 提出前チェックリスト > App Store Connect に Age Rating 項目を追加**

`RELEASE_v1.1.2.md` の § 3 「App Store Connect」サブセクションの **既存最終項目 (審査ノートに § 2.4 を貼り付け) の次** に追加:

```markdown
- [ ] **Age Rating で「広告」=「はい」になっていることを確認** ← #86 対策 (AdMob 統合済みのため必須)
```

- [ ] **Step 3: § 4 によくある reject 理由に Age Rating 節を追加**

`RELEASE_v1.1.2.md` の § 4.3 (「Kids カテゴリ要件を満たしていない」) の **次に新節として** 追加:

```markdown
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
```

- [ ] **Step 4: 0. 前提条件 に Age Rating 項目を追加**

`RELEASE_v1.1.2.md` の § 0 「前提条件」リスト末尾に追加:

```markdown
- ✅ ASC Age Rating で「広告」=「はい」設定済み (#86 対策、AdMob 統合済みのため必須)
```

- [ ] **Step 5: lint チェック**

```bash
npx markdownlint-cli2 'RELEASE_v1.1.2.md'
```

Expected: 0 violations (既存項目との整合性確認)。markdownlint が無ければ skip。

- [ ] **Step 6: Commit**

```bash
git add RELEASE_v1.1.2.md
git commit -m "$(cat <<'EOF'
docs(#86): RELEASE_v1.1.2.md に Age Rating Advertising=Yes 必須を反映

v1.1.2 提出時に automated review が AdMob 統合済みなのに Age Rating
"Advertising" が "No" であることを検知して reject (#86)。次回以降の
リリースで同じパターンを踏まないよう、提出手順書に予防策を追記:

- § 0 前提条件に "Age Rating Advertising=Yes 設定済み" を追加
- § 1.5 App Privacy 末尾に Age Rating 注意の併記
- § 3 提出前チェックリスト (ASC) に確認項目追加
- § 4.4 新節: Age Rating 設定漏れの reject パターン解説

ASC UI 側の修正自体はユーザーが別途実施 (この PR は docs 反映のみ)。
EOF
)"
```

---

## Task 2: en draft から絵文字を除去 (Issue #85)

**Files:**
- Modify: `RELEASE_v1.1.1_ASC_EN.md` (§ 0 冒頭注意書き / § 3 Description / § 6 What's New)
- Modify: `RELEASE_v1.1.2.md` (§ 2.5 What's New en)

### 背景

2026-05-23 の v1.1.1 ASC English locale 追加作業 (#82 で merge) で、英語版 Description / What's New に絵文字を含めると ASC が受け付けないことを確認 (Issue #85)。日本語ロケーションでは絵文字使用に問題なし (v1.1.1 What's New で ✨🐛🌍 を含めて公開実績あり)。Apple の公式ドキュメントには明示されていない ASC 実装ベースの挙動。

### 編集内容

- [ ] **Step 1: `RELEASE_v1.1.1_ASC_EN.md` § 3 Description の絵文字を除去**

該当箇所 (lines 54〜79 の code block 内):

```text
[Main features]
✅ Record chores with a single tap and earn coins
✅ Register multiple children, each with a personal theme color
✅ Customize the list of chores to match your home
✅ Monthly history view with automatic allowance calculation
✅ Monthly Retrospective screen — celebrate effort as a family
✅ Backdate entries when you forget to log right away

[What makes it different]
🎯 Simple, child-friendly design
🏆 Coin animations and sound effects to keep kids motivated
📱 Fully offline — no internet connection required
🔒 All data stays on your device only
```

**置き換え後**:

```text
[Main features]
- Record chores with a single tap and earn coins
- Register multiple children, each with a personal theme color
- Customize the list of chores to match your home
- Monthly history view with automatic allowance calculation
- Monthly Retrospective screen — celebrate effort as a family
- Backdate entries when you forget to log right away

[What makes it different]
- Simple, child-friendly design
- Coin animations and sound effects to keep kids motivated
- Fully offline — no internet connection required
- All data stays on your device only
```

§ 3 末尾の Notes / review points の 3 番目「Emojis are kept — the Japanese listing uses them and they render fine in both locales.」は **削除** し、代わりに以下に置き換え:

```markdown
- **Emojis are removed in the en locale** — ASC's automated check rejects emojis in the English Description / What's New text (Issue #85, confirmed 2026-05-23). The Japanese locale still accepts emojis, so `RELEASE_v1.1.1.md` の日本語 draft は触らない。
```

- [ ] **Step 2: `RELEASE_v1.1.1_ASC_EN.md` § 6 What's New の絵文字を除去**

該当箇所 (lines 129〜139 の code block 内):

```text
Version 1.1.1 brings a more stable home screen and improved English support ✨

🐛 Bug fixes
- Fixed an issue where your children's cards and stats sometimes failed to appear the first time the Home screen opened.
- Fixed the "Version" row on the Settings screen so it now shows the current version (1.1.1) correctly instead of an outdated number.

🌍 Improved English support
- Tab labels (Home / Record / Settings), the Retrospective screen, each section of the Settings screen, notification settings, and the body text of reminder notifications now display naturally in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it together with your family!
```

**置き換え後**:

```text
Version 1.1.1 brings a more stable home screen and improved English support.

Bug fixes
- Fixed an issue where your children's cards and stats sometimes failed to appear the first time the Home screen opened.
- Fixed the "Version" row on the Settings screen so it now shows the current version (1.1.1) correctly instead of an outdated number.

Improved English support
- Tab labels (Home / Record / Settings), the Retrospective screen, each section of the Settings screen, notification settings, and the body text of reminder notifications now display naturally in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it together with your family!
```

leading summary char-count コメント (line 142) も「**77 chars**」→「**70 chars**」に更新 (絵文字 ✨ + " " の 2 chars 減算)。

§ 6 末尾の Notes / review points の 1 番目「"Improved English support" keeps the same emoji and ordering as the Japanese version (🐛 then 🌍)…」は **削除** し、代わりに以下に置き換え:

```markdown
- **Section headers are plain text (no emojis)** in the en locale per Issue #85. The Japanese version keeps the 🐛 / 🌍 emoji ordering; the en draft mirrors only the ordering, not the emojis.
```

- [ ] **Step 3: `RELEASE_v1.1.1_ASC_EN.md` § 0 (冒頭) に注意書きを追加**

ファイル冒頭、L1〜L8 の bullet 3 つの最後 (L7) の **直後** に新 bullet を追加:

```markdown
- **No emojis in the en locale** (Issue #85): ASC's automated review rejects emojis in the English Description / What's New text fields. All en drafts in this document use plain text only. The Japanese locale (`RELEASE_v1.1.1.md`) is unaffected and keeps its emoji conventions.
```

- [ ] **Step 4: `RELEASE_v1.1.2.md` § 2.5 What's New (en) の絵文字を除去**

該当箇所 (lines 158〜172 の code block):

```text
Version 1.1.2 makes recording chores faster and more reliable ✨

✨ New
- Added Bulk Mode — pick multiple chores and record them in one go. Great for logging chores in batches after the kids are done.
- When a chore is already recorded for the same day, the task card now shows an "Already recorded N time(s)" badge so it's easy to avoid double-logging.

🐛 Bug fixes
- Fixed an issue where the chore history and monthly history sheets could appear empty the first time they were opened.

🌍 Improved English support
- Added English translations for alert messages, the default help task names, and count phrases (one / other variants), so the app feels more natural in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it with your family!
```

**置き換え後**:

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

加えて、§ 2.5 見出し直前の引用ブロック (lines 152〜157) の末尾に **1 行追加**:

```markdown
> - ⚠️ **絵文字は使用不可** (Issue #85): ASC 英語ロケーションは Description / What's New の絵文字を automated reject する。本 § のテキストは全て plain text。`§ 2.1` の ja draft は絵文字維持で OK (実績あり)。
```

- [ ] **Step 5: `RELEASE_v1.1.2.md` § 2.2 プロモーションテキスト en の絵文字確認**

`RELEASE_v1.1.2.md` の § 2.2 en promo (lines 126〜128) を確認:

```text
New Bulk Mode lets you record several chores at once. Same-day duplicates now show an "already recorded" hint, so logging chores stays effortless.
```

→ 絵文字なし。**編集不要**。本 step は確認のみ。

- [ ] **Step 6: lint チェック**

```bash
npx markdownlint-cli2 'RELEASE_v1.1.1_ASC_EN.md' 'RELEASE_v1.1.2.md'
```

Expected: 0 violations。MD031/032/040/060/029 (CLAUDE.md user memory の `feedback_markdown_lint.md` 準拠)。markdownlint が無ければ skip。

- [ ] **Step 7: Commit**

```bash
git add RELEASE_v1.1.1_ASC_EN.md RELEASE_v1.1.2.md
git commit -m "$(cat <<'EOF'
docs(#85): ASC 英語ロケーションの絵文字を全 en draft から除去

ASC の automated review が英語ロケーションの Description / What's New
text フィールドの絵文字を reject することを 2026-05-23 に確認 (#85)。
日本語ロケーションは絵文字 OK (v1.1.1 で公開実績あり)。

en draft の絵文字を plain text (ハイフン箇条書き + 通常見出し) に置換:

- RELEASE_v1.1.1_ASC_EN.md § 3 Description (✅×6 / 🎯🏆📱🔒)
- RELEASE_v1.1.1_ASC_EN.md § 6 What's New (✨ / 🐛 / 🌍)
- RELEASE_v1.1.2.md § 2.5 What's New en (✨ / 🐛 / 🌍)
- 両ファイル冒頭 / 該当章末尾の Notes に "no emojis in en" 注意書きを追加

ja draft (RELEASE_v1.1.1.md / RELEASE_v1.1.2.md § 2.1) は touch しない。
EOF
)"
```

---

## Task 3: `release-version-bump-check` skill に Age Rating + en 絵文字 learning を追記

**Files:**
- Modify: `~/.claude/skills/release-version-bump-check/SKILL.md`

### 設計判断

新 skill `asc-submission-checklist` を作るのではなく、既存 `release-version-bump-check` skill の scope を「リリース提出前 ITMS reject 予防全般」に少し拡張する。理由:

- core テーマ (リリース PR / 提出前にやるべき確認) が共通
- 新 skill にすると skill 数が増えて daily-issue-triage 時の検索が煩雑になる
- description は「ITMS 90186 / 90062 対策」が中心のままで、新章「Other ASC pre-submission gotchas」として下位章追加に留める

### 編集内容

- [ ] **Step 1: skill description を拡張**

`~/.claude/skills/release-version-bump-check/SKILL.md` L1〜L4 のフロントマター部分:

**Before**:

```yaml
---
name: release-version-bump-check
description: Use when preparing or reviewing an iOS App Store release PR — verifies that `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` are higher than the values App Store Connect has already approved, so the build is not rejected with ITMS-90186 ("train is closed") or ITMS-90062 ("CFBundleShortVersionString must contain a higher version"). Also covers the cross-target replace-all pitfall (12 occurrences for a typical app) and release-doc synchronization.
---
```

**After**:

```yaml
---
name: release-version-bump-check
description: Use when preparing or reviewing an iOS App Store release PR — verifies that `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` are higher than the values App Store Connect has already approved (so the build is not rejected with ITMS-90186 / ITMS-90062), and covers two other common pre-submission ASC rejects: the Age Rating "Advertising" content descriptor must be "Yes" when a banner ad SDK is integrated, and the English locale (Description / What's New) rejects emojis even though the Japanese locale accepts them. Also covers the cross-target replace-all pitfall (12 occurrences for a typical app) and release-doc synchronization.
---
```

- [ ] **Step 2: 新章「8. Other ASC pre-submission gotchas」を末尾近くに追加**

`~/.claude/skills/release-version-bump-check/SKILL.md` の「## Common Mistakes」(L188 付近) の **直前** に新章を追加:

```markdown
## Other ASC pre-submission gotchas

Version bump 以外でリリース直前に踏みやすい reject パターン 2 件。両方とも v1.1.2 OtetsudaiCoin リリースで踏み (Issues #85 / #86)、build の再アップロードを必要としない metadata-only fix で済むが、見落とすと automated review に弾かれて手戻りになる。

### Age Rating: 広告 SDK 統合時は "Advertising" content descriptor を Yes に

**症状**: 提出直後に自動レビューから以下のメッセージで reject される。

> An automated analysis of the submission indicates the app may include advertising but you did not select "Yes" for the "Advertising" content descriptor on the Age Rating selection in App Store Connect.

**根本原因**: AdMob / Google Mobile Ads / Facebook Audience Network などの広告 SDK を統合しているのに、ASC の Age Rating で "Advertising" content descriptor が "No" のまま。Apple の automated check が SDK 静的解析で広告統合を検知し、Age Rating 申告と齟齬があるとブロックする。

**対策** (ASC UI のみ、build 再アップロード不要):

1. ASC → アプリ → 「App 情報」 → 「年齢制限指定」 → 「編集」
2. 「広告」 (Advertising) の項目を **「はい」** に設定 → 保存
3. 設定変更だけで再提出可。Age Rating の結果 (4+ など) はほぼ変動しない

**予防**: リリース提出前チェックリストに「Age Rating Advertising=Yes 確認」項目を入れる。広告 SDK を組み込んだバージョン以降は常に Yes を維持する。

### 英語ロケーション (en): Description / What's New に絵文字を入れない

**症状**: en locale の Description / What's New に絵文字を含めて保存しようとすると ASC が受け付けない (具体的なエラー文言は Apple サポート経由でしか出ないことがあり、UI 上は silent fail も起きる)。日本語ロケーションでは絵文字 OK で、v1.1.x シリーズの ja What's New で ✨🐛🌍 を含めた公開実績あり。

**根本原因**: ASC 実装ベースの挙動 (Apple 公式ドキュメントには明示されていない)。en locale の text フィールドのみ絵文字フィルタが入っている模様。

**対策**:

- en draft では絵文字を使わず、見出しは plain text、箇条書きは `- ` (ハイフン) に統一する
- ja draft は絵文字維持で OK (両 locale で同じ書式を強制する必要なし)
- 既存 draft の確認対象: § Description / § What's New / § (subtitle / promotional text は短いので通常無関係だが絵文字を入れない方が無難)

**予防**: en draft section のテンプレに "plain text only, no emojis" の注意書きを残しておくと次回 release で踏まない。
```

- [ ] **Step 3: 「Quick Reference: ITMS error → fix」表に Age Rating 行を追加**

`~/.claude/skills/release-version-bump-check/SKILL.md` の「## Quick Reference: ITMS error → fix」表 (L165〜L169) の **「All three share a fix family」段落の直前** に追加:

**Before**:

```markdown
| ITMS-90478 | "Invalid Version" (build number not higher) | Bump `CURRENT_PROJECT_VERSION` past the last uploaded build. |

All three share a fix family: **the relevant version key must go up**.
```

**After**:

```markdown
| ITMS-90478 | "Invalid Version" (build number not higher) | Bump `CURRENT_PROJECT_VERSION` past the last uploaded build. |
| Age Rating reject (non-ITMS) | "...did not select 'Yes' for the 'Advertising' content descriptor" | ASC → App 情報 → 年齢制限指定 → 編集 → 広告 = はい (build 再アップロード不要) |
| en locale silent fail | en Description / What's New に絵文字 → ASC が保存できない / automated reject | en draft の絵文字を除去 (plain text + ハイフン箇条書き)。ja は維持で OK |

The ITMS family shares one fix (**the relevant version key must go up**); the bottom two are metadata-only fixes.
```

- [ ] **Step 4: 「## Common Mistakes」表に Age Rating + en 絵文字 行を追加**

`~/.claude/skills/release-version-bump-check/SKILL.md` の「## Common Mistakes」表末尾 (L197 付近、`忘れて tag を push し忘れた` 行の次) に **2 行追加**:

```markdown
| 広告 SDK を組み込んだのに Age Rating Advertising=No のまま | 提出直後に automated review reject (#86 OtetsudaiCoin v1.1.2) | ASC → 年齢制限指定で「広告」=「はい」に変更 (build 再アップロード不要) |
| en locale の Description / What's New に絵文字を入れた | ASC が保存できない or 提出後に reject (#85 OtetsudaiCoin) | en draft は plain text + ハイフン箇条書き。ja は絵文字維持で OK |
```

- [ ] **Step 5: 「## Real-World Impact」最終段落に v1.1.2 ケースを追記**

`~/.claude/skills/release-version-bump-check/SKILL.md` 末尾「## Real-World Impact」 (L199〜L201) の **後** に新段落を追加:

```markdown
v1.1.1 → v1.1.2 の提出 (2026-05-23) では別パターン 2 件を踏んだ: (a) AdMob 統合済みなのに ASC Age Rating の "Advertising" が No のままで automated reject (Issue #86)、(b) 英語ロケーションの What's New に絵文字 (✨🐛🌍) を入れたら ASC が受け付けない (Issue #85 — Phase 1 で en draft を初追加した際に発覚)。両方とも metadata-only fix (build 再アップロード不要) で復旧可能だが、リリース提出前のチェックリストに項目化しておけば 0 回目の提出で防げる。
```

- [ ] **Step 6: Commit**

```bash
git add ~/.claude/skills/release-version-bump-check/SKILL.md
git commit -m "$(cat <<'EOF'
skill(release-version-bump-check): Age Rating + en 絵文字 learning 追記

v1.1.2 OtetsudaiCoin リリース提出 (2026-05-23) で踏んだ 2 件の reject:
- Age Rating "Advertising" を Yes にしていない (#86, AdMob 統合済み)
- en locale Description / What's New に絵文字を入れた (#85)

両方とも build 再アップロード不要 metadata-only fix だが、提出前チェック
リストに無いと毎回踏みうる。version bump check の skill scope を
「リリース提出前 ITMS reject 予防全般」に少し拡張する形で取り込み:

- description に Age Rating + en 絵文字 NG の概要を追加
- 新章「Other ASC pre-submission gotchas」で 2 件の詳細解説
- Quick Reference 表に該当 reject パターンを 2 行追加
- Common Mistakes 表に該当 mistake を 2 行追加
- Real-World Impact に v1.1.2 ケースを追記

skill 名 / 主たる version bump フローは変更なし。
EOF
)"
```

---

## Task 4: CLAUDE.md に learning 追記

**Files:**
- Modify: `CLAUDE.md` (project root, L74 付近 = 「## プロジェクト固有制約 (Xcode 16+)」の直前あたり)

### 編集内容

- [ ] **Step 1: 新節「## ASC 提出時の落とし穴 (リリースで踏んだ learning)」を追加**

`CLAUDE.md` の **「## プロジェクト固有制約 (Xcode 16+)」セクションの直前** に新節を追加 (CLAUDE.md L74 付近、`## Simulator 視覚検証の限界` より上の位置 — ファイル末尾近くで「リリース」「ASC」関連の learning がまとまっている `## i18n: xcstrings plural variations の呼び出し` 等の近くがベター。

実際の挿入位置は `## ASC 提出時の落とし穴` を `## Simulator 視覚検証の限界` (L113 付近) の **直前** に置く形でも良い。executing-plans 時に CLAUDE.md を再読してから最終位置を決める。):

```markdown
## ASC 提出時の落とし穴 (リリースで踏んだ learning)

- **Age Rating の「広告」=「はい」設定が必須** (Issue #86, v1.1.2 提出時 2026-05-23): AdMob (Google Mobile Ads) を統合した v1.1.0 以降は、ASC → App 情報 → 年齢制限指定で「広告」を必ず「はい」に設定する。No のままだと automated review が SDK 統合を検知して reject する。metadata-only fix なので build 再アップロードは不要、ASC UI で切替えるのみ。リリース手順書 (`RELEASE_vX.Y.Z.md`) の提出前チェックリストに項目化済み。
- **英語ロケーションの Description / What's New には絵文字を入れない** (Issue #85, 2026-05-23): ASC は en locale の text フィールドの絵文字を弾く (公式ドキュメント未明記の挙動)。日本語ロケーションでは絵文字 OK (v1.1.1 ja What's New で ✨🐛🌍 を公開実績あり)。en draft は plain text 見出し + `- ` ハイフン箇条書きで統一する。`RELEASE_vX.Y.Z.md` § What's New (en) / `RELEASE_vX.Y.Z_ASC_EN.md` 系の draft section に "plain text only, no emojis" 注意書きを残す運用とする。
- スキル: [[release-version-bump-check]] が version bump + Age Rating + en 絵文字 NG をまとめてカバー。リリース PR 作成時に必ず invoke する。
```

- [ ] **Step 2: lint チェック**

```bash
npx markdownlint-cli2 'CLAUDE.md'
```

Expected: 0 violations。markdownlint が無ければ skip。

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(CLAUDE.md): ASC 提出時の落とし穴 learning 追記 (#86 / #85)

v1.1.2 リリース提出 (2026-05-23) で踏んだ 2 件の ASC reject パターン
を、次回以降のリリース session が CLAUDE.md ロード時に拾えるよう追記:

- Age Rating の「広告」=「はい」設定が必須 (#86, AdMob 統合済み)
- 英語ロケーションの Description / What's New に絵文字を入れない (#85)

詳細手順と reject メッセージの全文は release-version-bump-check skill
と RELEASE_v1.1.2.md § 4.4 に格納済み。CLAUDE.md には learning 要点と
skill 参照のみ。
EOF
)"
```

---

## Task 5: Verification

- [ ] **Step 1: 全 commit が積まれていることを確認**

```bash
git log --oneline origin/main..HEAD
```

Expected: 4 commits (Task 1〜4 で作成、commit メッセージは `docs(#86):` / `docs(#85):` / `skill(release-version-bump-check):` / `docs(CLAUDE.md):` 系)

- [ ] **Step 2: 変更ファイル一覧の妥当性確認**

```bash
git diff --name-only origin/main..HEAD
```

Expected:
- `RELEASE_v1.1.2.md`
- `RELEASE_v1.1.1_ASC_EN.md`
- `CLAUDE.md`
- (`~/.claude/skills/release-version-bump-check/SKILL.md` は git 外なので一覧に出ないが、別途 `cat ~/.claude/skills/release-version-bump-check/SKILL.md | head -30` で description 拡張が反映されていることを確認)

- [ ] **Step 3: 絵文字が en draft 内に残っていないか grep**

```bash
grep -nE '[✅🎯🏆📱🔒✨🐛🌍]' RELEASE_v1.1.1_ASC_EN.md RELEASE_v1.1.2.md
```

Expected output (絵文字残存箇所):
- `RELEASE_v1.1.2.md` の **ja What's New (§ 2.1) の中**にある ✨🐛🌍 は **意図的に残す** (ja locale は絵文字 OK)。
- それ以外の hit があれば置換漏れ → 該当箇所修正。
- ja draft 内の絵文字 (§ 2.1) と「⚠️」「⚙️」など UI/コメント絵文字は除外して読む。

確認用に grep 結果を visual review。

- [ ] **Step 4: skill 更新の動作確認**

```bash
grep -c "Age Rating" ~/.claude/skills/release-version-bump-check/SKILL.md
grep -c "no emojis\|en locale" ~/.claude/skills/release-version-bump-check/SKILL.md
```

Expected: 両 grep とも 1 以上 (新章「Other ASC pre-submission gotchas」配下にヒット)。

---

## Task 6: Push + PR 作成

- [ ] **Step 1: 同一ブランチ既存 PR がないことを再確認** (CLAUDE.md ルール準拠)

```bash
gh pr list --head docs/release-learnings-asc --state all
```

Expected: 空 (新規ブランチなので何もないはず)

- [ ] **Step 2: HEAD ブランチを再確認** (CLAUDE.md ルール準拠)

```bash
git status
```

Expected: `On branch docs/release-learnings-asc`、clean tree

- [ ] **Step 3: push**

```bash
git push -u origin docs/release-learnings-asc
```

- [ ] **Step 4: PR 作成**

```bash
gh pr create --title "docs(#86, #85): ASC 提出時の落とし穴 learning を skill + docs に反映" --body "$(cat <<'EOF'
## Summary

v1.1.2 リリース提出サイクル (2026-05-23) で踏んだ ASC reject 2 件の learning を、次回以降のリリースで自動的に避けられるよう CLAUDE.md / `release-version-bump-check` skill / RELEASE doc に反映します。

- **#86 (release blocker)**: AdMob 統合済みなのに ASC Age Rating の "Advertising" を "Yes" にしていなかったため automated review が reject。ASC UI 操作は別途ユーザーが実施するので、本 PR は docs/skill 反映のみ。
- **#85**: 英語ロケーションの Description / What's New に絵文字 (✨🐛🌍 / ✅🎯🏆📱🔒) を入れると ASC に弾かれる。en draft 3 箇所から絵文字除去 + 注意書き追加。

## Changes

| 種別 | ファイル | 変更内容 |
|---|---|---|
| docs | `RELEASE_v1.1.2.md` | § 0 / § 1.5 / § 3 / § 4.4 に Age Rating Advertising=Yes の手順追加 (#86), § 2.5 What's New (en) から絵文字除去 (#85) |
| docs | `RELEASE_v1.1.1_ASC_EN.md` | § 0 冒頭に "no emojis in en" 注意書き, § 3 Description (✅×6 / 🎯🏆📱🔒) と § 6 What's New (✨🐛🌍) を plain text 化 (#85) |
| skill | `~/.claude/skills/release-version-bump-check/SKILL.md` (個人 global) | description 拡張 + 新章「Other ASC pre-submission gotchas」+ Quick Reference 表 / Common Mistakes 表 / Real-World Impact 追記 |
| docs | `CLAUDE.md` | 新節「## ASC 提出時の落とし穴 (リリースで踏んだ learning)」を追加。Age Rating + en 絵文字の 2 件を要点だけ記載し詳細は skill / RELEASE doc を参照 |

## Out of Scope

- **ASC UI 側の Age Rating 修正** はユーザーが ASC 上で別途実施 (PR merge とは independent)。
- **v1.1.2 本体の build 再アップロード** は不要 (metadata-only fix)。pbxproj 触らない。
- **Issue #50 Phase 2 の進行** は v1.1.2 受理後に別 session で対応。

## Test plan

- [ ] `RELEASE_v1.1.2.md` の Age Rating セクション (§ 4.4 / § 3 チェックリスト) を読み、手順だけで ASC UI を操作できることを確認
- [ ] `RELEASE_v1.1.1_ASC_EN.md` を読み、en draft 全文に絵文字が残っていないこと (ja 側の引用部分や注意書きの ⚠️ 等は除外) を確認
- [ ] `~/.claude/skills/release-version-bump-check/SKILL.md` を読み、新章が version bump 本筋を邪魔せず追記されていることを確認
- [ ] `CLAUDE.md` 新節が既存節と並列で読めること、related skill ([[release-version-bump-check]]) リンクが正しいことを確認
- [ ] `grep -nE '[✅🎯🏆📱🔒✨🐛🌍]' RELEASE_v1.1.1_ASC_EN.md RELEASE_v1.1.2.md` で意図しない絵文字残存がないことを確認 (ja What's New § 2.1 の絵文字は意図的に残す)

## Related

- Closes #86 (docs/skill 反映完了、ASC UI 修正はユーザーが別途実施)
- Closes #85
- Related skill: [[release-version-bump-check]]
- Related release doc: `RELEASE_v1.1.2.md` / `RELEASE_v1.1.1_ASC_EN.md`
EOF
)"
```

Expected: PR URL が返る。

- [ ] **Step 5: PR URL をユーザーに共有**

PR URL を message に含めて返す。

---

## Self-Review (writing-plans skill 内 review)

**Spec coverage**:
- #86 (Age Rating reject) → Task 1 (RELEASE_v1.1.2.md 反映) + Task 3 (skill 反映) + Task 4 (CLAUDE.md 反映) ✓
- #85 (en 絵文字弾き) → Task 2 (RELEASE_v1.1.1_ASC_EN.md + RELEASE_v1.1.2.md § 2.5 修正) + Task 3 (skill 反映) + Task 4 (CLAUDE.md 反映) ✓
- ASC UI 操作はユーザー担当として Out of Scope 明示済み ✓
- 1 PR / 4 commit / `docs/release-learnings-asc` ブランチ ✓

**Placeholder scan**: 全 step に code block or 具体テキスト含む。「TBD」「実装する」などのプレースホルダなし ✓

**Type consistency**: docs only なので型整合性は無関係。skill 内の見出し名 (「Other ASC pre-submission gotchas」) を Task 3 内で一貫使用 ✓

**追加メモ**:
- markdownlint 実行は環境にコマンドが無ければ skip 可能なように記述
- CLAUDE.md の挿入位置は executing 時に最終決定 (関連 learning がまとまっている末尾近くを優先)
- Task 5 Step 3 の grep は ja What's New (§ 2.1) の絵文字を visual review で除外する手順を明記
