# Issue #148: 記録画面タスクカードの個性化(絵文字アイコン)— Design Doc

- 日付: 2026-07-18
- 対象 Issue: #148(優先度: 高)
- 前提: #147(ブランドカラー オレンジ×ティール、PR #174)merge 済み。`AccessibilityColors.brandPrimary` 等が利用可能
- 決定プロセス: superpowers:brainstorming で 4 論点(表現方式 / ピッカー / migration / スコープ)をユーザーが選択

## ゴール

全タスクカードが同一 SF Symbol(hands.sparkles)+ グレー円で区別できない問題を解消し、タスクごとの絵文字アイコンで子どもが視覚的にタスクを識別できるようにする。あわせて「タップして選択」の冗長テキストを削除する。

受け入れ条件(issue より):

- タスクごとに異なるアイコン/絵文字が表示され、ユーザーが変更できる
- 既存ユーザーのタスクにもデフォルト絵文字が付与される(表示時フォールバックで充足)

## 決定事項

| 論点 | 決定 |
| --- | --- |
| 表現方式 | **絵文字のみ**(`icon: String?` 1 プロパティ)。色プロパティは YAGNI で見送り。Text 描画のため ViewInspector の AccessibilityImageLabel blocker を回避できる |
| ピッカー | **プリセットグリッドのみ**(自由入力なし) |
| 既存データ | **表示時フォールバック**(DB 一括書き換えの one-time migration はしない) |
| 追加スコープ | TaskCardView の選択色 `.blue` → `brandPrimary` 化のみ。他画面への絵文字展開は含めない |

## 設計

### 1. Domain: `HelpTask`(`app/OtetsudaiCoin/Domain/Entities/HelpTask.swift`)

- `icon: String?` を追加。initializer はデフォルト引数 `icon: String? = nil` で既存呼び出し互換。`deactivate()/activate()/updateCoinRate()/updatingSortOrder()` 等の copy 系メソッドは icon を引き継ぐ
- `updatingIcon(_ newIcon: String?) -> HelpTask` を追加(ピッカー保存用)
- 表示解決(既存 `displayName` と同型のパターン):

  ```swift
  var displayIcon: String {
      if let icon, !icon.isEmpty { return icon }
      return HelpTask.defaultIconsByName[name] ?? "✨"
  }
  ```

- `defaultIconsByName: [String: String]`(canonical ja 名がキー。`defaultTaskNames` と同期必須 — 同期テストで担保):

  | タスク | 絵文字 |
  | --- | --- |
  | 下の子の面倒を見る | 👶 |
  | お風呂を入れる | 🛁 |
  | 食器を出す | 🍽️ |
  | 食器を片付ける | 🥣 |
  | お片付けする | 🧸 |
  | 玄関の靴を並べる | 👟 |
  | ゴミ出しのお手伝い | 🗑️ |
  | 洗濯物を運ぶ | 🧺 |
  | テーブルを拭く | 🧽 |
  | 自分の部屋の掃除 | 🧹 |

- `defaultTasks()` は icon を明示保存**しない**(nil のまま。表示は辞書フォールバックが解決し、将来のデフォルト絵文字変更にも DB 書き換えなしで追従)

### 2. Core Data(lightweight migration)

- `OtetsudaiCoin 4.xcdatamodel` を新設し `.xccurrentversion` を更新。`CDHelpTask` に **optional String `icon`**(default なし)を追加
- optional 属性の追加は inferred mapping による lightweight migration で自動(v1→v3 の既存実績と同パターン)
- `CoreDataHelpTaskRepository` の save/fetch mapping に icon を追加
- In-memory テスト用 Mock(`MockHelpTaskRepository`)は struct ベースのため変更不要(HelpTask に icon が乗るだけ)

### 3. ピッカー: `TaskIconCatalog` + TaskManagementView

- `TaskIconCatalog`(`app/OtetsudaiCoin/Domain/Entities/` か `Utils/` — 実装時に既存 convention に合わせる):

  ```swift
  enum TaskIconCatalog {
      static let presets: [String] // 28 個前後: デフォルト 10 + 🍳🥗🌱🪴🐶🐱🛒📚🎒🪥🧦🛏️🚪🪟🧻💧🌂✉️ 等
  }
  ```

  重複なし・全て絵文字 1 文字(grapheme cluster 1 個)を unit test で担保
- TaskManagementView のタスク追加/編集フォームに LazyVGrid(6 列)グリッドを追加。選択中の絵文字は brandPrimary リングで表示(ChildFormView の色グリッドと同一 UX パターン)
- `TaskManagementViewModel` の addTask/updateTask 系 API に icon 引数を追加(既存シグネチャはデフォルト引数で互換維持)

### 4. TaskCardView 再設計(`Presentation/Components/TaskCardView.swift`)

- `taskIcon`: `Image(systemName: "hands.sparkles")` → `Text(task.displayIcon)`(`.font(.title2)` 相当)。円の地色: 未選択 = `Color.gray.opacity(0.1)` / 選択 = `brandPrimary.opacity(0.15)`。絵文字 Text は `.accessibilityHidden(true)`(装飾、#84 の VoiceOver パターン)。カード(Button)の accessibilityLabel は従来どおり displayName ベースを維持
- **`unselectedIndicator`(「○ タップして選択」行)を削除**。単独モードの `selectedIndicator`(「✓選択中」行)も削除し、選択状態は **カード枠線(brandPrimary 2pt)+ 右上チェックマーク overlay(checkmark.circle.fill, brandPrimary)** で表現
- 一括モードの `bulkSelectionIndicator`(checkbox 行)は機能として維持。色 `.blue` → `brandPrimary`
- その他の選択色(`coinInfo` の文字色 / `cardBackground` の fill・stroke)も `.blue` → `AccessibilityColors.brandPrimary` 系へ置換
- カード高さ `frame(height: 150)` は行削減に合わせて実装時に調整可(視覚検証で確認)

### 5. i18n

- 絵文字は言語中立のため xcstrings 追加は原則不要。ピッカーのセクション見出し等の新規 UI 文言のみ xcstrings に追加(en 訳含む、[[xcstrings-bulk-update]] 参照)

### 6. テスト戦略

1. `HelpTaskTests`: displayIcon フォールバック 3 段(明示 icon / デフォルト名辞書 / ✨)+ copy 系メソッドの icon 引き継ぎ + `defaultTaskNames` ↔ `defaultIconsByName` 同期テスト(既存 `testEveryDefaultNameHasLocalizationEntry` と同型)
2. `TaskIconCatalog`: 重複なし・非空・全要素が 1 grapheme cluster
3. Repository: icon の save → fetch roundtrip(nil / 値あり両方)
4. `TaskManagementViewModel`: addTask/updateTask で icon が保存されること
5. `TaskCardView`(findAll ベース、iOS 26 identifier 回帰対応): 絵文字 Text の存在 / 「タップして選択」文言の不在 / 選択時 Shape fill = `brandPrimary` 定数比較。未実証 traversal に PASS が依存する場合は assertion message に観測値 dump(#106 ルール)
6. 視覚検証: `scripts/capture-asc-screenshots.sh`(02-record が Record タブを撮影)で before/after 一次目視 → `git checkout -- docs/screenshots/` で discard

### 7. スコープ外

- HelpHistoryView:310 / HelpRecordEditView:160 / TaskManagementView:120 の hands.sparkles アイコンの絵文字展開(follow-up 候補として PR description に記載)
- 絵文字の自由入力(TextField)
- SplashScreenView / RecordTutorialView の hands.sparkles(ブランド演出・チュートリアル素材であり task 個性化と無関係)

## 実装順序(概要)

1. HelpTask に icon + displayIcon + 辞書(TDD)
2. Core Data model v4 + repository mapping(roundtrip テスト)
3. TaskIconCatalog(TDD)
4. TaskCardView 再設計(findAll テスト)
5. TaskManagementView ピッカー + ViewModel(TDD)
6. 全体テスト + 視覚検証

詳細タスク分割は writing-plans で行う。
