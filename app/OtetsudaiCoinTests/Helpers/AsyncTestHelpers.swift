import XCTest

extension XCTestCase {
    /// 条件が満たされるまで 10ms ごとに確かめて待つ (#313)。
    ///
    /// ViewModel が `Task { }` で起こした非同期処理の完了を待つときに使う。
    /// 「0.1 秒待てば終わっているはず」という固定時間の待ちは、遅い CI の runner や
    /// メインスレッドが一時的に止まったときに間に合わず、テストが時々落ちる。
    /// ここでは条件そのものを待つので、速い環境では数 ms で抜け、遅い環境では timeout まで待てる。
    /// timeout までに満たされなければ、呼び出し元の行で XCTFail する。
    @MainActor
    @discardableResult
    func waitUntil(
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("waitUntil: \(timeout) 秒待っても条件が満たされませんでした", file: file, line: line)
                return false
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms. allow-fixed-wait: waitUntil 自身のポーリング間隔
        }
        return true
    }
}
