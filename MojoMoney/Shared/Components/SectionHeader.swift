import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.mojoTextSecondary)
                .tracking(1.2)
            Spacer()
            trailing
        }
        .padding(.top, MOJOSpacing.sm)
        .padding(.bottom, MOJOSpacing.xs)
    }
}
