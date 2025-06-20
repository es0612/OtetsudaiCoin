import SwiftUI

struct PaymentDatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var paymentSettingsManager: PaymentSettingsManager
    @State private var selectedDay: Int
    
    init(paymentSettingsManager: PaymentSettingsManager) {
        self.paymentSettingsManager = paymentSettingsManager
        self._selectedDay = State(initialValue: paymentSettingsManager.settings.paymentDay)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("お小遣いを支払う日を選択してください")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Picker("支払日", selection: $selectedDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)日").tag(day)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                
                Text("毎月\(selectedDay)日に自動でお小遣いが支払われます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("支払日設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newSettings = PaymentSettings(
                            paymentDay: selectedDay,
                            isAutoPaymentEnabled: paymentSettingsManager.settings.isAutoPaymentEnabled
                        )
                        paymentSettingsManager.saveSettings(newSettings)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    PaymentDatePickerView(paymentSettingsManager: PaymentSettingsManager())
}