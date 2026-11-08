import Foundation

@MainActor
@Observable
class MonthlySummaryViewModel {

    // MARK: - State

    private(set) var selectedMonth: Date

    var snapshot: MonthSnapshot?

    var isLoading: Bool = false

    /// おまけ付きの支払いが保存できた直後の演出の対象 (#279)。View は non-nil の間だけ演出を重ねる。
    private(set) var celebratingBonus: PaymentBonus?

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

    /// 水平スワイプの translation 幅から月ナビを行う（View の DragGesture から呼ぶ）。
    /// iOS 慣習: 左スワイプ（width < 0）= 次の月へ進む / 右スワイプ（width > 0）= 前の月へ戻る。
    /// 月が移動したら true を返し、呼び出し側が loadMonth を kick する。
    @discardableResult
    func handleHorizontalSwipe(translationWidth: CGFloat) -> Bool {
        if translationWidth < -50 {
            goToNextMonth()
            return true
        } else if translationWidth > 50 {
            goToPreviousMonth()
            return true
        }
        return false
    }

    // MARK: - Payment

    /// 表示中の月の「未払い残額」を支払う。完済済みなら no-op。
    /// 既払いがある月（.partiallyPaid）は残額のみを新規 payment として保存する（全額二重払いを防ぐ）。
    /// 残額は新規の payment 行として保存するが、computePaymentStatus が当月の全 payment 行を
    /// 合算して判定するため、残額行を別途追加しても合計が totalCoins に達し .paid と判定される。
    /// 保存後 loadMonth で paidAmount / paymentStatus を再評価する。
    /// isLoading を in-flight ガードに用い、CTA の double-tap による二重 save（全額過払い）を防ぐ。
    ///
    /// #279: `bonus` を渡すと、同じ支払い行の `bonusAmount` / `bonusStampKey` に載せる（`amount` には混ぜない）。
    /// 保存できたときだけ `celebratingBonus` を立てる。引数なしの呼び出しは今までと同じ動き。
    func payCurrentMonth(bonus: PaymentBonus? = nil) async {
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
                note: "\(year)年\(month)月のお小遣い支払い",
                bonusAmount: bonus?.amount ?? 0,
                bonusStampKey: bonus?.stamp.rawValue
            )
            try await allowancePaymentRepository.save(payment)
            await loadMonth()   // paidAmount/paymentStatus を再評価（loadMonth が isLoading を管理）
            if let bonus {
                celebratingBonus = bonus
            }
        } catch {
            // 保存失敗時は snapshot を維持（paymentStatus は変わらない）
            DebugLogger.error("payCurrentMonth failed: \(error)")
        }
    }

    /// おまけの演出を閉じる (#279)。
    func dismissCelebration() {
        celebratingBonus = nil
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
            // #279: おまけは paidAmount / paymentStatus に混ぜず、一覧として別に持つ
            let bonuses = monthPayments
                .filter { $0.bonusAmount > 0 }
                .sorted { $0.paidAt < $1.paidAt }
                .map { MonthSnapshot.BonusEntry(stampKey: $0.bonusStampKey, amount: $0.bonusAmount, paidAt: $0.paidAt) }

            let paymentStatus = computePaymentStatus(
                payments: allPayments,
                year: year,
                month: month,
                expected: totalCoins
            )

            let monthLabel = Self.monthLabel(year: year, month: month, locale: Locale.current)

            self.snapshot = MonthSnapshot(
                monthLabel: monthLabel,
                totalCount: totalCount,
                totalCoins: totalCoins,
                paidAmount: paidAmount,
                taskBreakdown: breakdown,
                highlights: highlights,
                calendar: calendarDays,
                paymentStatus: paymentStatus,
                bonuses: bonuses
            )
        } catch {
            // #173: 以前はログすら残らず、ユーザーには空表示だけが見えて
            // 「記録が無い月」と「取得に失敗した月」を区別できなかった。
            // snapshot は破棄したまま（月ラベルと数字の取り違えを避ける）で、
            // 原因追跡の手掛かりだけ残す。
            DebugLogger.error("loadMonth failed: \(error)")
            self.snapshot = nil
        }
    }

    /// 表示用の月ラベルを locale に応じて生成する (#155 コメント報告の i18n 漏れ対応)。
    ///
    /// 旧実装は "\(year)年\(month)月" の日本語ハードコードで、en ロケールでも
    /// 日本語表記が出ていた。`yMMMM` テンプレートは ja で「2026年7月」(現行と同一)、
    /// en で「July 2026」になる。テスト可能にするため locale を引数に取る static helper とする。
    nonisolated static func monthLabel(year: Int, month: Int, locale: Locale) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            return "\(year)/\(month)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
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
        // M-2(#125): 獲得 0 の月は支払い対象なし → .paid 扱い（空月で ¥0 支払い CTA を出さない）。
        if expected <= 0 { return .paid }

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
    let bonuses: [BonusEntry]    // #279: 当月のおまけ（paidAt の古い順）。paidAmount には含めない

    /// 支払い 1 行ぶんのおまけ (#279)。保存されたスタンプのキーを表示用の値に変えるのはここだけ。
    /// View はこの型だけを読む。未知のキー（将来のスタンプや壊れた値）でも捨てず、🎁 / 「おまけ」で表示する。
    struct BonusEntry: Equatable {
        let stampKey: String?
        let amount: Int
        let paidAt: Date

        var stamp: BonusStamp? { stampKey.flatMap(BonusStamp.init(rawValue:)) }
        var emoji: String { stamp?.emoji ?? BonusStamp.fallbackEmoji }
        var title: String { stamp?.title ?? BonusStamp.fallbackTitle }
    }

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
