import SwiftUI

struct NotificationSettingsView: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @Bindable var paymentViewModel: PaymentReminderNotificationSettingsViewModel

    var body: some View {
        Form {
            Section("リマインド通知") {
                Toggle("通知を有効にする", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { newValue in
                        Task { await viewModel.toggleNotification(enabled: newValue) }
                    }
                ))

                if viewModel.isEnabled {
                    DatePicker(
                        "通知時間",
                        selection: Binding(
                            get: { viewModel.reminderTime },
                            set: { newTime in
                                Task { await viewModel.updateReminderTime(newTime) }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section("支払いリマインド") {
                Toggle("通知を有効にする", isOn: Binding(
                    get: { paymentViewModel.isEnabled },
                    set: { newValue in
                        Task { await paymentViewModel.toggleNotification(enabled: newValue) }
                    }
                ))

                if paymentViewModel.isEnabled {
                    DatePicker(
                        "通知時間",
                        selection: Binding(
                            get: { paymentViewModel.reminderTime },
                            set: { newTime in
                                Task { await paymentViewModel.updateReminderTime(newTime) }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .navigationTitle("通知設定")
        .commonAlerts(
            errorMessage: viewModel.errorMessage,
            successMessage: nil,
            onErrorDismiss: { viewModel.clearErrorMessage() }
        )
        .commonAlerts(
            errorMessage: paymentViewModel.errorMessage,
            successMessage: nil,
            onErrorDismiss: { paymentViewModel.clearErrorMessage() }
        )
    }
}
