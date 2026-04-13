import SwiftUI

final class EmailSyncModule: MOJOModule {
    let id          = "email-sync"
    let displayName = "Email Sync"
    let icon        = "envelope.fill"
    let accentColor = Color(hex: "8B5CF6")
    let isEnabled   = false
    let statusSummary = "Auto-match email receipts to Monarch transactions."

    func makeContentView() -> AnyView {
        AnyView(
            EmptyStateView(
                icon: "envelope.fill",
                title: "Email Receipt Sync",
                message: "Automatically match Gmail receipts to Monarch transactions. Coming soon!"
            )
            .background(Color.mojoNavy.ignoresSafeArea())
        )
    }

    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
