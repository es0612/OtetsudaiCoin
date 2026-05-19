# Claude Code Spec-Driven Development

Kiro-style Spec Driven Development implementation using claude code slash commands, hooks and agents.

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`
- Commands: `.claude/commands/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro:spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, but generate responses in Japanese (思考は英語、回答の生成は日本語で行うように)

## Workflow

### Phase 0: Steering (Optional)
`/kiro:steering` - Create/update steering documents
`/kiro:steering-custom` - Create custom steering for specialized contexts

Note: Optional for new features or small additions. You can proceed directly to spec-init.

### Phase 1: Specification Creation
1. `/kiro:spec-init [detailed description]` - Initialize spec with detailed project description
2. `/kiro:spec-requirements [feature]` - Generate requirements document
3. `/kiro:spec-design [feature]` - Interactive: "Have you reviewed requirements.md? [y/N]"
4. `/kiro:spec-tasks [feature]` - Interactive: Confirms both requirements and design review

### Phase 2: Progress Tracking
`/kiro:spec-status [feature]` - Check current progress and phases

## Development Rules
1. **Consider steering**: Run `/kiro:steering` before major development (optional for new features)
2. **Follow 3-phase approval workflow**: Requirements → Design → Tasks → Implementation
3. **Approval required**: Each phase requires human review (interactive prompt or manual)
4. **No skipping phases**: Design requires approved requirements; Tasks require approved design
5. **Update task status**: Mark tasks as completed when working on them
6. **Keep steering current**: Run `/kiro:steering` after significant changes
7. **Check spec compliance**: Use `/kiro:spec-status` to verify alignment

## Git / PR 運用ルール
- **feature branch に追加 commit する前**に、対応する PR が merge 済みでないかを `gh pr view <PR> --json mergedAt,state` で確認する。merge 後にローカル branch へ commit すると main に届かず、follow-up PR が必要になる。
- **別目的の PR に無関係なファイルを同梱しない**（例: retrospective ドキュメント PR に別 issue の修正計画 plan.md を載せない）。実装対象 issue の feature branch に保管し、必要なら独立した PR を切る。
- **push / PR 作成の直前**に `git status` で HEAD ブランチを再確認する。別ターミナル・別 Claude セッション・外部プロセスがブランチを切り替えている可能性があり、意図しないブランチへの push を防ぐ。
- **PR 作成の前**に `gh pr list --head <branch>` で同一ブランチの既存 PR を確認する。並列セッションが先に push&PR を作っているケースがあり、二重作成や test plan 上書きを避ける。
- **新ブランチを切る前 / feature branch を作業し直す前**に `git fetch origin` を走らせ、`origin/main` を起点にする。ローカル `main` が遅れていると古い起点でブランチを切ってしまい、後で rebase / cherry-pick の手戻りになる。
- **同一ファイル (CLAUDE.md など) を複数の feature branch から並行更新する場合**は、後発 PR を先発 PR の merge 後に `origin/main` から派生させる。同じ insertion point に並行追記すると conflict で手戻る。先発 PR がまだ open なら、後発の追記は先発に rebase する or 先発 merge 完了まで待つ。並行 session で同じ文書を触る予定があるときは、PR 作成前に `gh pr list --search "CLAUDE.md in:title"` 等で先行 PR の有無を確認する。

## Subagent / Task 実行ルール
- subagent の存在意義は「context 隔離」。コード変更を伴う Task は subagent、verification / test 実行のみで成果物が無い Task は main 実行でも可。subagent 接続エラー時に verification-only なら即時 main 実行へフォールバックする。

## iOS テスト flake 切り分け
- 並列 simulator run で UI テスト・load 系テストが flaky に落ちることがある。regression と断定する前に該当テストを `xcodebuild test -only-testing:` で isolated 再実行し、PASS すれば parallel flake として扱う（本修正と無関係な既知問題として切り分け可能）。

## CI スクリプト開発ルール
- bash 系 CI スクリプトは push 前にローカルで全シナリオ (pass / fail / enforce / info などのモード分岐すべて) を実行し網羅検証する。本番 GitHub Actions で初めて挙動を確認するスタイルは 1 サイクル数分 × 修正回数のロスになる。
- リリース系の自動チェック CI は、(a) `paths` フィルタで対象ファイル変更時のみ起動、(b) PR ラベル / タイトルで enforce (失敗で blocking) と info (警告のみ) を二段階に切り替える設計にすると、false positive と CI 時間を両方抑制できる。

## Spec / Plan 作成ルール
- spec / design ドキュメント作成時にも前提となる既存コードを実際に Read で開いて verify する。writing-plans 段階で初めて View 階層など実装差分が判明すると spec 修正に手戻りが発生する。spec 段階で View 階層・主要関数の実装を 1 回 Read してから書き起こす。
- Plan からの「既存 convention に合わせるための設計改善的逸脱」は、その場で commit メッセージに deviation 理由を明記して反映する（例: 新規 `XxxViewTests.swift` を作る計画を既存 `BannerAdViewTests.swift` 等に揃える）。事前に plan を rewrite しない（時間ロス）、事後に黙って逸脱しない（レビュー時に混乱）。
- spec 作成時のテストファイル存在確認は、`ls Presentation/ViewModels/` のような浅い listing ではなく `find . -name "X*Tests.swift" -not -path "*build*"` で全階層から探す。サブディレクトリ前提で見落とすと spec の前提が崩れて自己修正 commit が必要になる。

## プロジェクト固有制約 (Xcode 16+)
- このプロジェクトの Xcode project は `PBXFileSystemSynchronizedRootGroup` を採用しているため、新規 `.swift` を所定ディレクトリに置くだけで自動認識され `project.pbxproj` 編集は不要。Plan 作成や Task 見積もりで「pbxproj 編集ステップ」を blocker 扱いしない。

## SwiftUI View テスト戦略
- ViewInspector は NavigationStack + ZStack + UIViewRepresentable (BannerAdView) + Material の組み合わせを深く traverse できない既知制約がある。`find(viewWithAccessibilityIdentifier:)` / `find(text:)` / `find(ViewType.X.self)` いずれも該当 view へ到達不可、`"Search did not find a match. Possible blockers: BannerAdView, Material, AccessibilityImageLabel"` で fail する。
- 上記が予想される View では UI 構造の structural test を強行せず、(a) ViewModel テストでロジック網羅 + (b) View の smoke test (init crash なし) + (c) behavior test (toggle/binding が ViewModel state を動かすこと) で間接担保、UI の最終 visual は simulator 手動 / UI test に委ねる。
- 該当 View の refactor を入れるなら BannerAdView を component 分離 / Material 依存を Color 系に置換 する方向で別 issue 化する (例: #74)。

## i18n: xcstrings plural variations の呼び出し
- xcstrings の `variations.plural` (one / other) を Swift 側から有効化するには **string interpolation** が必須。`String(localized: "%lld 件...") + String(format: format, count)` の組み合わせは plural 解釈を bypass して常に `other` を返す。
- 正しい書き方: `String(localized: "\(count) 件...")` (`String.LocalizationValue` の placeholder に値を渡すと plural branch が選ばれる)。catalog のキーは `%lld` 形式のまま (`"%lld 件..."`) で、value 側も `%lld` を保つ。
- 詳細は [[xcstrings-plural-variations]] skill にまとめている。複数キー追加時は [[xcstrings-bulk-update]] と併用。
- count=1 のときに `one` バリアントが効くことを unit test (`XCTAssertTrue(message.contains("1"))` 程度でよい) で 1 件担保しておくと runtime bypass の regression を catch できる。

## NotificationManager 発火と error message の干渉
- `NotificationManager.shared.notifyHelpRecordUpdated()` (および類似の data-update 通知) を呼ぶと、observer 側で `loadData()` → `setLoading(true)` が走り、その副作用で `errorMessage` がクリアされる (`BaseViewModel.setLoading` の挙動: `if loading { errorMessage = nil }`)。
- このため write 操作が **0 件しか成功しなかった場合に notify を呼ぶと、直前に `setError(...)` でセットした errorMessage が消えてしまう**。write が 1 件以上成功したときだけ notify する設計にする (`if !successIds.isEmpty { notify() }`)。
- `successMessage` は `setLoading(true)` で消えないので、success のみ気にする既存パターン (`recordHelp` 等) では問題化しなかった。一括 / batch 系の新規実装で踏みやすい罠。

## Steering Configuration

### Current Steering Files
Managed by `/kiro:steering` command. Updates here reflect command changes.

### Active Steering Files
- `product.md`: Always included - Product context and business objectives
- `tech.md`: Always included - Technology stack and architectural decisions
- `structure.md`: Always included - File organization and code patterns

### Custom Steering Files
<!-- Added by /kiro:steering-custom command -->
<!-- Format:
- `filename.md`: Mode - Pattern(s) - Description
  Mode: Always|Conditional|Manual
  Pattern: File patterns for Conditional mode
-->

### Inclusion Modes
- **Always**: Loaded in every interaction (default)
- **Conditional**: Loaded for specific file patterns (e.g., "*.test.js")
- **Manual**: Reference with `@filename.md` syntax

