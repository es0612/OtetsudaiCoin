import Foundation

@MainActor
@Observable
class MonthlySummaryViewModel {

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
        allowancePaymentRepository: AllowancePaymentRepository,
        initialMonth: Date? = nil
    ) {
        self.child = child
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowancePaymentRepository = allowancePaymentRepository

        let cal = Calendar.current
        let anchor = initialMonth ?? Date()
        let comps = cal.dateComponents([.year, .month], from: anchor)
        self.selectedMonth = cal.date(from: comps) ?? anchor

        // #54: sheet/遷移直後の empty state gap を避けるため init で isLoading=true。
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

    // MARK: - Payment

    /// 表示中の月の「未払い残額」を支払う。完済済みなら no-op。
    /// 既払いがある月（.partiallyPaid）は残額のみを新規 payment として保存する（全額二重払いを防ぐ）。
    /// 残額は新規の payment 行として保存するが、computePaymentStatus が当月の全 payment 行を
    /// 合算して判定するため、残額行を別途追加しても合計が totalCoins に達し .paid と判定される。
    /// 保存後 loadMonth で paidAmount / paymentStatus を再評価する。
    /// isLoading を in-flight ガードに用い、CTA の double-tap による二重 save（全額過払い）を防ぐ。
    func payCurrentMonth() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let snap = snapshot, snap.paymentStatus != .paid else { return }
        let remainder = snap.totalCoins - snap.paidAmount
        guard remainder > 0 else { return }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let year = comps.year, let month = comps.month else { return }
        do {
            let payment = AllowancePayment(
                id: UUID(),
                childId: child.id,
                amount: remainder,
                month: month,
                year: year,
                paidAt: Date(),
                note: "\(year)年\(month)月のお小遣い支払い"
            )
            try await allowancePaymentRepository.save(payment)
            await loadMonth()   // paidAmount/paymentStatus を再評価（loadMonth が isLoading を管理）
        } catch {
            // 保存失敗時は snapshot を維持（paymentStatus は変わらない）
            DebugLogger.error("payCurrentMonth failed: \(error)")
        }
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

            let monthPayments = allPayments.filter { $0.year == year && $0.month == month }
            let paidAmount = monthPayments.reduce(0) { $0 + $1.amount }

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
                paidAmount: paidAmount,
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
    let paidAmount: Int          // 当月に既に支払い済みの合計
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
