import Foundation

struct PaymentSettings: Codable, Equatable {
    let paymentDay: Int // 1-31の日付
    let isAutoPaymentEnabled: Bool
    
    init(paymentDay: Int = 1, isAutoPaymentEnabled: Bool = true) {
        self.paymentDay = max(1, min(31, paymentDay))
        self.isAutoPaymentEnabled = isAutoPaymentEnabled
    }
    
    static let `default` = PaymentSettings()
}

class PaymentSettingsManager: ObservableObject {
    @Published var settings: PaymentSettings = PaymentSettings.default
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "payment_settings"
    
    init() {
        loadSettings()
    }
    
    func saveSettings(_ settings: PaymentSettings) {
        self.settings = settings
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(PaymentSettings.self, from: data) else {
            return
        }
        self.settings = settings
    }
}