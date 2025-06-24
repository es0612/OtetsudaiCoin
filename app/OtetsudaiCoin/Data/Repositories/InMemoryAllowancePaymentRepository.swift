import Foundation

final class InMemoryAllowancePaymentRepository: AllowancePaymentRepository, @unchecked Sendable {
    static let shared = InMemoryAllowancePaymentRepository()
    
    private var payments: [AllowancePayment] = []
    private let queue = DispatchQueue(label: "allowance-payment-repo", attributes: .concurrent)
    private let userDefaults = UserDefaults.standard
    private let storageKey = "allowance_payments"
    
    private init() {
        loadFromStorage()
    }
    
    func save(_ payment: AllowancePayment) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if let index = self.payments.firstIndex(where: { $0.id == payment.id }) {
                    self.payments[index] = payment
                } else {
                    self.payments.append(payment)
                }
                self.saveToStorage()
                continuation.resume()
            }
        }
    }
    
    func findById(_ id: UUID) async throws -> AllowancePayment? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let payment = self.payments.first { $0.id == id }
                continuation.resume(returning: payment)
            }
        }
    }
    
    func findAll() async throws -> [AllowancePayment] {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Array(self.payments))
            }
        }
    }
    
    func findByChildId(_ childId: UUID) async throws -> [AllowancePayment] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let childPayments = self.payments.filter { $0.childId == childId }
                    .sorted { $0.paidAt > $1.paidAt }
                continuation.resume(returning: childPayments)
            }
        }
    }
    
    func findByChildIdAndMonth(_ childId: UUID, month: Int, year: Int) async throws -> AllowancePayment? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let payment = self.payments.first { payment in
                    payment.childId == childId && payment.month == month && payment.year == year
                }
                continuation.resume(returning: payment)
            }
        }
    }
    
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [AllowancePayment] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let paymentsInRange = self.payments.filter { payment in
                    payment.paidAt >= startDate && payment.paidAt <= endDate
                }.sorted { $0.paidAt > $1.paidAt }
                continuation.resume(returning: paymentsInRange)
            }
        }
    }
    
    func delete(_ id: UUID) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.payments.removeAll { $0.id == id }
                self.saveToStorage()
                continuation.resume()
            }
        }
    }
    
    func update(_ payment: AllowancePayment) async throws {
        try await save(payment)
    }
    
    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(payments)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save allowance payments: \(error)")
        }
    }
    
    private func loadFromStorage() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            payments = try JSONDecoder().decode([AllowancePayment].self, from: data)
        } catch {
            print("Failed to load allowance payments: \(error)")
            payments = []
        }
    }
}