import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
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
                            viewModel.loadChildren()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.children.isEmpty {
                    VStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("お子様を登録してください")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        if let selectedChild = viewModel.selectedChild {
                            childStatsView(for: selectedChild)
                        }
                        
                        childrenListView
                    }
                    .padding()
                }
            }
            .navigationTitle("おてつだいコイン")
            .onAppear {
                viewModel.loadChildren()
            }
        }
    }
    
    private func childStatsView(for child: Child) -> some View {
        VStack(spacing: 16) {
            Text(child.name)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(viewModel.totalRecordsThisMonth)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    Text("今月の実績: \(viewModel.totalRecordsThisMonth)回")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.consecutiveDays)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    Text("連続日数: \(viewModel.consecutiveDays)日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.monthlyAllowance)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    Text("お小遣い: \(viewModel.monthlyAllowance)円")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var childrenListView: some View {
        VStack(alignment: .leading) {
            Text("お子様を選択")
                .font(.headline)
                .padding(.horizontal)
            
            List(viewModel.children, id: \.id) { child in
                Button(action: {
                    viewModel.selectChild(child)
                }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: child.themeColor) ?? .blue)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(child.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                        
                        Text(child.name)
                            .font(.title3)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if viewModel.selectedChild?.id == child.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listStyle(PlainListStyle())
        }
    }
}

extension Color {
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        
        let hexColor = String(hex.dropFirst())
        guard let value = UInt64(hexColor, radix: 16) else { return nil }
        
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}