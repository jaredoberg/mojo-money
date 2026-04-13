import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Get Started"

    var body: some View {
        VStack(spacing: MOJOSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.mojoTextSecondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.mojoTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let action {
                MOJOButton(title: actionLabel, style: .primary, action: action)
                    .padding(.top, MOJOSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MOJOSpacing.xl)
    }
}
