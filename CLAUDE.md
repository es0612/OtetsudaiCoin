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

## Subagent / Task 実行ルール
- subagent の存在意義は「context 隔離」。コード変更を伴う Task は subagent、verification / test 実行のみで成果物が無い Task は main 実行でも可。subagent 接続エラー時に verification-only なら即時 main 実行へフォールバックする。

## iOS テスト flake 切り分け
- 並列 simulator run で UI テスト・load 系テストが flaky に落ちることがある。regression と断定する前に該当テストを `xcodebuild test -only-testing:` で isolated 再実行し、PASS すれば parallel flake として扱う（本修正と無関係な既知問題として切り分け可能）。

## CI スクリプト開発ルール
- bash 系 CI スクリプトは push 前にローカルで全シナリオ (pass / fail / enforce / info などのモード分岐すべて) を実行し網羅検証する。本番 GitHub Actions で初めて挙動を確認するスタイルは 1 サイクル数分 × 修正回数のロスになる。
- リリース系の自動チェック CI は、(a) `paths` フィルタで対象ファイル変更時のみ起動、(b) PR ラベル / タイトルで enforce (失敗で blocking) と info (警告のみ) を二段階に切り替える設計にすると、false positive と CI 時間を両方抑制できる。

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

