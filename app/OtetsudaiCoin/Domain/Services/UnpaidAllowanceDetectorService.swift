import Foundation

class UnpaidAllowanceDetectorService {
    private let allowanceCalculator = AllowanceCalculator()
    
    func detectUnpaidPeriods(
        childId: UUID,
        helpRecords: [HelpRecord],
        payments: [AllowancePayment],
        tasks: [HelpTask]
    ) -> [UnpaidPeriod] {
        let calendar = Calendar.current
        let currentDate = Date()
        let currentComponents = calendar.dateComponents([.year, .month], from: currentDate)
        
        let recordsByMonth = groupRecordsByMonth(helpRecords)
        let paymentsByMonth = groupPaymentsByMonth(payments.filter { $0.childId == childId })
        
        var unpaidPeriods: [UnpaidPeriod] = []
        
        for (monthKey, monthRecords) in recordsByMonth {
            if monthKey.year == currentComponents.year && monthKey.month == currentComponents.month {
                continue
            }
            
            let expectedAmount = allowanceCalculator.calculateMonthlyAllowance(
                records: monthRecords,
                tasks: tasks
            )
            
            let totalPaid = paymentsByMonth[monthKey]?.reduce(0) { $0 + $1.amount } ?? 0
            let unpaidAmount = expectedAmount - totalPaid
            
            if unpaidAmount > 0 {
                let unpaidPeriod = UnpaidPeriod(
                    childId: childId,
                    month: monthKey.month,
                    year: monthKey.year,
                    expectedAmount: unpaidAmount
                )
                unpaidPeriods.append(unpaidPeriod)
            }
        }
        
        return unpaidPeriods.sorted { period1, period2 in
            if period1.year != period2.year {
                return period1.year > period2.year
            }
            return period1.month > period2.month
        }
    }
    
    private func groupRecordsByMonth(_ records: [HelpRecord]) -> [MonthKey: [HelpRecord]] {
        let calendar = Calendar.current
        return Dictionary(grouping: records) { record in
            let components = calendar.dateComponents([.year, .month], from: record.recordedAt)
            return MonthKey(year: components.year!, month: components.month!)
        }
    }
    
    private func groupPaymentsByMonth(_ payments: [AllowancePayment]) -> [MonthKey: [AllowancePayment]] {
        return Dictionary(grouping: payments) { payment in
            MonthKey(year: payment.year, month: payment.month)
        }
    }
}

private struct MonthKey: Hashable {
    let year: Int
    let month: Int
}