import Foundation

/// 設定画面の「サウンドと触覚」トグルを仲介する ViewModel (#150)。
///
/// SwiftUI の Toggle へ束縛するため値を stored property に持つが、
/// 変更は didSet で即座に service (= UserDefaults) へ書き戻す。
/// 記録画面側は service を毎回読むため、ここでの変更は次の発火から反映される。
@MainActor
@Observable
class FeedbackSettingsViewModel {

    var isSoundEnabled: Bool {
        didSet { service.isSoundEnabled = isSoundEnabled }
    }

    var isHapticEnabled: Bool {
        didSet { service.isHapticEnabled = isHapticEnabled }
    }

    private let service: FeedbackSettingsServiceProtocol

    init(service: FeedbackSettingsServiceProtocol) {
        self.service = service
        self.isSoundEnabled = service.isSoundEnabled
        self.isHapticEnabled = service.isHapticEnabled
    }
}
