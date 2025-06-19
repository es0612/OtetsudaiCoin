import Foundation
@testable import OtetsudaiCoin

class MockChildRepository: ChildRepository {
    var children: [Child] = []
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
    
    // テスト用プロパティ
    var savedChildren: [Child] = []
    var updatedChildren: [Child] = []
    var deletedChildIds: [UUID] = []
    
    func save(_ child: Child) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        savedChildren.append(child)
        
        // 既存の子供を更新するか、新しく追加
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        } else {
            children.append(child)
        }
    }
    
    func findById(_ id: UUID) async throws -> Child? {
        if shouldThrowError {
            throw errorToThrow
        }
        return children.first { $0.id == id }
    }
    
    func findAll() async throws -> [Child] {
        if shouldThrowError {
            throw errorToThrow
        }
        return children
    }
    
    func delete(_ id: UUID) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        deletedChildIds.append(id)
        children.removeAll { $0.id == id }
    }
    
    func update(_ child: Child) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        updatedChildren.append(child)
        
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        }
    }
}

class MockHelpTaskRepository: HelpTaskRepository {
    var tasks: [HelpTask] = []
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
    
    func save(_ task: HelpTask) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        tasks.append(task)
    }
    
    func findById(_ id: UUID) async throws -> HelpTask? {
        if shouldThrowError {
            throw errorToThrow
        }
        return tasks.first { $0.id == id }
    }
    
    func findAll() async throws -> [HelpTask] {
        if shouldThrowError {
            throw errorToThrow
        }
        return tasks
    }
    
    func findActive() async throws -> [HelpTask] {
        if shouldThrowError {
            throw errorToThrow
        }
        return tasks.filter { $0.isActive }
    }
    
    func delete(_ id: UUID) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        tasks.removeAll { $0.id == id }
    }
    
    func update(_ task: HelpTask) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
}

class MockHelpRecordRepository: HelpRecordRepository {
    var records: [HelpRecord] = []
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
    
    func save(_ record: HelpRecord) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        records.append(record)
    }
    
    func findById(_ id: UUID) async throws -> HelpRecord? {
        if shouldThrowError {
            throw errorToThrow
        }
        return records.first { $0.id == id }
    }
    
    func findAll() async throws -> [HelpRecord] {
        if shouldThrowError {
            throw errorToThrow
        }
        return records
    }
    
    func findByChildId(_ childId: UUID) async throws -> [HelpRecord] {
        if shouldThrowError {
            throw errorToThrow
        }
        return records.filter { $0.childId == childId }
    }
    
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [HelpRecord] {
        if shouldThrowError {
            throw errorToThrow
        }
        return records.filter { $0.recordedAt >= startDate && $0.recordedAt <= endDate }
    }
    
    func findByChildIdInCurrentMonth(_ childId: UUID) async throws -> [HelpRecord] {
        if shouldThrowError {
            throw errorToThrow
        }
        let filteredRecords = records.filter { $0.childId == childId }
        return filteredRecords.filter { $0.isInCurrentMonth() }
    }
    
    func delete(_ id: UUID) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        records.removeAll { $0.id == id }
    }
    
    func update(_ record: HelpRecord) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        }
    }
}

class MockAllowancePaymentRepository: AllowancePaymentRepository {
    var payments: [AllowancePayment] = []
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
    
    func save(_ payment: AllowancePayment) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        payments.append(payment)
    }
    
    func findById(_ id: UUID) async throws -> AllowancePayment? {
        if shouldThrowError {
            throw errorToThrow
        }
        return payments.first { $0.id == id }
    }
    
    func findByChildIdAndMonth(_ childId: UUID, month: Int, year: Int) async throws -> AllowancePayment? {
        if shouldThrowError {
            throw errorToThrow
        }
        return payments.first { $0.childId == childId && $0.month == month && $0.year == year }
    }
    
    func findByChildId(_ childId: UUID) async throws -> [AllowancePayment] {
        if shouldThrowError {
            throw errorToThrow
        }
        return payments.filter { $0.childId == childId }
    }
    
    func findAll() async throws -> [AllowancePayment] {
        if shouldThrowError {
            throw errorToThrow
        }
        return payments
    }
    
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [AllowancePayment] {
        if shouldThrowError {
            throw errorToThrow
        }
        return payments.filter { $0.paidAt >= startDate && $0.paidAt <= endDate }
    }
    
    func delete(_ id: UUID) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        payments.removeAll { $0.id == id }
    }
    
    func update(_ payment: AllowancePayment) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index] = payment
        }
    }
}

class MockSoundService: SoundServiceProtocol {
    var coinEarnSoundPlayed = false
    var taskCompleteSoundPlayed = false
    var errorSoundPlayed = false
    var isMuted: Bool = false
    var volume: Float = 1.0
    var shouldThrowError = false
    
    // テスト用のプロパティ
    var playCoinEarnSoundCalled = false
    var playTaskCompleteSoundCalled = false
    var playErrorSoundCalled = false
    
    func playCoinEarnSound() throws {
        playCoinEarnSoundCalled = true
        coinEarnSoundPlayed = true
        if shouldThrowError {
            throw NSError(domain: "SoundError", code: 1, userInfo: nil)
        }
    }
    
    func playTaskCompleteSound() throws {
        playTaskCompleteSoundCalled = true
        taskCompleteSoundPlayed = true
        if shouldThrowError {
            throw NSError(domain: "SoundError", code: 1, userInfo: nil)
        }
    }
    
    func playErrorSound() throws {
        playErrorSoundCalled = true
        errorSoundPlayed = true
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
    }
    
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
    }
    
    func soundFileExists(_ soundType: SoundType) -> Bool {
        return true
    }
}