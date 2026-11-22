# #308 PR 1 集計カードと未払いバナーの英語表示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 集計カード（ホーム 2 枚・履歴 3 枚）の文言を en で英語にし、未払いバナーの期間の重複を除き、案内文を「月のまとめから」に直す。

**Architecture:** `StatisticsCard` の `title` / `subtitle` を `LocalizedStringKey` にして、呼び出し側のリテラルのまま翻訳を引く。案内文は String Catalog のキーを差し替え、期間の文字列は `HomeViewModel.unpaidPeriodsText` で年月の重複を除く。

**Tech Stack:** Swift / SwiftUI / XCTest / ViewInspector 0.10.2 / String Catalog（`Localizable.xcstrings`）

**Spec:** `docs/superpowers/specs/2026-11-22-issue-308-statistics-card-unpaid-banner-design.md`

## Global Constraints

- en の新しい訳: 「コイン獲得！」→ `coins earned!`、「日連続！」→ `day streak!`、「コイン/回」→ `coins per chore`
- 新しい案内文（ja / en）:
  - `%@の未支払いのお小遣いが%lldコインあります。月のまとめから支払えます。` / `%@ has %lld coins of unpaid allowance. You can pay from the Monthly Summary.`
  - `%lld人の子供に未支払いのお小遣いが合計%lldコインあります。月のまとめから支払えます。` / `%lld children have unpaid allowances totaling %lld coins. You can pay from the Monthly Summary.`
- 古い案内文のキー 2 つ（`…履歴画面から支払いを行ってください。`）は catalog から消す
- ja の表示は、案内文を除いて変えない
- xcstrings は `xcstrings-bulk-update` skill の手順で編集する（`" : "` の書式を保つ・既存の訳を上書きしない）
- xcodebuild は FOREGROUND、合否は `** TEST SUCCEEDED **` の行で判定。simulator は `iPhone 17 Pro Max` を UDID で指定（`/bin/bash -c 'source scripts/lib/common.sh && JQ=$(resolve_jq) && resolve_udid "iPhone 17 Pro Max"'`）

## Review Focus

1. **ja が変わらない**: カードの見出し・単位は ja でも今と同じ文字で出る → Task 1 の `test_statisticsCard_resolvesJapaneseUnchanged`
2. **年をまたぐ未払いの並び**: 2 人が 2025 年 12 月と 2026 年 1 月を未払いのとき、期間は「2026年1月, 2025年12月」の 2 つだけで新しい順 → Task 2 の `testUnpaidPeriodsTextRemovesDuplicateMonthsAcrossChildren`
3. **古いキーの参照が残らない**: 「履歴画面から」がアプリ・テストのどこにも残らない → Task 2 Step 5 の grep
4. **未払いの合計額と人数は重複を除かない**: 月の重複を除くのは表示の文字列だけで、`unpaidPeriods`・`totalUnpaidAmount`・人数は今のまま → Task 2 のテストで `unpaidPeriods.count == 4` を確かめる
5. **キーの訳が catalog にある**: 新しいキー 5 つに en の訳があり、参照中の 7 キーが stale でない → Task 1・2 の catalog テスト

---

### Task 1: `StatisticsCard` を翻訳する

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Components/StatisticsCard.swift`（`title` / `subtitle` の型と `init` の引数）
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`（キー 3 つを追加。`今月のコイン`・`連続記録`・`実績`・`回`・`獲得コイン`・`平均コイン` の `extractionState: stale` を外す。`コイン` は stale でないので触らない）
- Create: `app/OtetsudaiCoinTests/Presentation/Components/StatisticsCardTests.swift`（置き場所は既存の Components テストに合わせてよい）
- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`（#308 のキーのテストを 1 本追加）

**Interfaces:**
- Produces: `StatisticsCard.init(icon: String, title: LocalizedStringKey, value: String, subtitle: LocalizedStringKey, color: Color, style: StatisticsCardStyle = .large)`

- [ ] **Step 1: 失敗するテストを書く**

```swift
// StatisticsCardTests
func test_statisticsCard_resolvesEnglish() throws {
    let card = StatisticsCard(icon: "star.fill", title: "獲得コイン", value: "60", subtitle: "コイン/回", color: .orange)
    let texts = try card.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string(locale: Locale(identifier: "en")) }
    XCTAssertTrue(texts.contains("Earned Coins"), "rendered: \(texts)")
    XCTAssertTrue(texts.contains("coins per chore"), "rendered: \(texts)")
    XCTAssertTrue(texts.contains("60"), "rendered: \(texts)")
}
func test_statisticsCard_resolvesJapaneseUnchanged() throws {
    // title: "連続記録", subtitle: "日連続！" → ja で "連続記録" と "日連続！"
}
// LocalizationStringCatalogTests
func testStatisticsCardKeysHaveEnglishTranslation() {
    // ["今月のコイン","コイン獲得！","連続記録","日連続！","実績","回","獲得コイン","コイン","平均コイン","コイン/回"]
    // それぞれ存在し、stale でなく、en の stringUnit.value が空でない。
    // 新しい 3 つは en が "coins earned!" / "day streak!" / "coins per chore"
}
```

- [ ] **Step 2: テストを流して失敗を確かめる**

Run: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination "id=<udid>" -parallel-testing-enabled NO -only-testing:OtetsudaiCoinTests/StatisticsCardTests -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: `** TEST FAILED **`。`test_statisticsCard_resolvesEnglish` が `rendered: [...獲得コイン...]` で FAIL（今は `String` なので翻訳されない）。catalog のテストはキーが無い・stale で FAIL。`resolvesJapaneseUnchanged` は今も PASS（非退行の確認）

- [ ] **Step 3: 実装する** — `StatisticsCard` の 2 つのプロパティと `init` の型を `LocalizedStringKey` に変える（呼び出し 5 か所と Preview はリテラルなので変更不要）。catalog は上の Files のとおり

- [ ] **Step 4: テストを流して通ることを確かめる**

Run: Step 2 と同じ
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Components/StatisticsCard.swift app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Presentation/Components/StatisticsCardTests.swift app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "fix(#308): 集計カードの見出しと単位を英語表示で翻訳する"
```

### Task 2: 未払いバナーの期間の重複と案内文

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/HomeViewModel.swift:331-335`（`unpaidPeriodsText`）と `:353`・`:356`（案内文）
- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`（古いキー 2 つを消し、新しいキー 2 つを ja / en で足す）
- Modify: `app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift:195`・`:224`（期待値の文言）と、新しいテスト 1 本
- Modify: `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift:222-223`（キー名）

**Interfaces:**
- Consumes: なし（Task 1 と独立）
- Produces: `func unpaidPeriodsText(locale: Locale = .current) -> String`（シグネチャは今のまま。年月の重複を除き、新しい順）

- [ ] **Step 1: 失敗するテストを書く / 直す**

```swift
@MainActor
func testUnpaidPeriodsTextRemovesDuplicateMonthsAcrossChildren() async {
    // child1: 2026-01・2025-12、child2: 2026-01・2025-12（MockUnpaidAllowanceDetectorService に 4 件）
    await viewModel.checkUnpaidAllowances()
    XCTAssertEqual(viewModel.unpaidPeriods.count, 4)            // 元のデータは重複を除かない
    XCTAssertEqual(viewModel.unpaidPeriodsText(locale: Locale(identifier: "ja_JP")), "2026年1月, 2025年12月")
    XCTAssertEqual(viewModel.unpaidPeriodsText(locale: Locale(identifier: "en_US")), "January 2026, December 2025")
}
```

- `:195`・`:224` の期待値を新しい文言（`…月のまとめから支払えます。`）に直す
- catalog テストの `:222-223` を新しいキー名に直す

- [ ] **Step 2: テストを流して失敗を確かめる**

Run: `… -only-testing:OtetsudaiCoinTests/HomeViewModelTests -only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: `** TEST FAILED **`。新しいテストは `"2026年1月, 2025年12月, 2026年1月, 2025年12月"` で FAIL、案内文の 2 本と catalog のテストも FAIL

- [ ] **Step 3: 実装する** — `unpaidPeriodsText` は `(year, month)` で重複を除いてから新しい順（年→月の降順）に並べ、既存の `MonthlySummaryViewModel.monthLabel` で整形する。案内文の 2 か所を新しい文言にする。catalog は古いキーを消し、新しいキーを足す（ja は source 言語のキーそのもの、en は Global Constraints の文）

- [ ] **Step 4: テストを流して通ることを確かめる**

Run: Step 2 と同じ
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 古い文言の参照が残っていないことを確かめる**

Run: `grep -rn '履歴画面から\|History screen' app/OtetsudaiCoin app/OtetsudaiCoinTests app/OtetsudaiCoinUITests`
Expected: 0 件

- [ ] **Step 6: ユニットテスト全体を流す**

Run: `… -only-testing:OtetsudaiCoinTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/HomeViewModel.swift app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "fix(#308): 未払いバナーの期間の重複を除き、案内文を月のまとめに合わせる"
```

### Task 3: 画面で確かめる（コードの変更なし）

- [ ] **Step 1: after を撮る**

Run: `/bin/bash scripts/capture-verification-screenshots.sh --appearance light --locale both --content-size large`
Expected: exit 0。ja 37 枚・en 12 枚

- [ ] **Step 2: before と比べる** — before は `<scratchpad>/before308/{ja-light,en-light}`（main の `faa63b9` で撮影済み）

Run: `/bin/bash scripts/compare-screenshots.sh <scratchpad>/before308/en-light docs/screenshots/verification/en/light` と ja も同様
Expected: 差分が出るのは、en の 06・31・32・33 と ja の 31・32 だけ（ほかは同一か status bar のみ）。06・31〜33 の en を Read で目視し、日本語の文言が名前以外に 0 件、32 の期間が「October 2026, September 2026」の 2 つだけ
