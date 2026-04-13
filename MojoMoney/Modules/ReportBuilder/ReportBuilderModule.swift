import SwiftUI

final class ReportBuilderModule: MOJOModule {
    let id          = "report-builder"
    let displayName = "Report Builder"
    let icon        = "doc.richtext.fill"
    let accentColor = Color(hex: "10B981")
    let isEnabled   = false
    let statusSummary = "Custom PDF financial reports."

    func makeContentView() -> AnyView {
        AnyView(
            EmptyStateView(
                icon: "doc.richtext.fill",
                title: "Report Builder",
                message: "Generate custom PDF financial reports from your Monarch data. Coming soon!"
            )
            .background(Color.mojoNavy.ignoresSafeArea())
        )
    }

    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
