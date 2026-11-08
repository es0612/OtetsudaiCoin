# #279 おまけ（ご褒美）を支払いと一緒に渡す Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 月のまとめで、お小遣いを支払うときに「おまけ（額 + 褒め言葉スタンプ 1 つ）」を任意で足せるようにし、確定の瞬間の演出と、月のまとめの「もらったおまけ」欄で後から見返せるようにする。

**Architecture:** おまけは支払いと同じ `AllowancePayment` の行に `bonusAmount`（既定 0）と `bonusStampKey`（既定 nil）として持つ。`amount` は今までどおり「稼いだ分の支払い」だけなので、支払い状態・未払い検出・リマインダーは変わらない。Core Data は v5（軽量マイグレーション）。UI は今の CTA を 1 タップのまま残し、その下の副リンクからシートを開く。演出は ViewModel の状態で出す overlay。

**Tech Stack:** Swift / SwiftUI（iOS 26 SDK）、Core Data（`OtetsudaiCoin.xcdatamodeld`）、XCTest、ViewInspector 0.10.2、XCUITest、String Catalog（`Localizable.xcstrings`）

**Spec:** `docs/superpowers/specs/2026-11-08-issue-279-bonus-payment-design.md`（issue #279 のコメントの転記。正本は issue 側）

## Global Constraints

- アンチゴール 1「支払いが面倒になる」: おまけを付けない支払いは今と同じ「CTA を 1 回押すだけ」。確認画面やシートを挟まない
- アンチゴール 2「兄弟で比べて不公平感」: おまけはその子の画面（月のまとめ・支払い時の演出）にだけ出す。ホームの子ども一覧など、複数の子が並ぶ場所には出さない
- **おまけを `amount` に混ぜない**（spec の制約）。`paidAmount` / `paymentStatus` / `UnpaidAllowanceDetectorService` / リマインダーは `amount` だけを読む
- `AllowancePayment.note` にスタンプを入れない（ViewModel が決まった文を書く欄のため）
- おまけを付けられるのは `paymentStatus != .paid` の月だけ（入口は CTA と同じ条件で出す）
- 金額の表記は CTA と同じ「¥」
- スタンプは固定の 4 種。保存するのはキー（`rawValue`）で、表示文言ではない。キーは一度出荷したら変えない
- 「視差効果を減らす」が ON のとき、演出の動きはフェードだけにする（#151 / PR #294 の `MotionPlan` と同じ形）
- 新しい画面の文言は ja / en の両方を xcstrings に入れる
- `HomeViewModel.payMonthlyAllowance()` / `recordAllowancePayment(amount:)` は触らない（View からの呼び出し 0 件。扱いは別 issue）
- PR 本文は `Refs #279`（`Closes` にしない。受け入れにオーナー家庭での 1 か月の確認を含むため）

## Review Focus

1. **おまけ付きで払っても「払った額」と支払い状態が変わらない**: 稼ぎ 200・おまけ 50 で払ったら、`snapshot.paidAmount == 200`（250 ではない）、状態は `.paid`。未払い検出も `amount` だけで判定する → Task 3 の `testPayWithBonusKeepsPaidAmountAsEarnings` と `testDetectUnpaidIgnoresBonusAmount`
2. **古い UserDefaults の JSON（おまけの欄が無い）が decode できる**: できないと、まだ移行していない人の移行が毎回黙って失敗し続ける（`AllowancePaymentMigrationService.swift:43`）→ Task 1 の `testMigrateIfNeeded_legacyJSONWithoutBonusKeys_migratesAsNoBonus`
3. **v4 の SQLite ストアが v5 で開け、既存の行は「おまけなし」として読める** → Task 2 の `testV4StoreOpensUnderCurrentModelWithNoBonus`
4. **保存に失敗したら演出を出さない**（渡していないのに「おめでとう」が出るのは最悪）→ Task 3 の `testPayWithBonusFailureDoesNotCelebrate`
5. **新しい版のアプリが書いた未知のスタンプのキーを、古い版で消さずに出す**（汎用の 🎁「おまけ」で表示）→ Task 3 の `testUnknownStampKeyIsListedWithFallback`

---

## File Structure

| ファイル | 役割 | 作成 / 変更 |
| --- | --- | --- |
| `app/OtetsudaiCoin/Domain/Entities/BonusStamp.swift` | スタンプ 4 種（キー・絵文字・文言）と未知キーの代わりの表示 | 作成 |
| `app/OtetsudaiCoin/Domain/Entities/PaymentBonus.swift` | 「額 + スタンプ」の値。額の範囲チェック | 作成 |
| `app/OtetsudaiCoin/Domain/Entities/AllowancePayment.swift` | `bonusAmount` / `bonusStampKey` と、古い JSON を読める decode | 変更 |
| `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 5.xcdatamodel/contents` | v5 モデル | 作成 |
| `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion` | 現行版を v5 に | 変更 |
| `app/OtetsudaiCoin/Data/Repositories/CoreDataAllowancePaymentRepository.swift` | 2 属性の読み書き | 変更 |
| `app/OtetsudaiCoin/Presentation/ViewModels/MonthlySummaryViewModel.swift` | おまけ付きの支払い・演出の状態・月のおまけ一覧 | 変更 |
| `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusDraft.swift` | シートの入力状態（純粋な値。単体テスト対象） | 作成 |
| `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusPaymentSheet.swift` | おまけのシート | 作成 |
| `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusCelebrationView.swift` | 確定後の演出と `MotionPlan` | 作成 |
| `app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift` | 副リンク・シート・overlay・「もらったおまけ」欄 | 変更 |
| `app/OtetsudaiCoin/Resources/Localizable.xcstrings` | 新しい文言（ja / en） | 変更 |
| `app/OtetsudaiCoinUITests/BonusPaymentUITests.swift` | 1 タップ支払いとおまけの流れの UI テスト | 作成 |
| `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift` | 撮影シーン verify-28〜30 | 変更 |

テストのファイルは各 Task に書く。`project.pbxproj` の編集は不要（`PBXFileSystemSynchronizedRootGroup`）。

## テストの回し方（全 Task 共通）

- project skill `running-xcodebuild-tests-and-date-fixtures` に従う。結果は `** TEST SUCCEEDED **` の文言で判定し、件数は `xcrun xcresulttool get test-results summary` で読む
- Simulator は UDID で指定する: `-destination id=110B1CD3-3A7D-4C40-A615-090A263067A2`（iPhone 17 Pro Max。2026-11-08 に `xcrun simctl list devices available` で確認。無ければ同じコマンドで選び直す）
- 単体テスト: `xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination id=<UDID> -only-testing:OtetsudaiCoinTests/<Class>/<test>`
- UI テスト: 上に `-parallel-testing-enabled NO` を足し、`-only-testing:OtetsudaiCoinUITests/<Class>/<test>`
- xcodebuild は foreground で走らせる（subagent も同じ）
- 日付の fixture は固定日（15 日など）にする。相対日付にしない

---

### Task 1: スタンプ・おまけの値・`AllowancePayment` の拡張

**Files:**

- Create: `app/OtetsudaiCoin/Domain/Entities/BonusStamp.swift`
- Create: `app/OtetsudaiCoin/Domain/Entities/PaymentBonus.swift`
- Modify: `app/OtetsudaiCoin/Domain/Entities/AllowancePayment.swift`
- Test: Create `app/OtetsudaiCoinTests/Domain/BonusStampTests.swift`
- Test: Modify `app/OtetsudaiCoinTests/Domain/Services/AllowancePaymentMigrationServiceTests.swift`

**Interfaces:**

- Produces:
  - `enum BonusStamp: String, CaseIterable, Identifiable { case effort, thanks, steady, challenge }`、`var emoji: String`、`var title: String`（`String(localized:)`）、`static let fallbackEmoji = "🎁"`、`static var fallbackTitle: String`（「おまけ」）
  - `struct PaymentBonus: Equatable { let amount: Int; let stamp: BonusStamp; static let maxAmount = 9_999_999; init?(amount: Int, stamp: BonusStamp) }`。`amount` が 1〜`maxAmount` の外なら nil
  - `AllowancePayment` に `let bonusAmount: Int`、`let bonusStampKey: String?`。init は `init(id:childId:amount:month:year:paidAt:note:bonusAmount: Int = 0, bonusStampKey: String? = nil)`（既存の呼び出しはそのままコンパイルできる）

スタンプの中身（spec の例示から Claude が決めた初期セット）:

| case / キー | emoji | ja | en |
| --- | --- | --- | --- |
| `effort` | 🏅 | がんばったで賞 | Great Effort Award |
| `thanks` | 💐 | ありがとう賞 | Thank You Award |
| `steady` | 🐢 | まいにちコツコツ賞 | Every Day Award |
| `challenge` | 🚀 | チャレンジ賞 | Challenge Award |
| （未知のキー） | 🎁 | おまけ | Bonus |

- [ ] **Step 1: 失敗するテストを書く**

`BonusStampTests`:

```swift
func testStampKeysAreStable() {
    // 保存されるキー。出荷後に変えると過去のおまけが「未知のスタンプ」になる
    XCTAssertEqual(BonusStamp.allCases.map(\.rawValue), ["effort", "thanks", "steady", "challenge"])
}
func testUnknownKeyIsNotAStamp() { XCTAssertNil(BonusStamp(rawValue: "gold")) }
func testPaymentBonusRejectsOutOfRangeAmount() {
    XCTAssertNil(PaymentBonus(amount: 0, stamp: .effort))
    XCTAssertNil(PaymentBonus(amount: -1, stamp: .effort))
    XCTAssertNil(PaymentBonus(amount: PaymentBonus.maxAmount + 1, stamp: .effort))
    XCTAssertEqual(PaymentBonus(amount: 1, stamp: .thanks)?.amount, 1)
    XCTAssertEqual(PaymentBonus(amount: PaymentBonus.maxAmount, stamp: .thanks)?.amount, 9_999_999)
}
func testBonusFieldsRoundTripThroughJSON() throws {
    let p = AllowancePayment(id: UUID(), childId: UUID(), amount: 200, month: 11, year: 2026,
                             paidAt: Date(timeIntervalSinceReferenceDate: 0), bonusAmount: 50, bonusStampKey: "effort")
    let decoded = try JSONDecoder().decode(AllowancePayment.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(decoded.bonusAmount, 50)
    XCTAssertEqual(decoded.bonusStampKey, "effort")
}
```

`AllowancePaymentMigrationServiceTests` に追加（JSON は文字列で書く。`JSONEncoder` で作ると新しい欄が入ってしまい、古いデータを再現できない。`paidAt` は既定の Date 戦略 = 2001-01-01 からの秒数）:

```swift
func testMigrateIfNeeded_legacyJSONWithoutBonusKeys_migratesAsNoBonus() async throws {
    let id = UUID(), childId = UUID()
    let legacy = """
    [{"id":"\(id.uuidString)","childId":"\(childId.uuidString)","amount":300,"month":5,"year":2026,"paidAt":800000000,"note":"2026年5月のお小遣い支払い"}]
    """
    // 既存テストと同じ userDefaults / repository の準備で legacy を legacyStorageKey に入れて migrateIfNeeded()
    // 期待: フラグが立つ / 1 件移行 / amount == 300 / bonusAmount == 0 / bonusStampKey == nil
}
```

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/BonusStampTests -only-testing:OtetsudaiCoinTests/AllowancePaymentMigrationServiceTests`
Expected: コンパイルエラー（`BonusStamp` / `PaymentBonus` / `bonusAmount` が未定義）

- [ ] **Step 3: 実装する**

`AllowancePayment` に自前の `init(from decoder:)` を struct の本体に書き、`bonusAmount` は `decodeIfPresent ?? 0`、`bonusStampKey` は `decodeIfPresent` で読む（他の欄は今と同じく必須）。`encode(to:)` と `CodingKeys` は合成のまま。`==` は id 比較のまま変えない。

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`（`AllowancePaymentMigrationServiceTests` の既存 7 件も通る）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Domain/Entities/BonusStamp.swift app/OtetsudaiCoin/Domain/Entities/PaymentBonus.swift \
  app/OtetsudaiCoin/Domain/Entities/AllowancePayment.swift app/OtetsudaiCoinTests/Domain/BonusStampTests.swift \
  app/OtetsudaiCoinTests/Domain/Services/AllowancePaymentMigrationServiceTests.swift
git commit -m "feat(#279): おまけのスタンプと額を AllowancePayment に足す（古い JSON も読める）"
```

---

### Task 2: Core Data v5 とリポジトリ

**Files:**

- Create: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 5.xcdatamodel/contents`
- Modify: `app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion`
- Modify: `app/OtetsudaiCoin/Data/Repositories/CoreDataAllowancePaymentRepository.swift`（`apply(_:to:)` と `toDomain()`）
- Test: Modify `app/OtetsudaiCoinTests/Data/CoreDataAllowancePaymentRepositoryTests.swift`
- Test: Create `app/OtetsudaiCoinTests/Data/CoreDataModelMigrationTests.swift`

**Interfaces:**

- Consumes: Task 1 の `AllowancePayment.bonusAmount` / `bonusStampKey`
- Produces: `CDAllowancePayment.bonusAmount: Int32`（非 optional・既定 0・scalar）、`CDAllowancePayment.bonusStampKey: String?`

v5 の `contents` は v4 の複製に、`CDAllowancePayment` の 2 行を足すだけ（前例: 7e93b6e #148 の v4）:

```xml
<attribute name="bonusAmount" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="bonusStampKey" optional="YES" attributeType="String"/>
```

- [ ] **Step 1: 失敗するテストを書く**

`CoreDataAllowancePaymentRepositoryTests` に 2 件（既存の固定日 fixture を使う）:

- `testSaveAndFetchPersistsBonus`: `bonusAmount: 50, bonusStampKey: "thanks"` で save → `findById` で 50 / "thanks"
- `testSaveAndFetchWithoutBonusReadsZeroAndNil`: 既定のまま save → 0 / nil

`CoreDataModelMigrationTests.testV4StoreOpensUnderCurrentModelWithNoBonus`:

1. 一時ディレクトリに `v4.sqlite` を作る（in-memory ストアはマイグレーションしないので SQLite にする）。`tearDown` で消す
2. v4 のモデルを読む: `Bundle(for: CDAllowancePayment.self).url(forResource: "OtetsudaiCoin", withExtension: "momd")!.appendingPathComponent("OtetsudaiCoin 4.mom")`（コンパイル後の名前は 2026-11-08 に DerivedData の `OtetsudaiCoin.momd/` で確認）
3. その model の `NSPersistentStoreCoordinator` に SQLite ストアを足し、`NSManagedObject(entity: model.entitiesByName["CDAllowancePayment"]!, insertInto:)` に `setValue(_:forKey:)` で 7 属性（amount 300 など）を入れて save。生成クラス `CDAllowancePayment` は v5 でコンパイルされているので、v4 の挿入には使わない
4. `NSPersistentContainer(name: "OtetsudaiCoin")` の description の `url` をその SQLite に向けて load（自動マイグレーション・推論は既定で ON）
5. 期待: load の error が nil / fetch 1 件 / `toDomain()` の `amount == 300`、`bonusAmount == 0`、`bonusStampKey == nil`

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/CoreDataAllowancePaymentRepositoryTests -only-testing:OtetsudaiCoinTests/CoreDataModelMigrationTests`
Expected: コンパイルエラー（`CDAllowancePayment` に `bonusAmount` が無い）

- [ ] **Step 3: v5 モデル・`.xccurrentversion`（`OtetsudaiCoin 5.xcdatamodel`）・リポジトリの対応付けを足す**

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`
加えて `-only-testing:OtetsudaiCoinTests` 全体を 1 回流す（モデル変更は全リポジトリのテストに効くため）。

- [ ] **Step 5: Commit**

```bash
git add "app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/OtetsudaiCoin 5.xcdatamodel/contents" \
  app/OtetsudaiCoin/OtetsudaiCoin.xcdatamodeld/.xccurrentversion \
  app/OtetsudaiCoin/Data/Repositories/CoreDataAllowancePaymentRepository.swift \
  app/OtetsudaiCoinTests/Data/CoreDataAllowancePaymentRepositoryTests.swift \
  app/OtetsudaiCoinTests/Data/CoreDataModelMigrationTests.swift
git commit -m "feat(#279): Core Data model v5 で支払いにおまけの 2 属性を足す（軽量マイグレーション）"
```

---

### Task 3: 月のまとめの ViewModel（おまけ付きの支払い・演出の状態・月のおまけ一覧）

**Files:**

- Modify: `app/OtetsudaiCoin/Presentation/ViewModels/MonthlySummaryViewModel.swift`（`payCurrentMonth` `:95`、`loadMonth` `:125`、`MonthSnapshot` `:270`）
- Test: Modify `app/OtetsudaiCoinTests/Presentation/MonthlySummaryViewModelTests.swift`
- Test: Modify `app/OtetsudaiCoinTests/Domain/Services/UnpaidAllowanceDetectorServiceTests.swift`

**Interfaces:**

- Consumes: Task 1 の `PaymentBonus`、`BonusStamp`、`AllowancePayment(…bonusAmount:bonusStampKey:)`
- Produces:
  - `func payCurrentMonth(bonus: PaymentBonus? = nil) async`（引数なしの呼び出しは今と同じ動き）
  - `private(set) var celebratingBonus: PaymentBonus?`、`func dismissCelebration()`
  - `MonthSnapshot.bonuses: [MonthSnapshot.BonusEntry]`（`MonthSnapshot(` の呼び出しは `MonthlySummaryViewModel.swift:169` の 1 か所だけ。2026-11-08 に grep で確認）
  - `struct BonusEntry: Equatable { let stampKey: String?; let amount: Int; let paidAt: Date; var stamp: BonusStamp? { stampKey.flatMap(BonusStamp.init(rawValue:)) }; var emoji: String; var title: String }`。`emoji` / `title` は stamp が nil なら `BonusStamp.fallbackEmoji` / `fallbackTitle`

- [ ] **Step 1: 失敗するテストを書く**

既存の `testPayCurrentMonthSavesPaymentAndMarksPaid`（`:186`）と同じ準備（皿洗い 100 × 2 回 = 200、今月の固定日）を共通 helper にして使う:

```swift
func testPayWithBonusSavesBonusOnSameRow() async {
    // 準備 → loadMonth → payCurrentMonth(bonus: PaymentBonus(amount: 50, stamp: .effort)!)
    XCTAssertEqual(mockAllowancePaymentRepository.payments.count, 1)
    XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.amount, 200)
    XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.bonusAmount, 50)
    XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.bonusStampKey, "effort")
}
func testPayWithBonusKeepsPaidAmountAsEarnings() async {
    // 同上の後
    XCTAssertEqual(viewModel.snapshot?.paidAmount, 200, "おまけを払った額に混ぜない")
    XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid)
}
func testPayWithBonusSetsCelebration() async     // celebratingBonus == 渡した bonus
func testPlainPayDoesNotSetCelebration() async   // payCurrentMonth() の後 celebratingBonus == nil
func testDismissCelebrationClears() async        // dismissCelebration() で nil
func testPayWithBonusFailureDoesNotCelebrate() async {
    // mockAllowancePaymentRepository.shouldThrowError = true → celebratingBonus == nil、payments は空
}
func testPayWithBonusOnPaidMonthIsNoOp() async  // 既に 200 払い済み → 保存 0 件・celebratingBonus == nil
func testLoadMonthListsBonusesOfSelectedMonthOnly() async {
    // 今月: おまけ 50(effort, 15 日) と おまけなし 1 件、先月（cal.date(byAdding: .month, value: -1) の 15 日）: おまけ 30
    // 期待: bonuses.map(\.amount) == [50]、bonuses.first?.stamp == .effort
}
func testBonusesAreSortedByPaidAtAscending() async  // 今月 2 件（20 日に 30、10 日に 10）→ [10, 30]
func testUnknownStampKeyIsListedWithFallback() async {
    // 今月 bonusAmount 40, bonusStampKey "gold"
    // 期待: bonuses.count == 1、stamp == nil、emoji == "🎁"、title == BonusStamp.fallbackTitle
}
```

`UnpaidAllowanceDetectorServiceTests` に 1 件:

```swift
func testDetectUnpaidIgnoresBonusAmount() {
    // 既存の testDetectUnpaidPeriodsWithLastMonth と同じ準備（先月・固定日 15 日）で、稼ぎ 200、支払い amount 100 + bonusAmount 500
    // 期待: 未払い 1 件、expectedAmount == 100（おまけは未払いを埋めない）
}
```

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/MonthlySummaryViewModelTests -only-testing:OtetsudaiCoinTests/UnpaidAllowanceDetectorServiceTests`
Expected: コンパイルエラー（`payCurrentMonth(bonus:)` / `celebratingBonus` / `bonuses` が未定義）。`testDetectUnpaidIgnoresBonusAmount` はコンパイルが通れば今の実装で GREEN になる見込み（検出は `amount` だけを読むため）。これは「今の実装が制約を満たしている」ことの回帰の囲いなので、RED が出なくてよい。commit メッセージにその旨を書く

- [ ] **Step 3: 実装する**

- `payCurrentMonth(bonus:)`: 今のガード（`isLoading`、`.paid`、`remainder > 0`）はそのまま。保存する行に `bonusAmount: bonus?.amount ?? 0`、`bonusStampKey: bonus?.stamp.rawValue` を足す。保存に成功し `loadMonth()` を呼んだ後に、bonus があれば `celebratingBonus = bonus`。catch では触らない
- `loadMonth()`: `monthPayments`（`:157`）から `bonusAmount > 0` の行を `paidAt` の昇順で `BonusEntry` にする。`paidAmount` の計算（`:158`）と `computePaymentStatus` は変えない

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`（既存の `MonthlySummaryViewModelTests` も全件通る）
加えて `grep -rn "bonusAmount" app/OtetsudaiCoin --include='*.swift'` を流し、`UnpaidAllowanceDetectorService.swift` / `PaymentReminderNotificationService.swift` / `HomeViewModel.swift` に 0 件であることを確かめる（「おまけを `amount` の判定に混ぜない」の確認）

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Presentation/ViewModels/MonthlySummaryViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/MonthlySummaryViewModelTests.swift \
  app/OtetsudaiCoinTests/Domain/Services/UnpaidAllowanceDetectorServiceTests.swift
git commit -m "feat(#279): 月のまとめでおまけ付きの支払いと、その月のおまけ一覧を扱う"
```

---

### Task 4: おまけのシートと、月のまとめの副リンク

**Files:**

- Create: `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusDraft.swift`
- Create: `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusPaymentSheet.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift`（`paymentCTA` `:205` の下に副リンク、`body` にシート）
- Test: Create `app/OtetsudaiCoinTests/Presentation/Components/BonusDraftTests.swift`

**Interfaces:**

- Consumes: Task 1 の `BonusStamp`、`PaymentBonus`（`maxAmount`）、Task 3 の `payCurrentMonth(bonus:)`
- Produces:
  - `struct BonusDraft: Equatable`: `static let chipAmounts = [10, 50, 100]`、`static let maxDigits = 7`、`var stamp: BonusStamp?`、`private(set) var amountText: String`、`var amount: Int`（空なら 0）、`mutating func setAmountText(_ raw: String)`、`mutating func addChip(_ value: Int)`、`func total(remainder: Int) -> Int`、`var bonus: PaymentBonus?`（stamp が nil か額が範囲外なら nil）、`static func stampColumnCount(isAccessibilitySize: Bool) -> Int`（2 / 1）
  - `BonusPaymentSheet(remainder: Int, onConfirm: (PaymentBonus) -> Void, onCancel: () -> Void)`
  - accessibilityIdentifier: 副リンク `summary_bonus_payment_entry`、スタンプ `bonus_stamp_<rawValue>`、チップ `bonus_chip_<10|50|100>`、額の入力 `bonus_amount_field`、確定 `bonus_confirm_button`、キャンセル `bonus_cancel_button`

シートの並び（spec「1 画面で全部」）: ナビゲーションタイトル「おまけを付ける」・左上に「キャンセル」→ 見出し「スタンプを選ぶ」と 4 つのスタンプ（`LazyVGrid`、列数は `stampColumnCount`。AX サイズでは 1 列）→ 見出し「おまけの額」とチップ「+¥10 / +¥50 / +¥100」と数字の入力（`.keyboardType(.numberPad)`）→ 内訳 3 行「お小遣い ¥{remainder} / おまけ ¥{amount} / 渡す額 ¥{total}」→ 確定ボタン「おまけを付けて支払う ¥{total}」（`.primaryButton()`、`draft.bonus == nil` の間は `.disabled`）。選ばれたスタンプは枠とチェックで示し、`.accessibilityAddTraits(.isSelected)` を付ける。

副リンク: CTA の真下に「おまけを付けて支払う」。`paymentStatus != .paid` のときだけ出す（CTA と同じ `if` の中）。見た目は CTA より目立たないテキストリンク（`.buttonStyle(.borderless)` + `AccessibilityColors.brandPrimary` の文字。このプロジェクトに副ボタンの共通 style は無い。2026-11-08 に `AppButtonStyle.swift` で確認）。押すとシートを出す。確定したらシートを閉じてから `Task { await viewModel.payCurrentMonth(bonus:) }` を呼ぶ。CTA の動き（1 タップで即支払い）は変えない。

- [ ] **Step 1: 失敗するテストを書く**

```swift
func testSetAmountTextKeepsAsciiDigitsOnly() {
    var d = BonusDraft()
    d.setAmountText("5a0"); XCTAssertEqual(d.amountText, "50")
    d.setAmountText("５０"); XCTAssertEqual(d.amountText, "", "全角数字は落とす（numberPad は半角を出す。貼り付けだけの経路）")
    d.setAmountText("007"); XCTAssertEqual(d.amountText, "7")
}
func testSetAmountTextCapsAtSevenDigits() {
    var d = BonusDraft(); d.setAmountText("123456789"); XCTAssertEqual(d.amount, 1_234_567)
}
func testAddChipAccumulatesAndClampsAtMax() {
    var d = BonusDraft(); d.addChip(10); d.addChip(50); XCTAssertEqual(d.amount, 60)
    d.setAmountText("9999990"); d.addChip(100); XCTAssertEqual(d.amount, PaymentBonus.maxAmount)
}
func testBonusRequiresStampAndPositiveAmount() {
    var d = BonusDraft(); d.addChip(50); XCTAssertNil(d.bonus, "スタンプ未選択")
    d.stamp = .thanks; XCTAssertEqual(d.bonus, PaymentBonus(amount: 50, stamp: .thanks))
    d.setAmountText(""); XCTAssertNil(d.bonus, "額 0")
}
func testTotalAddsRemainderAndBonus() { var d = BonusDraft(); d.addChip(100); XCTAssertEqual(d.total(remainder: 230), 330) }
func testStampColumnsDropToOneAtAccessibilitySizes() {
    XCTAssertEqual(BonusDraft.stampColumnCount(isAccessibilitySize: false), 2)
    XCTAssertEqual(BonusDraft.stampColumnCount(isAccessibilitySize: true), 1)
}
```

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/BonusDraftTests`
Expected: コンパイルエラー（`BonusDraft` が未定義）

- [ ] **Step 3: `BonusDraft` → `BonusPaymentSheet` → `MonthlySummaryView` の副リンクとシートを実装する**

7 桁の上限は Core Data の `Integer 32` があふれないための技術上の上限（spec の「上限は設けない」はおまけの方針としての上限のこと）。

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`。アプリのビルドも通ること（シートと View はこの時点では UI テストで確かめない。Task 7 で通す）

- [ ] **Step 5: `git diff | cat -e` で、触っていない空行のインデントが消えていないか確かめて Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusDraft.swift \
  app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusPaymentSheet.swift \
  app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift \
  app/OtetsudaiCoinTests/Presentation/Components/BonusDraftTests.swift
git commit -m "feat(#279): おまけのシートと、月のまとめの「おまけを付けて支払う」リンクを足す"
```

---

### Task 5: 確定後の演出と「もらったおまけ」欄

**Files:**

- Create: `app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusCelebrationView.swift`
- Modify: `app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift`
- Test: Create `app/OtetsudaiCoinTests/Presentation/Components/BonusCelebrationViewTests.swift`

**Interfaces:**

- Consumes: Task 3 の `celebratingBonus` / `dismissCelebration()` / `MonthSnapshot.bonuses`（`BonusEntry.emoji` / `title` / `amount`）
- Produces:
  - `BonusCelebrationView(bonus: PaymentBonus, onClose: () -> Void)`。identifier: 全体 `bonus_celebration`、閉じる `bonus_celebration_close`
  - `extension BonusCelebrationView { struct MotionPlan { let initialScale: CGFloat; let entrance: Animation; static func make(reduceMotion: Bool) -> MotionPlan } }`（`SplashScreenView.MotionPlan.make(reduceMotion:)` と同じ形）
  - 「もらったおまけ」欄の identifier `summary_bonus_section`

演出の中身: 半透明の背景の上に、スタンプの絵文字（大）・スタンプ名・「+¥{amount}」・「閉じる」ボタン。勝手には消えない（親が子に見せてから閉じる）。**`MonthlySummaryView` の `.overlay` で `viewModel.celebratingBonus` が nil でないときに出す。`.sheet` / `.fullScreenCover` にしない**: おまけのシートが閉じる途中で次の表示を始めると、SwiftUI はその表示を黙って捨てることがあるため。VoiceOver では演出全体を 1 要素にまとめ（`.accessibilityElement(children: .combine)`）、「閉じる」は別のボタンとして残す。

「もらったおまけ」欄: `snap.bonuses` が空でないときだけ、ハイライト（`highlightBadges`）の下に出す。見出し「もらったおまけ」、1 件ごとに「{emoji} {title}」と「+¥{amount}」の行。支払い状態に関係なく出す（払い終えた月で見返すため）。上の「獲得 ¥{totalCoins}」にはおまけを足さない。

- [ ] **Step 1: 失敗するテストを書く**

```swift
func testReduceMotionPlanFadesWithoutScaling() {
    XCTAssertEqual(BonusCelebrationView.MotionPlan.make(reduceMotion: true).initialScale, 1.0, "動かさない")
}
func testDefaultPlanScalesIn() {
    XCTAssertLessThan(BonusCelebrationView.MotionPlan.make(reduceMotion: false).initialScale, 1.0)
}
func testShowsStampAndAmount() throws {
    // ViewInspector: BonusCelebrationView(bonus: PaymentBonus(amount: 50, stamp: .effort)!) {}
    // findAll(ViewType.Text.self) の文字列に "🏅" と "+¥50" を含む（ja の stamp 名は locale: ja で探す。
    // skill writing-swiftui-view-tests の「ViewInspector の既定ロケールは英語」）
}
func testCloseButtonCallsOnClose() throws  // find(button:) を tap() → 呼ばれた
```

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/BonusCelebrationViewTests`
Expected: コンパイルエラー（`BonusCelebrationView` が未定義）

- [ ] **Step 3: `BonusCelebrationView`・overlay・「もらったおまけ」欄を実装する**

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: `git diff | cat -e` を確かめて Commit**

```bash
git add app/OtetsudaiCoin/Presentation/Views/BonusPayment/BonusCelebrationView.swift \
  app/OtetsudaiCoin/Presentation/Views/MonthlySummaryView.swift \
  app/OtetsudaiCoinTests/Presentation/Components/BonusCelebrationViewTests.swift
git commit -m "feat(#279): おまけを払った瞬間の演出と、月のまとめの「もらったおまけ」欄を足す"
```

---

### Task 6: 文言の ja / en

**Files:**

- Modify: `app/OtetsudaiCoin/Resources/Localizable.xcstrings`
- Test: Modify `app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift`

**Interfaces:**

- Consumes: Task 1・4・5 で書いた文言（下の表がその全部。Task 4・5 の実装と食い違ったら、実装の文字列に合わせて表を直す）

skill `xcstrings-bulk-update` に従って足す（`json.dump` で整形を崩さない・既存の訳を上書きしない）。

| キー（ja） | en |
| --- | --- |
| がんばったで賞 | Great Effort Award |
| ありがとう賞 | Thank You Award |
| まいにちコツコツ賞 | Every Day Award |
| チャレンジ賞 | Challenge Award |
| おまけ | Bonus |
| おまけを付けて支払う | Pay with a bonus |
| おまけを付ける | Add a bonus |
| スタンプを選ぶ | Pick a stamp |
| おまけの額 | Bonus amount |
| お小遣い | Allowance |
| 渡す額 | Total to give |
| おまけを付けて支払う ¥%lld | Pay ¥%lld with bonus |
| もらったおまけ | Bonuses received |
| +¥%lld | +¥%lld |
| 閉じる | Close |
| キャンセル | Cancel |

`閉じる` / `キャンセル` は既にあるかもしれない。あれば足さない（既存の訳を変えない）。

- [ ] **Step 1: 失敗するテストを書く**

`testMonthlyRecordPaymentStatusKeysExist`（`:163`）と同じ形で `testBonusPaymentKeysExist` を書き、上の表のキーを並べる。既存の `testAllKeysHaveEnglishTranslation` は catalog にあるキーしか見ないので、キーを入れ忘れても落ちない。それを塞ぐのがこのテスト。

- [ ] **Step 2: 失敗を確かめる**

Run: `-only-testing:OtetsudaiCoinTests/LocalizationStringCatalogTests`
Expected: FAIL（足していないキーの名前が出る）

- [ ] **Step 3: xcstrings に足す**

- [ ] **Step 4: 通ることを確かめる**

Run: Step 2 と同じ。Expected: `** TEST SUCCEEDED **`（`testAllKeysHaveEnglishTranslation` / `testEnglishTranslationsAreNotJapanese` も通る）。`git diff --stat` で xcstrings の差分が足した行の分だけであることを見る

- [ ] **Step 5: Commit**

```bash
git add app/OtetsudaiCoin/Resources/Localizable.xcstrings app/OtetsudaiCoinTests/Localization/LocalizationStringCatalogTests.swift
git commit -m "feat(#279): おまけの文言を ja / en で String Catalog に足す"
```

---

### Task 7: UI テストと見た目の確認

**Files:**

- Create: `app/OtetsudaiCoinUITests/BonusPaymentUITests.swift`
- Modify: `app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift`（シーン verify-28〜30。2026-11-08 に `grep -rn "verify-2[89]\|verify-3[0-9]"` で空を確認済み。着手時にもう一度 grep する）

**Interfaces:**

- Consumes: Task 4・5 の accessibilityIdentifier、既存の `home_monthly_summary_entry` / `child_button` / `record_button` / `summary_payment_cta`

なぜ別クラスか: `VerificationScreenshotUITests` は撮影 script が毎回全部流す。合否だけを見るテストは別クラスに置く（前例: `FeedbackSettingsUITests`）。

起動は `--uitesting --hide-developer-tools --in-memory-store -AppleLanguages (ja) -AppleLocale ja_JP`。サンプルの子どもには記録が無いので、テストの最初に記録タブで「お風呂を入れる」を 1 回記録する（既定の文字サイズでは、カードはそのまま押せる。AX サイズ向けのスクロール helper は要らない）。そのあとホームで最初の子 → 月のまとめを開く。額は文字入力（`typeText`）ではなくチップで入れる（Simulator のキーボードの状態でぶれるため）。

- [ ] **Step 1: テストを書く**

```swift
/// アンチゴール「支払いが面倒になる」の囲い: おまけを付けない支払いは CTA の 1 タップで終わる
func testPlainPaymentTakesOneTap() {
    // 記録 → 月のまとめ → summary_payment_cta を 1 回 tap
    // 期待: 5 秒以内に summary_payment_cta が消える / bonus_confirm_button も bonus_celebration も出ていない
}
/// おまけの流れ: シート → スタンプ → チップ → 確定 → 演出 → 閉じる → 「もらったおまけ」欄
func testBonusPaymentShowsCelebrationThenSummaryEntry() {
    // summary_bonus_payment_entry → bonus_confirm_button が無効 → bonus_stamp_effort → bonus_chip_50
    // → bonus_confirm_button が有効で label に "¥" を含む → tap
    // → bonus_celebration が出る、"+¥50" の文字がある → bonus_celebration_close
    // → summary_bonus_section が出て "+¥50" を含む / summary_payment_cta が消えている
}
```

`VerificationScreenshotUITests.testCaptureBonusPayment`: 既存の helper（`launchMainApp(extraArguments: ["--in-memory-store"])`、`tapCardAboveRecordBar`）で記録してから月のまとめへ。シートで `bonus_stamp_effort` と `bonus_chip_50` を選んだ状態を `verify-28-bonus-sheet`、確定後の演出を `verify-29-bonus-celebration`、閉じた後に `summary_bonus_section` まで上へスクロールして `verify-30-summary-bonus` として撮る。ファイル冒頭のシーン一覧のコメントにも 28〜30 を足す。

- [ ] **Step 2: 走らせて通ることを確かめる**

Run: `-parallel-testing-enabled NO -only-testing:OtetsudaiCoinUITests/BonusPaymentUITests`
Expected: `** TEST SUCCEEDED **`（2 件）。落ちたら、Task 4・5 の View を直す（テストを緩めない）

- [ ] **Step 3: 見た目を撮って一次目視する**

```bash
./scripts/capture-verification-screenshots.sh --appearance both
./scripts/capture-verification-screenshots.sh --appearance light --content-size accessibility-extra-extra-extra-large
```

`docs/screenshots/verification/{light,dark}/` の verify-07・28・29・30 を Read で見て、「シーン / 外観 / 文字サイズ / 気づいたこと」の表にまとめる。見るところ: AX 最大でスタンプ名・内訳・確定ボタンの「¥」が切れない（「…」が出ない）、ダークで演出の背景と文字が読める、verify-07（おまけなしの月のまとめ）に副リンクが CTA より目立たずに出ている。撮影の出力は gitignored なので commit しない。

- [ ] **Step 4: Commit**

```bash
git add app/OtetsudaiCoinUITests/BonusPaymentUITests.swift app/OtetsudaiCoinUITests/VerificationScreenshotUITests.swift
git commit -m "test(#279): 1 タップの支払いとおまけの流れの UI テスト、撮影シーン 28〜30 を足す"
```

---

## 最後に（全 Task の後）

- `-only-testing:OtetsudaiCoinTests` 全体と `BonusPaymentUITests` を流し、件数を xcresult の summary で読む
- 最終の whole-branch レビュー（project CLAUDE.md「Subagent / Task 実行ルール」）
- PR 本文: `Refs #279`。Task 7 の目視の表、`## Plan からの逸脱`（実装中に出たもの）、下の「Claude の判断」を載せる

## spec からの読み替えと、Claude の判断（PR 本文にも書く）

- **見返す画面は月のまとめだけ**: spec のゴール 3 に「（と履歴）」とあるが、決まったことの表は「月のまとめ」なので、そちらに従う。履歴の画面は触らない
- **額の入力は 7 桁まで**: Core Data の `Integer 32` があふれないための技術上の上限。おまけの方針としての上限は設けない
- **おまけの額は 1 以上、スタンプは必須**: spec の「額 + 褒め言葉スタンプ 1 つ」をそのまま読んだ。スタンプだけ（額 0）の「褒めるだけ」は v1 に入れない
- **全角数字の貼り付けは落とす**: numberPad は半角を出すため、全角が入るのは貼り付けのときだけ
- **スタンプの 4 種と en の訳**（Task 1 の表）: spec の例示から決めた。オーナーが PR で見て直せるよう、PR 本文に表を載せる
- **データは同じ行に持つ**（別エンティティにしない）: 1 回の支払いで渡すものが 1 行にまとまり、月のまとめの読み込み（`findByChildId` の 1 回）で取れる
