# HomeViewModelTests flaky test 修正

## Context

`HomeViewModelTests` で4つのテストが不安定に失敗している。原因は `checkUnpaidAllowances()` が内部で fire-and-forget の `Task {}` を使用しており、テストが非同期処理完了前にアサーションを実行してしまうため。変更前のコードでも同じテストが失敗することを確認済み（今回の未払いアラート常時表示化とは無関係の既存問題）。

## 方針: `checkUnpaidAllowances()` を async 化

内部の `Task {}` ラッパーを除去し、メソッド自体を `async` にする。呼び出し元の `loadChildren()` は既に `Task {}` ブロック内なので `await` を追加するだけで済む。テスト側は `await viewModel.checkUnpaidAllowances()` で確定的に待機できる。

## 変更内容

### 1. `HomeViewModel.swift` — `checkUnpaidAllowances()` を async 化

```swift
// Before:
func checkUnpaidAllowances() {
    Task {
        do {
            // ... async work ...
        } catch { ... }
    }
}

// After:
func checkUnpaidAllowances() async {
    do {
        // ... same async work, Task wrapper removed ...
    } catch { ... }
}
```

### 2. `HomeViewModel.swift` — `loadChildren()` の呼び出し箇所を await に変更

```swift
// Before:
if !children.isEmpty {
    checkUnpaidAllowances()
}

// After:
if !children.isEmpty {
    await checkUnpaidAllowances()
}
```

### 3. `HomeViewModel.swift` — `refreshDataTask` を `private(set)` に変更

```swift
// Before:
private var refreshDataTask: Task<Void, Never>?

// After:
private(set) var refreshDataTask: Task<Void, Never>?
```

テストから `await viewModel.refreshDataTask?.value` で待機可能にする。

### 4. `HomeViewModelTests.swift` — 5つのテストメソッドを修正

| テスト | 修正内容 |
|--------|----------|
| `testCheckUnpaidAllowancesWithNoUnpaid` | `async` 追加、`await` 使用 |
| `testCheckUnpaidAllowancesWithUnpaidPeriods` | `async` 追加、`await` 使用 |
| `testCheckUnpaidAllowancesWithMultipleChildren` | `async` 追加、`await` 使用 |
| `testDismissUnpaidWarning` | `async` 追加、`await` 使用 |
| `testSelectDifferentChildAfterSameChild` | `Task.sleep` → `await viewModel.refreshDataTask?.value` |

## 変更ファイル

- `app/OtetsudaiCoin/Presentation/ViewModels/HomeViewModel.swift`
- `app/OtetsudaiCoinTests/Presentation/HomeViewModelTests.swift`

## 検証

1. `xcodebuild test` で `HomeViewModelTests` 全8テストがパスすることを確認
2. `UnpaidAllowanceDetectorServiceTests` 全7テストがパスすることを確認
3. ビルド成功を確認
