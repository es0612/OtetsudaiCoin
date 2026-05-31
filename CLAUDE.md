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
- **SessionStart hook が生成する `pending-reflection.md` の処理**: 前 session の feature branch (PR merge 済み) に checked-out したまま新 session を開始すると、hook が `pending-reflection.md` を merged branch 上に置いてしまう。そのまま commit しても main には届かないので、SessionStart 直後の最初のステップに `gh pr view <前 session の PR> --json mergedAt,state` で merge 状態確認を組み込み、merged だった場合は **stash → `git fetch origin && git checkout main && git merge --ff-only` → docs 専用ブランチ作成 → stash pop → 独立 PR** の流れに切替える。merged branch 上で hook 出力を編集し始めない。
- **リリース reject / 障害対応では本体 fix PR と再発防止 PR を同セッションで並走させる**: 本体 fix PR (例 #98) を切ったら merge を待たず、別 branch で再発防止 PR (CLAUDE.md / skill 追記、例 #99) を即座に切って並走させる。本体 fix が ASC review queue 等に入る待ち時間が learnings を寝かせるリスクを生むので、retrospective を merge 後ではなく fix PR open 中に走らせる。reviewer も「修正 + 再発防止策」を同時に確認できる。既存「別目的の PR に無関係なファイルを同梱しない」ルールの **許容される並走 pattern** として明文化する。**並走が安全な前提は両 PR が別ファイルを触ること** (本体 = コード、再発防止 = CLAUDE.md)。同一ファイルを並行更新する場合は上記「同一ファイルを複数 feature branch から並行更新」ルールに従い、後発を先発 merge 後に `origin/main` から派生させる。

## Subagent / Task 実行ルール
- subagent の存在意義は「context 隔離」。コード変更を伴う Task は subagent、verification / test 実行のみで成果物が無い Task は main 実行でも可。subagent 接続エラー時に verification-only なら即時 main 実行へフォールバックする。

## daily-issue-triage 運用ルール
- triage 開始時に `gh issue list` を取得したら、**各 issue body が参照する spin-off / 実装 PR の `mergedAt` をまとめて先に確認する**。手順は (a) `gh issue list` で全 open issue を取得 → (b) body 内の `#NNN` PR 参照を抽出 → (c) `gh pr view <PR> --json mergedAt,state` で merge 状況を一括確認。本体機能が PR で merge 済みなのに close 漏れしている issue (例: #69 が PR #72 で実質完了していたケース) を triage 表の集約段階で「対応不要 (close のみ)」に振り分けられ、調査スコープ判断時間を節約できる。
- **全 open issue が "Blocked by external" (デザイン判断・リリース戦略待ち等) だった場合の出口戦略**: コード着手 0 件で triage を終了する代わりに、戦略判断系 issue を 1 件選び `superpowers:brainstorming` で結論をまとめ、**writing-plans に hand off せず issue body 更新 (もしくは comment) で skill を完了する** flow に切替える。brainstorming の terminal artifact は通常 plan だが、ゴールが「決定の記録」だけの場合は issue body 更新がそれに該当する。skill 適応理由 (writing-plans を呼ばない判断) を user-facing に明言してから入ると、reviewer が flow 逸脱を追える。
- **「その issue は既に修正済みでないか」を `git log -- <file>` (全履歴) で検証してから着手する。`git log -S <症状文字列>` だけに頼らない**: 修正コミットが症状文字列とは**別の行**に当たっている場合 pickaxe `-S` には出ず、見落として「既に直っているものを再実装」しかける。実例: #89#3 (en「Selected」hyphenation) を `git log -S '選択中'` で探したが、真の修正 2f4480d は `Text("選択中")` ではなく `.frame(width: 100→120)` 行に当たっていたため出ず、危うく再修正 PR を切るところだった。**手順**: (a) 既存ルール通り body の `#NNN` PR 参照の `mergedAt` を確認 → (b) **加えて** issue createdAt 以降の `git log --since=<createdAt> -- <関連ファイル>` で **PR 参照に現れない直接 commit による修正** も検出する (#89#2=e6fea96, #89#3=2f4480d はいずれも issue 本文に PR 参照が無く直接 commit で修正済みだった) → (c) 疑わしいコミットを `git show <sha>` で diff 確認。ASC スクショ等の visual artifact が最新 commit を反映しているかは `git log -- <png>` の最終 commit が `origin/main` の祖先か (`git merge-base --is-ancestor`) で裏取りする。triage の価値の大半は「既修正の検出」になることがある (#89 は 4 sub-item 中 2 件が既修正・1 件が別 issue 分離済みで、コード作業ゼロだった)。

## Verification / Visual review 運用ルール
- **Out-of-scope finding は本 PR で fix しない**: visual verification (screenshot / output 目視) で本来スコープ外の bug / regression を発見した場合、その PR 内で fix しようとしない。代わりに (a) PR description に finding を inline 記載 + (b) PR merge 後に **epic issue** を立てて優先順位 / target release version (例: #1 → v1.2 / #2-#4 → v1.1.3) を body に含める運用にする。本体 PR のスコープを clean に保ちつつ findings を triage 可能な形で残せる (#88 → Issue #89 で確立)。
- **User 介在の verification step (画像目視 等) は assistant が一次目視してから判断仰ぐ**: visual review を user に丸投げせず、assistant 側で全 artifact を読んで所見 (内訳 / 残課題) を表でまとめた上で「この内容で OK ですか / 追加課題ありますか」と AskUserQuestion する。user の判断負荷が下がり、out-of-scope finding の検出確度が上がる (#88 で i18n 漏れ 4 件発見の起点となった flow)。

## iOS テスト flake 切り分け
- 並列 simulator run で UI テスト・load 系テストが flaky に落ちることがある。regression と断定する前に該当テストを `xcodebuild test -only-testing:` で isolated 再実行し、PASS すれば parallel flake として扱う（本修正と無関係な既知問題として切り分け可能）。
- **background で `xcodebuild test` を chain 実行したら、報告される完了 exit code を鵜呑みにしない**: `xcodebuild ... > log 2>&1; echo "exit=$?"` を background 実行すると、harness が報告する**完了 exit は chain 末尾の `echo` の 0** になり、xcodebuild の real exit (65 = `** TEST FAILED **`) を隠す。「exit 0」通知を信じて緑判定すると失敗を見逃す。必ず log 末尾の `exit=` 行を `grep "^exit="` で読むか、`grep -F "** TEST FAILED"` / `Failing tests:` で結果を確認してから判定する。なお `find(viewWithAccessibilityIdentifier:)` 系の失敗詳細はストリーム log に出ないことがあるので、`.xcresult` を `xcrun xcresulttool get test-results tests --path <xcresult>` で開いて failure message を取る (`AccessibilityImageLabel` blocker 等の真因はここでしか見えない)。

## CI スクリプト開発ルール
- bash 系 CI スクリプトは push 前にローカルで全シナリオ (pass / fail / enforce / info などのモード分岐すべて) を実行し網羅検証する。本番 GitHub Actions で初めて挙動を確認するスタイルは 1 サイクル数分 × 修正回数のロスになる。
- リリース系の自動チェック CI は、(a) `paths` フィルタで対象ファイル変更時のみ起動、(b) PR ラベル / タイトルで enforce (失敗で blocking) と info (警告のみ) を二段階に切り替える設計にすると、false positive と CI 時間を両方抑制できる。
- **bash script を検証するときは本番と同じ shebang (`/bin/bash`) で実行する**: Bash tool は zsh で動くため、`[[ ... =~ ... ]]` のキャプチャは `$BASH_REMATCH` ではなく zsh の `$match` に入り、`$BASH_REMATCH` は**無言で空**になって誤診断を招く (#96 で BASH_REMATCH を真因と誤認しかけた起点)。offline 検証は `bash script.sh` か実行ビット経由で流し、`sh -c` / 素の zsh で叩かない。
- **bash script の外部バイナリ解決は `--version` のライブ実行で確認する (`-x` チェックでは不十分)**: 破損した asdf shim (`~/.asdf/shims/jq` → 存在しない libexec) は実行ビットが立つので `-x` を通過するが、実呼び出しで exit 126 で落ちる。PATH 先頭の shim を盲信せず、候補を `--version` で実行確認しながら選び、`JQ` 等の env override も用意する (#96 の `resolve_jq` パターン)。

## エラー / reject 診断の初動ルール
- **reject email / CI failure log を受け取ったら、原因仮説を立てる前に固有文言を verbatim で抜き出す**: ITMS コードやエラーキー (`previously approved version [X.Y.Z]`, `train ... closed`, `must contain a higher version`、CI なら exit code + 該当 step 名 + assertion 文言) を先に quote して並べてから診断を始める。実例: v1.1.3 の ITMS reject で initial diagnosis を「reject 後の再 upload で bump 忘れ」と書き始めた後、reject email を再読して `previously approved version [1.1.2]` の文言から「**approved 後の** next-version bump 忘れ」が正解と判明し、CLAUDE.md / PR description を書き直す手戻りが発生した (PR #98)。key string を先に固定してから原因仮説を組み立てると、初診ズレによる成果物の書き直しを防げる。ASC reject に限らず CI / runtime error の診断全般に適用する。
- **issue 本文の「原因(推定)」「対応案」を鵜呑みにせず、疑われた箇所を `git blame` + 実再現で検証してから fix する**: 起票時の診断はしばしば誤り。#96 は「BASH_REMATCH が zsh で動かない」を疑ったが真因は bare `jq` の asdf shim 破損 (red herring)、#97 は「`sleep 2` 不足 → 4 に増やせ」と書かれていたが `git blame` で sleep は初版から `4` = 提案 fix は適用済みかつ無効と判明 (真因は splash crossfade の cold/warm race)。**1 PR で 2 件踏んだ**。issue の提案 fix を貼る前に、(a) 疑われた行を `git blame` で履歴確認、(b) 失敗をローカル再現、の 2 点を必ず通す。

## Spec / Plan 作成ルール
- spec / design ドキュメント作成時にも前提となる既存コードを実際に Read で開いて verify する。writing-plans 段階で初めて View 階層など実装差分が判明すると spec 修正に手戻りが発生する。spec 段階で View 階層・主要関数の実装を 1 回 Read してから書き起こす。
- Plan からの「既存 convention に合わせるための設計改善的逸脱」は、その場で commit メッセージに deviation 理由を明記して反映する（例: 新規 `XxxViewTests.swift` を作る計画を既存 `BannerAdViewTests.swift` 等に揃える）。事前に plan を rewrite しない（時間ロス）、事後に黙って逸脱しない（レビュー時に混乱）。
- spec 作成時のテストファイル存在確認は、`ls Presentation/ViewModels/` のような浅い listing ではなく `find . -name "X*Tests.swift" -not -path "*build*"` で全階層から探す。サブディレクトリ前提で見落とすと spec の前提が崩れて自己修正 commit が必要になる。
- **Plan 実行中の user 応答による deviation の取り扱い**: writing-plans 中の AskUserQuestion で plan を reverse / scope 縮小した場合 (例: BannerAdView 移動 → 維持、追加 test 3 件 → 1 件)、plan 本体も書き換えた上で PR description の `## Plan からの逸脱` 節に deviation 理由を明記する。reviewer が「なぜ plan と差分があるのか」を追えるようにすると、レビュー時の混乱を防げる。
- **TDD の red verification step skip 条件**: red 段階の `xcodebuild test` 実行を skip 可能なのは、(a) コンパイルエラー確定 (型 / メソッド未定義で `BUILD FAILED` 必至)、(b) 直接的な期待値差 (`XCTAssertEqual` の数値ずれが impl 不在で必ず起きる) の場合のみ。skip した場合は commit メッセージと PR description の `## Plan からの逸脱` に skip 理由を明記して reviewer が追えるようにする。behavioral edge case (observer 経路、race condition、`setLoading` 副作用などタイミング依存) を試す red は **必ず実行** して fail を確認する。スキップすると「green になったが期待した経路ではなかった」を見逃す。
- **Plan の Task に global skill (`~/.claude/skills/`) 更新を含めない**: Plan / spec 作成時に `git ls-files | grep .claude/skills/` で対象 skill が project 内 (`.claude/skills/`) か global (`~/.claude/skills/`) かを確認する。global skill 更新を Task に含めると **project repo の `git add` 対象外**になり、Task 実行時に「Plan に書いたのに commit に入らない」逸脱が必発する (前 session で発生)。global skill 更新が必要な場合は別 step に分離し、PR description の `## Plan からの逸脱` 節に skill 更新内容を明記する運用にする。逸脱を事後説明するのではなく、Plan 設計時に分岐させる。

## プロジェクト固有制約 (Xcode 16+)
- このプロジェクトの Xcode project は `PBXFileSystemSynchronizedRootGroup` を採用しているため、新規 `.swift` を所定ディレクトリに置くだけで自動認識され `project.pbxproj` 編集は不要。Plan 作成や Task 見積もりで「pbxproj 編集ステップ」を blocker 扱いしない。

## Simulator 視覚検証の限界
- `xcrun simctl` には `tap` / `gesture` / `type` が存在しないため、CLI から UI を操作できない。`ios-simulator-app-verification` skill で UserDefaults / launch args 経由で state を pre-set してから launch するパターンを使う。
- **TabView の選択 tab が `@State private var selectedTab = 0` (永続化なし) の場合、simctl 経由では他 tab へ切替不可**。RecordView 等 sub-tab の視覚検証が必要なら、(a) `@AppStorage` 化して `simctl spawn defaults write` で切替えるか、(b) XCUITest で tab tap シミュレートに切替える判断を **plan 段階で** しておく。実行中に気付くと verification が部分的になり、PR description で「手動確認推奨」と明示する妥協が必要になる (#74 PR #77 で発生)。
- **(b) XCUITest 解の実績** (#88 ASC スクショ撮影): tab は `app.tabBars.buttons.element(boundBy:)` で位置参照すれば locale-agnostic に切替可能。スクショ取得は `XCUIScreen.main.screenshot()` を `XCTAttachment` (`lifetime = .keepAlways`) で添付し `xcrun xcresulttool export attachments` で xcresult から抽出 (Xcode 16+)。`scripts/capture-asc-screenshots.sh` で全自動化済み (下記「ASC スクショ撮影」セクション参照)。
- **`.safeAreaInset(edge: .bottom)` の TabView + List/Form での no-op 罠** (PR #94 で踏んで revert → Issue #95): TabView 内 NavigationStack + List/Form に `.safeAreaInset(edge: .bottom) { Color.clear.frame(height: N) }` を追加しても、(a) tab bar の safe area は TabView 側で既に管理、(b) ASC スクショは initial scroll position (top) で撮影されるため content 末尾までの効果は visible にならない → **initial view では padding 効果が見えず no-op に見える**。Plan 作成時に visual verification の前提を「ASC スクショ initial view で見える」 / 「scroll 底体験 / 実 app 操作で見える」 のどちらを担保するか **AskUserQuestion で明示確定** する。視覚検証は before (HEAD `git show` で取り出し) / after (working tree) を Read で並べて pixel-diff し、pixel-identical なら advisor 呼ぶ前に **dead code 疑い** として self-detect する (Task ship 前)。

## SwiftUI View テスト戦略
- ViewInspector は NavigationStack + ZStack + UIViewRepresentable (BannerAdView) + Material の組み合わせを深く traverse できない既知制約がある。`find(viewWithAccessibilityIdentifier:)` / `find(text:)` / `find(ViewType.X.self)` いずれも該当 view へ到達不可、`"Search did not find a match. Possible blockers: BannerAdView, Material, AccessibilityImageLabel"` で fail する。
- 上記が予想される View では UI 構造の structural test を強行せず、(a) ViewModel テストでロジック網羅 + (b) View の smoke test (init crash なし) + (c) behavior test (toggle/binding が ViewModel state を動かすこと) で間接担保、UI の最終 visual は simulator 手動 / UI test に委ねる。
- 該当 View の refactor を入れるなら BannerAdView を component 分離 / Material 依存を Color 系に置換 する方向で別 issue 化する (例: #74)。
- **`AccessibilityImageLabel` blocker** (`Image(systemName:)` + `.foregroundColor` の組み合わせ): `find(viewWithAccessibilityIdentifier:)` は AccessibilityImageLabel が 1 つでもあると該当 button へ到達できない。回避策は `find(ViewType.Button.self)` 経由で button 自体を掴み `try button.isDisabled()` などで state を確認する。accessibilityIdentifier 経由の指定を諦めるトレードオフだが、Button が 1 つしか無い component なら structural test として十分機能する。
- **Text 内容の検証は `findAll(ViewType.Text.self)` で blocker を跨ぐ** (#106 PR #109 で確立): 上の `find(ViewType.Button.self)` は button **state** (isDisabled 等) 用。Text の**表示文字列**を読みたい場合、`find(viewWithAccessibilityIdentifier:)` / `find(ViewType.Text.self)` は AccessibilityImageLabel blocker で到達不可だが、**`findAll(ViewType.Text.self)` は blocker を跨いで到達可能な Text を全列挙できる** (ローカル実行で確認済み)。判定時の罠: 数字の有無を `contains("1")` だけで見ると、ローカライズされない兄弟 Text (例 `coinInfo` の `"10コイン"`) が "1" を含み、対象 row が不在でも通る false positive になる → 衝突する兄弟を `!hasSuffix("コイン")` 等で除外してから数字一致を見る。`String(localized:)` を test 側で再計算して exact match する案は test-bundle/locale 解決に過結合する (app-host & 同 locale でしか一致しない) ので、**数字一致 + 兄弟除外**の方が頑健。
- **Component 分離による blocker 回避** (#74 で確立した path): `RecordView` の `recordButtonView` を `RecordButtonBar` (`Presentation/Components/`) に切り出し、component 単独で View test を書く形を取った。親 View 側に NavigationStack + ScrollView + UIViewRepresentable の組み合わせが残っていても、component test はそれらの影響を受けない。BannerAdView の位置を維持しつつ structural test を確保したいケースで有効。

## i18n: xcstrings plural variations の呼び出し
- xcstrings の `variations.plural` (one / other) を Swift 側から有効化するには **string interpolation** が必須。`String(localized: "%lld 件...") + String(format: format, count)` の組み合わせは plural 解釈を bypass して常に `other` を返す。
- 正しい書き方: `String(localized: "\(count) 件...")` (`String.LocalizationValue` の placeholder に値を渡すと plural branch が選ばれる)。catalog のキーは `%lld` 形式のまま (`"%lld 件..."`) で、value 側も `%lld` を保つ。
- 詳細は [[xcstrings-plural-variations]] skill にまとめている。複数キー追加時は [[xcstrings-bulk-update]] と併用。
- count=1 のときに `one` バリアントが効くことを unit test (`XCTAssertTrue(message.contains("1"))` 程度でよい) で 1 件担保しておくと runtime bypass の regression を catch できる。

## データ層 i18n の落とし穴 (Core Data 保存値)
- `HelpTask.defaultTasks()` のように **Core Data に save される文字列** は、xcstrings に翻訳を追加するだけでは英訳されない (save 時の locale で確定し DB に persist される)。
- 発見ケース: en ロケで起動しても DB 保存済みの ja 名「下の子の面倒を見る」がそのまま表示 (PR #88 の `docs/screenshots/asc/v1.1.x/en/02-record.png`、Issue #89 #1)。
- 対応案: (a) name を xcstrings key 化して UI 表示時に `String(localized:)` 経由で読み替え、(b) 既存 ja DB 値の migration (起動時 1 回 only)。
- 関連: UI 層 i18n の [[xcstrings-bulk-update]] と区別。サンプル生成 / Seeder / user-generated 等の data layer は別観点で扱う。

## ASC 提出時の落とし穴 (リリースで踏んだ learning)
- **Age Rating の「広告」=「はい」設定が必須** (Issue #86, v1.1.2 提出時 2026-05-23): AdMob (Google Mobile Ads) を統合した v1.1.0 以降は、ASC → App 情報 → 年齢制限指定で「広告」を必ず「はい」に設定する。No のままだと automated review が SDK 統合を検知して reject する。metadata-only fix なので build 再アップロードは不要、ASC UI で切替えるのみ。リリース手順書 (`RELEASE_vX.Y.Z.md`) の提出前チェックリストに項目化済み。
- **英語ロケーションの Description / What's New には絵文字を入れない** (Issue #85, 2026-05-23): ASC は en locale の text フィールドの絵文字を弾く (公式ドキュメント未明記の挙動)。日本語ロケーションでは絵文字 OK (v1.1.1 ja What's New で ✨🐛🌍 を公開実績あり)。en draft は plain text 見出し + `- ` ハイフン箇条書きで統一する。`RELEASE_vX.Y.Z.md` § What's New (en) / `RELEASE_vX.Y.Z_ASC_EN.md` 系の draft section に "plain text only, no emojis" 注意書きを残す運用とする。
- **approved された train の次に build を upload するなら必ず version bump** (PR #98, v1.1.2 → v1.1.3 で踏んだ 2026-05-28 ITMS-90186 / 90062): ASC で一度 `previously approved version` になった train (例: 1.1.2) は **closed 扱い** になり、同じ `MARKETING_VERSION` で別 build を upload すると ITMS-90186 (train closed) / ITMS-90062 (version not higher) で reject される。reject email の文言「`previously approved version [1.1.2]`」が決定打 (v1.1.2 build 53 が ASC 側で approved 済みだった証拠)。release PR 経由ではなく **Xcode → Archive → Distribute** で直接 upload する場面で最も踏みやすい (CI gate は PR でしか動かないので bypass される)。upload 前に必ず `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` を bump して新 train を作る。同じ罠を **v1.1.0 → v1.1.1 と v1.1.2 → v1.1.3 で 2 回踏んでいる** ので最重要 learning。
- **`release-version-bump-check` CI gate の射程外**: `scripts/version-bump-check.sh` + `version-bump-check.yml` は **PR 経由で pbxproj が変更される release flow** のみを gating する。**Xcode から直接 Archive → Distribute する経路には介在できない**。よってリリース手順書 (`RELEASE_vX.Y.Z.md`) § 1.2 の build 選択前のチェックリストに「**`git tag --list 'v*' --sort=-v:refname | head -1` または ASC の最新 approved version より pbxproj の `MARKETING_VERSION` が高いことを再確認**」を必ず置く。CI に頼り切らず、ローカル archive flow にもガードを残す。
- **ASC で approved になったら速やかに `git tag -a vX.Y.Z` を push**: v1.1.2 リリースで git tag が打たれず、release-version-bump-check.yml の base ref (`git describe --tags --abbrev=0`) が v1.1.1 のままになっていた。tag が無いと CI が「approved 済み版」と pbxproj 差分を比較できなくなる。`RELEASE_vX.Y.Z.md` § 5 完了後タスクに既に項目化済みだが、approved 通知を受けた段階で **即タグ push** する運用を徹底する (リリース時に Internal/External Release Notes を整える前に tag は先打ち)。
- スキル: [[release-version-bump-check]] が version bump + Age Rating + en 絵文字 NG をまとめてカバー。**release PR 作成時 + ASC へ build を upload する直前 (Xcode Archive する前) の 2 タイミング** で必ず invoke する。

## ASC スクショ撮影 (v1.1.x 用 / Issue #50 PR #88 で確立)
- 撮影実行: `./scripts/capture-asc-screenshots.sh` (1 コマンド完結、ja + en × 3 tab = 6 PNG を `docs/screenshots/asc/v1.1.x/{ja,en}/` に配置)。
- 仕組み: `ASCScreenshotUITests` (`app/OtetsudaiCoinUITests/`) が locale launch args (`-AppleLanguages '(en)'` / `'(ja)'`) + tab 切替 (`element(boundBy:)` で locale-agnostic) + `XCUIScreen.main.screenshot()` を `XCTAttachment` (`.keepAlways`) で添付 → `xcrun xcresulttool export attachments` で xcresult から抽出 → `jq` で `manifest.json` parse + リネーム配置。
- ASC 仕様で `XCUIScreen.main.screenshot()` (status bar 含む full screen) を使う。`app.screenshot()` だと status bar 抜けで解像度不足になり ASC reject の可能性。
- Simulator は **iPhone 17 Pro Max** (6.7-inch、ASC 最大サイズ device) を destination 指定。`scripts/capture-asc-screenshots.sh` 内に hardcoded。
- `--uitesting` launch arg で `TutorialService.checkFirstLaunch()` が skip され (TutorialService.swift:25-30)、`ContentView.setupInitialData()` で太郎 / 花子 sample data が seed される。
- 再撮影だけなら repo 内 script を実行する。spec/plan は不要。撮影出力は `docs/screenshots/asc/v1.1.x/{ja,en}/` を上書き。
- `scripts/capture-asc-screenshots.sh` は `-project "app/OtetsudaiCoin.xcodeproj"` を指定している (Xcode project が `app/` 配下にあるため repo root 実行で動作する)。同様の bash CLI script を追加する場合も同じ convention に揃える (`scripts/benchmark-tests.sh` も同パターン)。

## NotificationManager 発火と error message の干渉
- `NotificationManager.shared.notifyHelpRecordUpdated()` (および類似の data-update 通知) を呼ぶと、observer 側で `loadData()` → `setLoading(true)` が走り、その副作用で `errorMessage` がクリアされる (`BaseViewModel.setLoading` の挙動: `if loading { errorMessage = nil }`)。
- このため write 操作が **0 件しか成功しなかった場合に notify を呼ぶと、直前に `setError(...)` でセットした errorMessage が消えてしまう**。write が 1 件以上成功したときだけ notify する設計にする (`if !successIds.isEmpty { notify() }`)。
- `successMessage` は `setLoading(true)` で消えないので、success のみ気にする既存パターン (`recordHelp` 等) では問題化しなかった。一括 / batch 系の新規実装で踏みやすい罠。
- **reload trigger は data-lifecycle の入り口に集約する**: read-only な derived state (counts, summaries 等) を新規追加する場合、reload trigger は `loadData` 末尾 / `selectXxx` 末尾 / 依存値の `onChange` / 既存 `notifyXxxUpdated` observer 経路 にだけ置く。`recordXxx` / `recordBulkXxx` などの write 操作内で直接 reload を呼ばない。reload を 1 経路に統一することで、上記の `setLoading(true)` による errorMessage クリアの罠を踏まず、同一データの重複 fetch も避けられる (#73 で確立)。

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

