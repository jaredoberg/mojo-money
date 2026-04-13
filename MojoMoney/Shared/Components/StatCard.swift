import SwiftUI

struct StatCard: View {
    let value: String
    let label: String
    var valueColor: Color = .primary
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.mojoTextSecondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundColor(.mojoTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MOJOSpacing.md)
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.md)
    }
}
