import SwiftUI

enum MOJOButtonStyle {
    case primary
    case secondary
    case destructive
    case ghost
}

struct MOJOButton: View {
    let title: String
    var style: MOJOButtonStyle = .primary
    var isLoading: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(foregroundColor)
                } else if let icon = systemImage {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(MOJORadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: MOJORadius.sm)
                    .strokeBorder(borderColor, lineWidth: style == .secondary || style == .ghost ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .mojoTeal
        case .destructive: return .white
        case .ghost:       return .mojoTextSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return .mojoTeal
        case .secondary:   return .clear
        case .destructive: return .mojoDestructive
        case .ghost:       return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary: return .mojoTeal
        case .ghost:     return .mojoTextSecondary.opacity(0.4)
        default:         return .clear
        }
    }
}
