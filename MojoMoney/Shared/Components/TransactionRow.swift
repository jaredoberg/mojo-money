import SwiftUI

struct TransactionRow: View {
    let merchant: String
    let date: String
    let amount: Double
    var category: String? = nil
    var statusBadge: BadgeStatus? = nil
    var statusLabel: String? = nil
    var isReturn: Bool = false

    var body: some View {
        HStack(spacing: MOJOSpacing.md) {
            // Merchant icon
            ZStack {
                Circle()
                    .fill(Color.mojoCard)
                    .frame(width: 40, height: 40)
                Text(String(merchant.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.mojoTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.mojoTextSecondary)
                    if let cat = category {
                        Text("·")
                            .foregroundColor(.mojoTextSecondary)
                        Text(cat)
                            .font(.caption)
                            .foregroundColor(.mojoTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(isReturn ? "+\(formattedAmount)" : "-\(formattedAmount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isReturn ? .mojoSuccess : .primary)

                if let status = statusBadge {
                    StatusBadge(status: status, label: statusLabel)
                }
            }
        }
        .padding(.vertical, MOJOSpacing.sm)
        .padding(.horizontal, MOJOSpacing.md)
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.md)
    }

    private var formattedAmount: String {
        String(format: "$%.2f", abs(amount))
    }
}
