import SwiftUI

struct NotificationSettingsView: View {
    @Bindable var viewModel: NotificationSettingsViewModel

    var body: some View {
        Form {
            Section("リマインド通知") {
                Toggle("通知を有効にする", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.toggleNotification(enabled: newValue)
                        }
                    }
                ))

                if viewModel.isEnabled {
                    DatePicker(
                        "通知時間",
                        selection: Binding(
                            get: { viewModel.reminderTime },
                            set: { newTime in
                                Task {
                                    await viewModel.updateReminderTime(newTime)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .navigationTitle("通知設定")
    }
}
