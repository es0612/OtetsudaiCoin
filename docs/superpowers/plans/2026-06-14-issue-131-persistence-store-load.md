# Persistence Store-Load 失敗のユーザー可視化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Core Data ストアの読み込みに失敗したとき、全データが無言で空に見える代わりに、ブロッキングなエラー画面で「データを読み込めなかった」ことと再起動を非破壊的に伝える（Issue #131）。

**Architecture:** `PersistenceController` が `loadPersistentStores` のエラーを同期的に捕捉して `storeLoadError: Error?` に保持する。アプリ root (`OtetsudaiCoinApp.body`) はこの値を見て、失敗時は `ContentView` を構築せず専用の `StoreLoadErrorView` を表示する。**破壊的な自動復旧（ストア削除→再作成）は行わない** — transient / disk full / migration 中断のような回復可能な失敗で実データを永久消去するリスクがあるため（Issue #131 の主目的は「検知 + 可視化」、復旧フローは明示的にスコープ外）。

**Tech Stack:** Swift / SwiftUI / Core Data (NSPersistentContainer) / XCTest / ViewInspector 0.10.2 / String Catalog (`.xcstrings`)

---

## 設計判断（エラー UX の出し方）

`AskUserQuestion` で「plan を書いてから実装」を選択済みのため、ここで採用案を提示する。レビューで異論があれば差し替え可能。

| 案 | 内容 | 採否 |
| --- | --- | --- |
| **(a) ブロッキングなエラー画面 + 再起動誘導** | root で TabView の代わりに専用画面を出す。非破壊。再起動を促す。 | ✅ **採用** |
| (b) 自動復旧（store 削除 → 再作成） | 失敗時にストアを消して作り直す | ❌ 回復可能な失敗で実データを永久消去するため危険。お手伝いコイン（実データ）には不適 |
| (c) telemetry のみ | os.log だけ残す | ❌ 「データが消えた」体験を解消しない（既存 `os.log` は維持しつつ (a) を足す） |

**理由:** ストア未 attach 時は全リポジトリが空返し / write 失敗になるため、アプリへ入れると「追加したのに保存されない」更なる混乱を生む。ブロックして再起動を促すのが正しい。iOS はアプリ自身を再起動できないため、画面はボタンではなく情報提示（アイコン + 見出し + 再起動の案内文）にする。

---

## File Structure

| ファイル | 役割 | 変更 |
| --- | --- | --- |
| `app/OtetsudaiCoin/Persistence.swift` | ストア読み込みエラーの捕捉 + テスト/視覚確認 seam | Modify |
| `app/OtetsudaiCoin/Presentation/Views/StoreLoadErrorView.swift` | 失敗時に出す専用画面 | Create |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 画面文言の en 翻訳追加 | Modify |
| `app/OtetsudaiCoin/OtetsudaiCoinApp.swift` | root で `storeLoadError` を見て分岐 | Modify |
| `app/OtetsudaiCoinTests/Data/PersistenceControllerTests.swift` | `storeLoadError` の成功/失敗経路を検証 | Create |
| `app/OtetsudaiCoinTests/Presentation/Views/StoreLoadErrorViewTests.swift` | 画面の構造 smoke test | Create |

**App の分岐は `RootView` でラップしない:** `OtetsudaiCoinApp.body` で直接分岐すると、`storeLoadError != nil` のとき `StoreLoadErrorView()` だけが構築され `ContentView()` は一切 init されない（壊れたストアへの factory 構築 / `setupInitialData` の seed が走らない）。`RootView(storeLoadError:)` に切り出すと `else { ContentView() }` の View 値が両分岐で構築され、この利点が消える。したがって App レベルで分岐し、画面とコントローラのロジックを個別にテストする。App の wiring 自体は simulator 視覚確認に委ねる（`#115` の Developer 節ゲートと同じトレードオフ）。

---

## Task 1: `PersistenceController` でストア読み込みエラーを捕捉する

**Files:**
- Modify: `app/OtetsudaiCoin/Persistence.swift:59-95`
- Test: `app/OtetsudaiCoinTests/Data/PersistenceControllerTests.swift` (Create)

- [ ] **Step 1: 失敗するテストを書く**

Create `app/OtetsudaiCoinTests/Data/PersistenceControllerTests.swift`:

```swift
import XCTest
import CoreData
@testable import OtetsudaiCoin

@MainActor
final class PersistenceControllerTests: XCTestCase {

    func test_storeLoadError_isNil_onSuccessfulInMemoryLoad() {
        // in-memory (/dev/null) は正常にロードできるので storeLoadError は nil。
        // テスト/プレビューで誤ってエラー UI が出ないことの保証も兼ねる。
        let controller = PersistenceController(inMemory: true)
        XCTAssertNil(
            controller.storeLoadError,
            "in-memory store should load cleanly; got \(String(describing: controller.storeLoadError))"
        )
    }

    func test_storeLoadError_isNonNil_whenStoreURLIsUnopenable() throws {
        // store URL を「既存ディレクトリ」に向けると SQLite open が失敗する。
        // この経路は load 失敗 + 同期 completion での捕捉を同時に実証する
        // (loadPersistentStores が async だった場合この assert が落ちて気づける)。
        // 特定の NSError domain/code には依存せず「non-nil であること」だけを見る。
        let dirURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let controller = PersistenceController(storeURLOverride: dirURL)

        XCTAssertNotNil(
            controller.storeLoadError,
            "expected a load error when store URL is a directory; storeLoadError=\(String(describing: controller.storeLoadError))"
        )
    }
}
```

- [ ] **Step 2: RED 実行は skip（コンパイルエラー確定）**

`storeLoadError` プロパティと `init(storeURLOverride:)` が未定義のため **`BUILD FAILED` が必至**。CLAUDE.md「TDD red verification skip 条件 (a) コンパイルエラー確定」に該当するため RED の `xcodebuild test` は skip する。**ただし Step 4 の GREEN 実行は behavioral（同期捕捉のタイミング依存）なので必ず実行する**（advisor 指摘: この test がこのプロジェクト唯一の同期捕捉検証）。

- [ ] **Step 3: `Persistence.swift` を実装する**

`Persistence.swift` の `let container: NSPersistentContainer` 〜 `init` の末尾（現行 59-95 行）を以下で置き換える:

```swift
    let container: NSPersistentContainer

    /// ストア読み込みに失敗した場合のエラー（成功時は nil）。
    /// 失敗時はストアが attach されず全リポジトリが空返し / write 失敗になるため、
    /// アプリ root でこの値を見てエラー画面へ切り替える（Issue #131）。
    let storeLoadError: Error?

    nonisolated init(inMemory: Bool = false) {
        let storeURLOverride: URL?
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-store-load-failure") {
            // 視覚確認用: store URL を開けない URL に向けて load を故意に失敗させる
            storeURLOverride = Self.unopenableStoreURL()
        } else {
            storeURLOverride = inMemory ? URL(fileURLWithPath: "/dev/null") : nil
        }
        #else
        storeURLOverride = inMemory ? URL(fileURLWithPath: "/dev/null") : nil
        #endif
        self.init(storeURLOverride: storeURLOverride)
    }

    /// 指定イニシャライザ兼テスト seam。`storeURLOverride` に開けない URL（既存ディレクトリ等）を
    /// 渡すと load 失敗経路を決定的に再現できる。`nil` なら既定のストア記述子をそのまま使う。
    nonisolated init(storeURLOverride: URL?) {
        let container = NSPersistentContainer(name: "OtetsudaiCoin")
        if let storeURLOverride, let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.url = storeURLOverride
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                // ストア読み込み失敗。ログを残しつつエラーを捕捉して上位（root view）へ伝える。
                // local SQLite store は同期ロードのため、この closure は
                // loadPersistentStores の return 前に同期実行される（PersistenceControllerTests で実証）。
                Self.logger.error("Core Dataストアの読み込みに失敗しました: \(error.localizedDescription)")
                loadError = error
                #if DEBUG
                let nsError = error as NSError
                print("Core Data エラー詳細: \(nsError), \(nsError.userInfo)")
                #endif
            }
        }

        self.container = container
        self.storeLoadError = loadError
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    #if DEBUG
    /// `--force-store-load-failure` 用: SQLite が開けない URL（既存ディレクトリ）を返す。
    private nonisolated static func unopenableStoreURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("force-store-load-failure", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    #endif
```

実装メモ:
- 旧 init の早期 `return`（記述子が見つからない inMemory ケース）と二重の `automaticallyMergesChangesFromParent` 代入は除去する（`storeLoadError` を全経路で初期化する必要があるため早期 return は不可）。
- 旧 75-81 行のプレースホルダコメント（「本番環境では以下のような対応を検討」）は、実装で具体化されたため削除する。
- `saveContext()` 以降（96 行〜）は変更しない。

- [ ] **Step 4: GREEN 実行（必須・behavioral 検証）**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/PersistenceControllerTests \
  2>&1 | tee /tmp/p131-task1.log | tail -30
grep -E "Test Suite .*(passed|failed)|\*\* TEST" /tmp/p131-task1.log
```
Expected: 両テスト PASS。`test_storeLoadError_isNonNil_...` が PASS することで「ディレクトリ URL が実際に load 失敗を起こす」「同期 completion で `storeLoadError` に入る」の両方が実証される。

> background 実行時は CLAUDE.md「iOS テスト flake 切り分け」に従い、報告 exit を鵜呑みにせず log 末尾の `** TEST` / `Test Suite` 行で判定する。

- [ ] **Step 5: コミット**

```bash
git add app/OtetsudaiCoin/Persistence.swift app/OtetsudaiCoinTests/Data/PersistenceControllerTests.swift
git commit -m "feat(#131): PersistenceController がストア読み込みエラーを storeLoadError に捕捉"
```

---

## Task 2: `StoreLoadErrorView` と文言（en 翻訳）を追加する

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/Views/StoreLoadErrorView.swift`
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`
- Test: `app/OtetsudaiCoinTests/Presentation/Views/StoreLoadErrorViewTests.swift` (Create)

- [ ] **Step 1: 失敗するテストを書く**

Create `app/OtetsudaiCoinTests/Presentation/Views/StoreLoadErrorViewTests.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class StoreLoadErrorViewTests: XCTestCase {

    func test_canBeInstantiated() {
        // 生成して crash しない smoke test
        let view = StoreLoadErrorView()
        XCTAssertNotNil(view)
    }

    func test_rendersTitleAndGuidanceText() throws {
        // iOS 26 + ViewInspector 0.10.2 では accessibilityIdentifier 解決が不安定なため
        // findAll(ViewType.Text.self) で blocker (Image の AccessibilityImageLabel) を跨いで
        // Text を全列挙する（CLAUDE.md「SwiftUI View テスト戦略」）。
        // 文言の exact match は locale 依存になるため、見出し + 案内文の 2 つの Text が
        // 描画されること（locale 非依存の構造）を確認する。実文言は simulator 視覚確認で担保。
        let view = StoreLoadErrorView()
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertGreaterThanOrEqual(
            texts.count, 2,
            "expected title + guidance Text (>=2); rendered: \(texts)"
        )
        XCTAssertTrue(
            texts.allSatisfy { !$0.isEmpty },
            "rendered Texts should be non-empty; rendered: \(texts)"
        )
    }
}
```

- [ ] **Step 2: RED 実行は skip（コンパイルエラー確定）**

`StoreLoadErrorView` が未定義のため `BUILD FAILED` 必至。CLAUDE.md skip 条件 (a) に該当。

- [ ] **Step 3: `StoreLoadErrorView` を実装する**

Create `app/OtetsudaiCoin/Presentation/Views/StoreLoadErrorView.swift`:

```swift
import SwiftUI

/// Core Data ストアの読み込みに失敗したときに、アプリ全体（TabView）の代わりに表示する画面（Issue #131）。
///
/// ストアが attach されず全データが空に見える状態を正しくユーザーへ伝える。
/// 破壊的な自動復旧は行わず、アプリの再起動を促す（iOS はアプリ自身を再起動できないため
/// ボタンではなく案内文のみ）。既存の `ErrorView`（再試行ボタン前提の汎用エラー）とは
/// 用途が異なる（ストアは再試行で開き直せない）ため専用 View にしている。
struct StoreLoadErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AccessibilityColors.errorRed)

            Text("データを読み込めませんでした")
                .font(.headline)
                .foregroundColor(AccessibilityColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("アプリをいったん完全に終了してから、もう一度開いてください。問題が解決しない場合は、お手数ですがサポートまでご連絡ください。")
                .font(.subheadline)
                .foregroundColor(AccessibilityColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#if DEBUG
#Preview {
    StoreLoadErrorView()
}
#endif
```

> `Text("リテラル")` は SwiftUI が String Catalog から自動ローカライズする（ContentView の `Text("ホーム")` と同じ慣習）。ビルド時にこの 2 キーが `Localizable.xcstrings` へ自動抽出される。

- [ ] **Step 4: en 翻訳を `Localizable.xcstrings` に追加する**

CLAUDE.md「xcstrings-bulk-update」: Python `json.dump` は `" : "` 整形を壊すため **Edit ツールで手動挿入**する。`"strings" : {` 直後（先頭エントリの前）に 2 件を挿入する。

Edit の `old_string`:
```
  "strings" : {
    "「%@」の記録を削除しますか？この操作は取り消せません。" : {
```

Edit の `new_string`:
```
  "strings" : {
    "アプリをいったん完全に終了してから、もう一度開いてください。問題が解決しない場合は、お手数ですがサポートまでご連絡ください。" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Please quit the app completely and reopen it. If the problem persists, please contact support."
          }
        }
      }
    },
    "データを読み込めませんでした" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Couldn't load your data"
          }
        }
      }
    },
    "「%@」の記録を削除しますか？この操作は取り消せません。" : {
```

> en 文言は in-app（ASC ではない）なので絵文字制約は無関係。plain text で問題なし。

- [ ] **Step 5: GREEN 実行（View test + ローカライズ gate）**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OtetsudaiCoinTests/StoreLoadErrorViewTests \
  -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests \
  2>&1 | tee /tmp/p131-task2.log | tail -30
grep -E "Test Suite .*(passed|failed)|\*\* TEST" /tmp/p131-task2.log
```
Expected: 全 PASS。`LocalizationStringCatalogTests` が PASS することで新キー 2 件に en 翻訳が揃っていることを確認（「missing English translation」regression を防ぐ）。`test_rendersTitleAndGuidanceText` の `rendered:` dump で findAll が Text を取得できているか確認できる。

- [ ] **Step 6: コミット**

```bash
git add app/OtetsudaiCoin/Presentation/Views/StoreLoadErrorView.swift \
        app/OtetsudaiCoin/Resources/Localizable.xcstrings \
        app/OtetsudaiCoinTests/Presentation/Views/StoreLoadErrorViewTests.swift
git commit -m "feat(#131): ストア読み込み失敗時の StoreLoadErrorView と en 翻訳を追加"
```

---

## Task 3: アプリ root で `storeLoadError` を見て分岐する

**Files:**
- Modify: `app/OtetsudaiCoin/OtetsudaiCoinApp.swift:16-21`

> このタスクは App（`@main`）の wiring で ViewInspector で traverse 不可のため unit test を書かず、Task 4 の simulator 視覚確認で担保する（CLAUDE.md `#115` と同じトレードオフ）。

- [ ] **Step 1: `OtetsudaiCoinApp.body` を分岐させる**

`OtetsudaiCoinApp.swift` の `var body: some Scene { ... }` を以下で置き換える:

```swift
    var body: some Scene {
        WindowGroup {
            if persistenceController.storeLoadError != nil {
                // ストア未 attach で全データが空に見える状態。アプリへ入れず、
                // 再起動を促すブロッキング画面を出す（Issue #131）。
                StoreLoadErrorView()
            } else {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
```

- [ ] **Step 2: ビルドが通ることを確認**

Run:
```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  2>&1 | tee /tmp/p131-task3-build.log | tail -5
grep -E "BUILD (SUCCEEDED|FAILED)" /tmp/p131-task3-build.log
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoin/OtetsudaiCoinApp.swift
git commit -m "feat(#131): root でストア読み込み失敗時にエラー画面へ分岐"
```

---

## Task 4: 検証（フルテスト + simulator 視覚確認）

**Files:** なし（検証のみ）

- [ ] **Step 1: フル unit テストスイートを実行**

Run:
```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  2>&1 | tee /tmp/p131-full.log | tail -40
grep -E "\*\* TEST (SUCCEEDED|FAILED)|Failing tests:" /tmp/p131-full.log
```
Expected: `** TEST SUCCEEDED **`。既存テストへの regression が無いことを確認。

> 失敗時は CLAUDE.md「iOS テスト flake 切り分け」に従い、UI/load 系の flake は `-only-testing:` で isolated 再実行して切り分ける。

- [ ] **Step 2: 失敗画面を simulator で視覚確認（ja）**

`--force-store-load-failure` で起動してエラー画面を撮影する:

```bash
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath /tmp/p131-dd 2>&1 | tail -3
APP=$(find /tmp/p131-dd -name "OtetsudaiCoin.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install "iPhone 17 Pro Max" "$APP"
xcrun simctl launch "iPhone 17 Pro Max" com.asapapalab.OtetsudaiCoin --force-store-load-failure
sleep 3
xcrun simctl io "iPhone 17 Pro Max" screenshot /tmp/p131-error-ja.png
```
Then Read `/tmp/p131-error-ja.png` で確認:
- 見出し「データを読み込めませんでした」+ 案内文が表示される
- TabView（ホーム/記録/設定）が **出ていない**（ブロックされている）
- クラッシュしていない（非破壊）

- [ ] **Step 3: 失敗画面を simulator で視覚確認（en）**

```bash
xcrun simctl launch "iPhone 17 Pro Max" com.asapapalab.OtetsudaiCoin \
  --force-store-load-failure -AppleLanguages '(en)' -AppleLocale en_US
sleep 3
xcrun simctl io "iPhone 17 Pro Max" screenshot /tmp/p131-error-en.png
```
Then Read `/tmp/p131-error-en.png` で確認: en 文言「Couldn't load your data」+ 案内文が表示される（[[ios-simulator-locale-testing]]）。

- [ ] **Step 4: 正常起動の回帰確認（フラグ無し）**

```bash
xcrun simctl launch "iPhone 17 Pro Max" com.asapapalab.OtetsudaiCoin
sleep 3
xcrun simctl io "iPhone 17 Pro Max" screenshot /tmp/p131-normal.png
```
Then Read `/tmp/p131-normal.png` で確認: フラグ無しでは通常どおり TabView が出る（エラー画面が誤って出ない）。

- [ ] **Step 5: スクショは破棄（feature PR に含めない）**

`/tmp/` に出力しているので commit 対象外。視覚確認の所見は PR description に記載する（CLAUDE.md「別目的ファイル同梱の禁止」）。

---

## レビュー観点 / PR description に書くこと

- **設計判断**: ブロッキング画面 + 再起動誘導を採用、自動復旧（store 削除）は実データ消去リスクのため明示的に不採用。
- **テスト**: 同期捕捉は behavioral なので RED skip せず GREEN を実行して実証（advisor 指摘）。View test は locale 非依存の構造確認 + simulator 視覚確認の組み合わせ。
- **視覚確認**: ja / en エラー画面 + 正常起動の 3 枚を `/tmp/` で目視（PR には含めない）。
- **Plan からの逸脱**: 実装中に逸脱したら本節に理由を明記する。

## Self-Review チェック

- [x] **Spec coverage**: Issue #131 の対応案 3 点 — (1) ユーザー向けエラー表示 = Task 2/3、(2) telemetry = 既存 `os.log` を維持、(3) プレースホルダコメントの具体化 = Task 1 Step 3 で削除/実装。✅
- [x] **Placeholder scan**: 全 step に実コード / 実コマンド / 期待出力あり。"TODO" 等なし。✅
- [x] **Type consistency**: `storeLoadError`（Task 1 定義 → Task 3 参照）、`StoreLoadErrorView`（Task 2 定義 → Task 3 参照）、`init(storeURLOverride:)`（Task 1 定義 → 同 Task テスト参照）すべて整合。✅
