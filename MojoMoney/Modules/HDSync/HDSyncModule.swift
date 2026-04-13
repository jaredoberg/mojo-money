import SwiftUI

final class HDSyncModule: MOJOModule {
    let id          = "hd-sync"
    let displayName = "HD Sync"
    let icon        = "bolt.fill"
    let accentColor = Color.mojoTeal
    let isEnabled   = true

    var statusSummary: String {
        let runs = DatabaseService.shared.fetchSyncRuns(module: "hd_sync")
        if runs.isEmpty { return "No syncs yet — import CSVs to get started." }
        let applied = runs.compactMap { $0["applied"] as? Int }.reduce(0, +)
        return "\(applied) transactions enriched"
    }

    func makeContentView() -> AnyView {
        AnyView(
            NavigationStack {
                HDSyncDashboard()
            }
        )
    }

    func makeSettingsView() -> AnyView {
        AnyView(HDSettingsView())
    }
}
