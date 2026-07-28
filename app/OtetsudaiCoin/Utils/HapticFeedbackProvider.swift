import Foundation

/// 触覚フィードバックの発火口 (#150)。
///
/// `HapticFeedback` は static メソッドの集まりでテスト時に差し替えられないため、
/// 呼び出し側から見える seam としてこの protocol を挟む。
/// ON/OFF の判定はここでは行わない (呼び出し側が FeedbackSettingsService を見て決める)。
protocol HapticFeedbackProviding {
    func helpRecorded()
    func taskSelection()
    func childSelection()
    func errorOccurred()
}

/// 実機向けの実装。既存の `HapticFeedback` へ委譲するだけの薄いアダプタ。
struct SystemHapticFeedbackProvider: HapticFeedbackProviding {
    func helpRecorded() { HapticFeedback.helpRecorded() }
    func taskSelection() { HapticFeedback.taskSelection() }
    func childSelection() { HapticFeedback.childSelection() }
    func errorOccurred() { HapticFeedback.errorOccurred() }
}
