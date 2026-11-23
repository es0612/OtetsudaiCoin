// scripts/fixed-wait-check.sh の自己テスト用 fixture (Xcode のターゲットには含まれない)。
// 期待: 違反 5 件 / 許可 2 件。
// 行を足したり消したりしたら、test-wait-check.yml の期待値も直す。
import XCTest

final class FixedWaitCheckSample: XCTestCase {
    func violations() async {
        try? await Task.sleep(nanoseconds: 100_000_000)                // 違反 1: Task.sleep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { }       // 違反 2: asyncAfter
        Thread.sleep(forTimeInterval: 0.1)                              // 違反 3: Thread.sleep
        sleep(1)                                                        // 違反 4: sleep(
        // 違反 5: allow-fixed-wait の理由が空 (次の行)
        try? await Task.sleep(nanoseconds: 1) // allow-fixed-wait:
    }

    func allowed() async {
        try? await Task.sleep(nanoseconds: 10_000_000) // allow-fixed-wait: ポーリング間隔
        try? await Task.sleep(nanoseconds: 1)  // 1ns. allow-fixed-wait: 否定の確認
    }

    func notViolations() async {
        // Task.sleep や asyncAfter で待たない (コメントの中の言及は数えない)
        let player = Player()
        player.sleep(1)                                                 // 別の型の .sleep( は対象外
        let asleep = 1                                                  // 識別子の一部は対象外
        _ = asleep
    }
}

private struct Player {
    func sleep(_ seconds: Int) {}
}
