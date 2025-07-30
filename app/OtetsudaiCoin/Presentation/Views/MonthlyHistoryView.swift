import SwiftUI

struct MonthlyHistoryView: View {
    @Bindable var viewModel: MonthlyHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("再試行") {
                            viewModel.refreshData()
                        }
                        .primaryGradientButton()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.monthlyRecords.isEmpty {
                    VStack {
                        Image(systemName: "calendar.badge.minus")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("まだ履歴がありません")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.monthlyRecords, id: \.monthYearString) { monthlyRecord in
                        MonthlyRecordRow(monthlyRecord: monthlyRecord) { record in
                            Task {
                                await viewModel.payAllowance(for: record)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("月別履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                viewModel.refreshData()
            }
        }
        .onAppear {
            // selectedChildがセットされているか確認してからデータロード
            if viewModel.selectedChild != nil && viewModel.monthlyRecords.isEmpty {
                viewModel.refreshData()
            } else if viewModel.selectedChild == nil {
                // 子供が選択されていない場合のログ
                print("Warning: MonthlyHistoryView appeared but selectedChild is nil")
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct MonthlyRecordRow: View {
    let monthlyRecord: MonthlyRecord
    let onPayment: (MonthlyRecord) -> Void
    @State private var isExpanded = false
    @State private var showingPaymentConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthlyRecord.monthYearString)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("\(monthlyRecord.totalRecords)回")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("\(monthlyRecord.allowanceAmount)コイン")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if monthlyRecord.isPaid {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("支払い済み")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack {
                                Image(systemName: "clock.circle")
                                    .foregroundColor(.orange)
                                Text("未払い")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if monthlyRecord.helpRecords.isEmpty {
                        Text("この月のお手伝い記録はありません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("お手伝い記録")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(Array(monthlyRecord.helpRecords.enumerated()), id: \.offset) { index, record in
                            HStack {
                                Image(systemName: "hands.sparkles")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text(record.recordedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // タスク名を表示したい場合は、HelpTaskRepositoryから取得する必要がある
                                Text("お手伝い")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    
                    if let payment = monthlyRecord.paymentRecord {
                        Divider()
                        
                        Text("支払い記録")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(payment.paidAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(payment.amount)コイン支払い")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding(.leading, 8)
                    }
                    
                    // 支払いボタンを追加
                    if !monthlyRecord.isPaid && monthlyRecord.allowanceAmount > 0 {
                        Divider()
                        
                        Button(action: {
                            showingPaymentConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(.white)
                                Text("\(monthlyRecord.monthYearString)のお小遣いを支払う")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(monthlyRecord.allowanceAmount)コイン")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
        .alert("お小遣い支払い確認", isPresented: $showingPaymentConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("支払う") {
                onPayment(monthlyRecord)
            }
        } message: {
            Text("\(monthlyRecord.monthYearString)のお小遣い\(monthlyRecord.allowanceAmount)コインを支払いますか？")
        }
    }
}

#Preview {
    @Previewable @State var previewViewModel: MonthlyHistoryViewModel?
    
    Group {
        if let viewModel = previewViewModel {
            MonthlyHistoryView(viewModel: viewModel)
        } else {
            Text("Loading...")
        }
    }
    .task {
        await MainActor.run {
            let context = PersistenceController.preview.container.viewContext
            let helpRecordRepo = CoreDataHelpRecordRepository(context: context)
            let paymentRepo = InMemoryAllowancePaymentRepository.shared
            let calculator = AllowanceCalculator()
            
            previewViewModel = MonthlyHistoryViewModel(
                helpRecordRepository: helpRecordRepo,
                allowancePaymentRepository: paymentRepo,
                helpTaskRepository: CoreDataHelpTaskRepository(context: context),
                allowanceCalculator: calculator
            )
        }
    }
}