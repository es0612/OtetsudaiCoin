import SwiftUI

/// 月のまとめから開く「おまけを付ける」シート (#279)。
///
/// 1 画面で全部: スタンプ → おまけの額（チップ + 入力）→ 内訳 → 確定ボタン。
/// 確定ボタンは numberPad（return キーが無い）を出したままでも押せるよう、下端に固定する。
struct BonusPaymentSheet: View {
    let remainder: Int
    let onConfirm: (PaymentBonus) -> Void
    let onCancel: () -> Void

    @State private var draft = BonusDraft()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stampSection
                    amountSection
                    breakdownSection
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { confirmButton }
            .navigationTitle("おまけを付ける")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .accessibilityIdentifier("bonus_cancel_button")
                }
            }
        }
    }

    // MARK: - スタンプ

    private var stampColumns: [GridItem] {
        let count = BonusDraft.stampColumnCount(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var stampSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("スタンプを選ぶ")
                .appFont(.sectionHeader)
            LazyVGrid(columns: stampColumns, spacing: 12) {
                ForEach(BonusStamp.allCases) { stamp in
                    stampCard(stamp)
                }
            }
        }
    }

    private func stampCard(_ stamp: BonusStamp) -> some View {
        let isSelected = draft.stamp == stamp
        return Button {
            draft.stamp = stamp
        } label: {
            VStack(spacing: 6) {
                Text(stamp.emoji)
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(stamp.title)
                    .appFont(.captionText)
                    .fontWeight(.semibold)
                    .foregroundColor(AccessibilityColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.12) : AccessibilityColors.systemBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(isSelected ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AccessibilityColors.brandPrimary)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("bonus_stamp_\(stamp.rawValue)")
    }

    // MARK: - おまけの額

    private var amountBinding: Binding<String> {
        Binding(
            get: { draft.amountText },
            set: { draft.setAmountText($0) }
        )
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("おまけの額")
                .appFont(.sectionHeader)
            HStack(spacing: 8) {
                ForEach(BonusDraft.chipAmounts, id: \.self) { value in
                    Button {
                        draft.addChip(value)
                    } label: {
                        Text("+¥\(value)")
                            .appFont(.buttonText)
                            .foregroundColor(AccessibilityColors.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().stroke(AccessibilityColors.brandPrimary, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bonus_chip_\(value)")
                }
            }
            HStack(spacing: 4) {
                Text(verbatim: "¥")
                    .appFont(.primaryInfo)
                    .foregroundColor(AccessibilityColors.textSecondary)
                    .accessibilityHidden(true)
                TextField("おまけの額", text: amountBinding)
                    .keyboardType(.numberPad)
                    .appFont(.primaryInfo)
                    .accessibilityIdentifier("bonus_amount_field")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AccessibilityColors.systemBackgroundSecondary)
            )
        }
    }

    // MARK: - 内訳

    private var breakdownSection: some View {
        VStack(spacing: 8) {
            breakdownRow(label: "お小遣い", value: remainder)
            breakdownRow(label: "おまけ", value: draft.amount)
            Divider()
            breakdownRow(label: "渡す額", value: draft.total(remainder: remainder))
                .fontWeight(.bold)
        }
    }

    private func breakdownRow(label: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("¥\(value)")
        }
        .appFont(.primaryInfo)
        .foregroundColor(AccessibilityColors.textPrimary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 確定

    private var confirmButton: some View {
        Button {
            if let bonus = draft.bonus {
                onConfirm(bonus)
            }
        } label: {
            Text("おまけを付けて支払う ¥\(draft.total(remainder: remainder))")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .primaryButton()
        .disabled(draft.bonus == nil)
        .accessibilityIdentifier("bonus_confirm_button")
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
