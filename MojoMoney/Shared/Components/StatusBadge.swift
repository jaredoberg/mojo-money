import SwiftUI

enum BadgeStatus {
    case success, warning, error, info, comingSoon

    var color: Color {
        switch self {
        case .success:    return .mojoSuccess
        case .warning:    return .mojoWarning
        case .error:      return .mojoDestructive
        case .info:       return .mojoTeal
        case .comingSoon: return .mojoTextSecondary
        }
    }

    var icon: String {
        switch self {
        case .success:    return "checkmark.circle.fill"
        case .warning:    return "exclamationmark.triangle.fill"
        case .error:      return "xmark.circle.fill"
        case .info:       return "info.circle.fill"
        case .comingSoon: return "clock.fill"
        }
    }
}

struct StatusBadge: View {
    let status: BadgeStatus
    var label: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            if let label {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(MOJORadius.sm)
    }
}
