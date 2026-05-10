import Foundation

@MainActor
@Observable
class MonthlyRetrospectiveViewModel {

    // MARK: - State

    private(set) var selectedMonth: Date

    var snapshot: MonthSnapshot?

    var isLoading: Bool = false

    let child: Child

    // MARK: - Dependencies

    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowancePaymentRepository: AllowancePaymentRepository

    // MARK: - Constants

    static let maxMonthsAgo = 12

    // MARK: - Init

    init(
        child: Child,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        allowancePaymentRepository: AllowancePaymentRepository
    ) {
        self.child = child
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowancePaymentRepository = allowancePaymentRepository

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        self.selectedMonth = cal.date(from: comps) ?? Date()
    }

    // MARK: - Navigation

    func goToPreviousMonth() {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .month, value: -1, to: selectedMonth) else { return }

        guard let earliest = cal.date(byAdding: .month, value: -Self.maxMonthsAgo, to: currentMonthStart()) else { return }

        if candidate < earliest { return }

        selectedMonth = candidate
    }

    func goToNextMonth() {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .month, value: 1, to: selectedMonth) else { return }

        if candidate > currentMonthStart() { return }

        selectedMonth = candidate
    }

    // MARK: - Helpers

    private func currentMonthStart() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }
}

// MARK: - MonthSnapshot

struct MonthSnapshot: Equatable {
    let monthLabel: String
    let totalCount: Int
    let totalCoins: Int
    let taskBreakdown: [TaskBreakdownItem]
    let highlights: Highlights
    let calendar: [DailyActivity]
    let paymentStatus: PaymentStatus

    struct TaskBreakdownItem: Equatable {
        let name: String
        let count: Int
        let coinTotal: Int
    }

    struct DailyActivity: Equatable {
        let day: Int
        let count: Int
    }

    enum PaymentStatus: Equatable {
        case paid
        case unpaid
        case partiallyPaid
    }
}
