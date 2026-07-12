import Foundation
import os.log

/// 支払い履歴の UserDefaults → Core Data one-shot 移行サービス (Issue #142)。
///
/// 旧 `InMemoryAllowancePaymentRepository` は支払い履歴を UserDefaults の
/// `allowance_payments` キーへ JSON シリアライズして永続化していた。
/// Core Data 移行後の初回起動で旧データを 1 回だけ読み出して Core Data へ移し替える。
///
/// 設計方針:
/// - 移行済みフラグ (`allowance_payments_migrated_to_coredata`) は**移行成功時のみ**立てる。
///   decode 失敗 / save 失敗時はフラグを立てず、次回起動で再試行する
///   (save は id 一致の upsert のため部分成功後の再試行でも重複しない)。
/// - 旧 UserDefaults キーはロールバック安全のため削除せず残置する。
/// - 呼び出し側 (`ContentView.setupInitialData()`) は
///   `PersistenceController.shared.storeLoadError == nil` を確認してから実行する
///   (store 未ロードで走ると移行が空振りするため)。
final class AllowancePaymentMigrationService {
    static let legacyStorageKey = "allowance_payments"
    static let migrationCompletedKey = "allowance_payments_migrated_to_coredata"

    private static let logger = Logger(subsystem: "com.asapapalab.OtetsudaiCoin", category: "Migration")

    private let repository: AllowancePaymentRepository
    private let userDefaults: UserDefaults

    init(repository: AllowancePaymentRepository, userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults
    }

    /// 未移行なら旧 UserDefaults の支払い履歴を Core Data へ移行する（起動時 1 回経路から呼ぶ）。
    func migrateIfNeeded() async {
        guard !userDefaults.bool(forKey: Self.migrationCompletedKey) else { return }

        guard let data = userDefaults.data(forKey: Self.legacyStorageKey) else {
            // 旧データなし (新規ユーザー等) → 移行対象がないのでフラグのみ立てて完了
            userDefaults.set(true, forKey: Self.migrationCompletedKey)
            return
        }

        do {
            let payments = try JSONDecoder().decode([AllowancePayment].self, from: data)
            for payment in payments {
                try await repository.save(payment)
            }
            userDefaults.set(true, forKey: Self.migrationCompletedKey)
            Self.logger.info("支払い履歴 \(payments.count) 件を UserDefaults から Core Data へ移行しました")
        } catch {
            // 破損 JSON / 保存失敗 → クラッシュさせずフラグも立てない (次回起動で再試行)
            Self.logger.error("支払い履歴の Core Data 移行に失敗しました: \(error.localizedDescription)")
        }
    }
}
