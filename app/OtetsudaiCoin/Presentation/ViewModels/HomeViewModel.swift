import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var children: [Child] = []
    @Published var selectedChild: Child?
    @Published var monthlyAllowance: Int = 0
    @Published var consecutiveDays: Int = 0
    @Published var totalRecordsThisMonth: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let childRepository: ChildRepository
    private let helpRecordRepository: HelpRecordRepository
    private let allowanceCalculator: AllowanceCalculator
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        childRepository: ChildRepository,
        helpRecordRepository: HelpRecordRepository,
        allowanceCalculator: AllowanceCalculator
    ) {
        self.childRepository = childRepository
        self.helpRecordRepository = helpRecordRepository
        self.allowanceCalculator = allowanceCalculator
        
        // SwiftUIの宣言的な仕組み：NotificationCenterでデータ更新を自動監視
        NotificationCenter.default
            .publisher(for: .helpRecordUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadChildren() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedChildren = try await childRepository.findAll()
                children = loadedChildren
                isLoading = false
            } catch {
                errorMessage = "子供の情報を読み込めませんでした: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        refreshData()
    }
    
    func refreshData() {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let records = try await helpRecordRepository.findByChildIdInCurrentMonth(child.id)
                
                monthlyAllowance = allowanceCalculator.calculateMonthlyAllowance(records: records, child: child)
                consecutiveDays = allowanceCalculator.calculateConsecutiveDays(records: records)
                totalRecordsThisMonth = records.count
                
                isLoading = false
            } catch {
                errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}