import Foundation

/// 効果音とハプティクスの ON/OFF 設定 (#150)。
protocol FeedbackSettingsServiceProtocol: AnyObject {
    var isSoundEnabled: Bool { get set }
    var isHapticEnabled: Bool { get set }
}

/// `ReminderNotificationService` と同じ「protocol + UserDefaults 注入」の流儀に従うが、
/// 値を stored property にキャッシュせず computed property で毎回 UserDefaults を読む。
///
/// SettingsView は service を自前生成する作りのため (SettingsView.swift:34-37)、
/// 記録画面と設定画面でインスタンスが並存する。init で読んだ値を保持する方式だと
/// 設定画面で OFF にしても記録画面は起動時の true を読み続け、
/// アプリを再起動するまで OFF が効かない。UserDefaults を single source of truth に
/// することでこの不整合を構造的に排除する。
final class FeedbackSettingsService: FeedbackSettingsServiceProtocol {
    private enum UserDefaultsKey {
        static let sound = "sound_enabled"
        static let haptic = "haptic_enabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// 未保存なら true（初回起動時は両方 ON = 従来の効果音挙動を維持）
    var isSoundEnabled: Bool {
        get { userDefaults.object(forKey: UserDefaultsKey.sound) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: UserDefaultsKey.sound) }
    }

    var isHapticEnabled: Bool {
        get { userDefaults.object(forKey: UserDefaultsKey.haptic) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: UserDefaultsKey.haptic) }
    }
}
