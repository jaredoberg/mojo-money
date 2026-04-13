import SwiftUI

final class ProjectTrackerModule: MOJOModule {
    let id          = "project-tracker"
    let displayName = "Project Tracker"
    let icon        = "chart.bar.fill"
    let accentColor = Color(hex: "F59E0B")
    let isEnabled   = false
    let statusSummary = "Job costing across merchants."

    func makeContentView() -> AnyView {
        AnyView(
            EmptyStateView(
                icon: "chart.bar.fill",
                title: "Project Cost Tracker",
                message: "Track job costs across Home Depot, Lowe's, and other merchants. Coming soon!"
            )
            .background(Color.mojoNavy.ignoresSafeArea())
        )
    }

    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
