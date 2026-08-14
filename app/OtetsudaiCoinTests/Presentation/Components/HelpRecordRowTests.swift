import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// `HelpRecordRow`（履歴 1 行）のコンポーネントテスト。
///
/// 親の `HelpHistoryView` は NavigationStack + List + Image(systemName:) の
/// 組み合わせで ViewInspector が traverse できないが、`HelpRecordRow` は
/// トップレベル struct なので単独で検証できる
/// (CLAUDE.md § SwiftUI View テスト戦略「Component 分離による blocker 回避」)。
///
/// `accessibilityIdentifier` は ViewInspector 0.10.2 + iOS 26 SDK で解決不能なため、
/// `findAll(ViewType.Button.self)` ベースで掴む。
@MainActor
final class HelpRecordRowTests: XCTestCase {

    private func makeView(
        taskName: String = "皿洗い",
        taskIcon: String? = nil,
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) -> HelpRecordRow {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")
        let task = HelpTask(id: UUID(), name: taskName, isActive: true, coinRate: 100, sortOrder: 0, icon: taskIcon)
        let record = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: task.id,
            recordedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        )
        return HelpRecordRow(
            record: HelpRecordWithDetails(helpRecord: record, child: child, task: task),
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    /// #151: 編集・削除ボタンは HIG の最小タップ領域 44×44pt を満たす。
    ///
    /// 修正前は明示 frame が無く、`Image(systemName:).font(.system(size: 16))` の
    /// 実寸（約 16〜20pt）がそのままタップ領域だった。しかも 2 つが 12pt 間隔で
    /// 横並びなので、押し間違いが起きやすい。
    ///
    /// 失敗時に観測値を dump し、「frame が読めない」のか「値が足りない」のかを
    /// 再実行なしで切り分けられるようにする。
    func test_editAndDeleteButtons_meetMinimumTapTargetSize() throws {
        let minimumTapTarget: CGFloat = 44
        let view = makeView()

        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertEqual(buttons.count, 2, "編集・削除の 2 ボタンが見つからない (buttons=\(buttons.count))")

        // タップ領域は Button ではなく label 側の Image に付けている
        // (contentShape と組で当たり判定を frame 全体へ広げるため)。
        // Image は AccessibilityImageLabel blocker になるが、findAll なら列挙できる。
        // frame を持たない兄弟 Image (star.fill) は compactMap で落ちる。
        // 行頭アイコンは #177 で Text 絵文字になったため Image 列挙に現れない。
        let images = try view.inspect().findAll(ViewType.Image.self)
        let frames = images.compactMap { try? $0.fixedFrame() }
        XCTAssertEqual(
            frames.count, 2,
            "編集・削除アイコンの frame を 2 つ読めない (images=\(images.count) / frames=\(frames.map { ($0.width, $0.height) }))"
        )

        for frame in frames {
            XCTAssertGreaterThanOrEqual(
                frame.width ?? 0, minimumTapTarget,
                "アクションボタンの幅が 44pt 未満 / frames: \(frames.map { ($0.width, $0.height) })"
            )
            XCTAssertGreaterThanOrEqual(
                frame.height ?? 0, minimumTapTarget,
                "アクションボタンの高さが 44pt 未満 / frames: \(frames.map { ($0.width, $0.height) })"
            )
        }
    }

    /// タップ領域を広げても、それぞれのボタンが正しいコールバックに繋がっている。
    /// (frame を足す過程で onEdit / onDelete が入れ替わる事故を防ぐ)
    func test_buttonsInvokeTheirOwnCallbacks() throws {
        var edited = false
        var deleted = false
        let view = makeView(onEdit: { edited = true }, onDelete: { deleted = true })

        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertEqual(buttons.count, 2, "編集・削除の 2 ボタンが見つからない")

        try buttons[0].tap()
        XCTAssertTrue(edited, "1 つ目のボタンで onEdit が呼ばれない")
        XCTAssertFalse(deleted, "1 つ目のボタンで onDelete まで呼ばれている")

        try buttons[1].tap()
        XCTAssertTrue(deleted, "2 つ目のボタンで onDelete が呼ばれない")
    }

    /// #177 項目5: 行頭アイコンはタスクの displayIcon 絵文字を表示する (#148 の展開)。
    func test_rowIcon_rendersExplicitIconEmoji() throws {
        let view = makeView(taskIcon: "🧹")
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする (displayIcon の既定挙動が row に配線されていること)。
    func test_rowIcon_fallsBackToSparkleForUnknownName() throws {
        let view = makeView(taskName: "辞書に無い独自タスク")
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }
}
