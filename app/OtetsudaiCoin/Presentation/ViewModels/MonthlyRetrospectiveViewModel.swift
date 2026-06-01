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

        // #54: sheet 表示直後の empty state（「データがありません」）gap を避けるため、
        // init で defensive に isLoading=true を立てる。
        // actual load の kick は HomeView.prepareRetrospectiveViewModel 側で行う設計（責務分離）。
        self.isLoading = true
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

    // MARK: - Loading

    func loadMonth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allRecords = try await helpRecordRepository.findByChildId(child.id)
            let allTasks = try await helpTaskRepository.findAll()
            let allPayments = try await allowancePaymentRepository.findByChildId(child.id)

            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: selectedMonth)
            let year = comps.year ?? 0
            let month = comps.month ?? 0

            let monthRecords = allRecords.filter { record in
                let rc = cal.dateComponents([.year, .month], from: record.recordedAt)
                return rc.year == year && rc.month == month
            }

            let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })

            let totalCount = monthRecords.count
            let calculator = AllowanceCalculator()
            let totalCoins = calculator.calculateMonthlyAllowance(records: monthRecords, tasks: allTasks)

            let breakdown = computeTaskBreakdown(records: monthRecords, taskMap: taskMap)

            let service = RetrospectiveHighlightService()
            let highlights = service.compute(records: monthRecords, tasks: allTasks)

            let calendarDays = computeCalendarDays(records: monthRecords, year: year, month: month)

            let paymentStatus = computePaymentStatus(
                payments: allPayments,
                year: year,
                month: month,
                expected: totalCoins
            )

            let monthLabel = "\(year)年\(month)月"

            self.snapshot = MonthSnapshot(
                monthLabel: monthLabel,
                totalCount: totalCount,
                totalCoins: totalCoins,
                taskBreakdown: breakdown,
                highlights: highlights,
                calendar: calendarDays,
                paymentStatus: paymentStatus
            )
        } catch {
            self.snapshot = nil
        }
    }

    private func computeTaskBreakdown(records: [HelpRecord], taskMap: [UUID: HelpTask]) -> [MonthSnapshot.TaskBreakdownItem] {
        let groups = Dictionary(grouping: records) { $0.helpTaskId }
        return groups.compactMap { taskId, recs in
            guard let task = taskMap[taskId] else { return nil }
            return MonthSnapshot.TaskBreakdownItem(
                name: task.displayName,
                count: recs.count,
                coinTotal: recs.count * task.coinRate
            )
        }
        .sorted { $0.count > $1.count }
    }

    private func computeCalendarDays(records: [HelpRecord], year: Int, month: Int) -> [MonthSnapshot.DailyActivity] {
        let cal = Calendar.current
        var monthStartComps = DateComponents()
        monthStartComps.year = year
        monthStartComps.month = month
        monthStartComps.day = 1
        guard let monthStart = cal.date(from: monthStartComps),
              let range = cal.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let countsByDay: [Int: Int] = Dictionary(grouping: records) { record in
            cal.component(.day, from: record.recordedAt)
        }.mapValues { $0.count }

        return range.map { day in
            MonthSnapshot.DailyActivity(day: day, count: countsByDay[day] ?? 0)
        }
    }

    private func computePaymentStatus(
        payments: [AllowancePayment],
        year: Int,
        month: Int,
        expected: Int
    ) -> MonthSnapshot.PaymentStatus {
        let monthPayments = payments.filter { $0.year == year && $0.month == month }
        let totalPaid = monthPayments.reduce(0) { $0 + $1.amount }

        if totalPaid == 0 { return .unpaid }
        if totalPaid >= expected { return .paid }
        return .partiallyPaid
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
