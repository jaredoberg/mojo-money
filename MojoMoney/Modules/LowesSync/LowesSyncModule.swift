import SwiftUI

final class LowesSyncModule: MOJOModule {
    let id          = "lowes-sync"
    let displayName = "Lowes Sync"
    let icon        = "hammer.fill"
    let accentColor = Color(hex: "0066CC")
    let isEnabled   = false
    let statusSummary = "Enrich Monarch transactions with Lowe's Pro purchase details."

    func makeContentView() -> AnyView {
        AnyView(
            EmptyStateView(
                icon: "hammer.fill",
                title: "Lowes Sync",
                message: "Enrich Monarch transactions with Lowe's Pro purchase history. Coming soon!"
            )
            .background(Color.mojoNavy.ignoresSafeArea())
        )
    }

    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
