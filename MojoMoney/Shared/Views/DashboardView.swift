import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MOJOSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOJO Money")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Monarch, on autopilot.")
                        .font(.subheadline)
                        .foregroundColor(.mojoTextSecondary)
                }
                .padding(.horizontal, MOJOSpacing.lg)
                .padding(.top, MOJOSpacing.lg)

                // Module grid
                LazyVGrid(columns: columns, spacing: MOJOSpacing.md) {
                    ForEach(appState.moduleRegistry.modules, id: \.id) { mod in
                        ModuleCard(module: mod)
                            .environmentObject(appState)
                    }
                }
                .padding(.horizontal, MOJOSpacing.lg)

                // Monarch status bar
                MonarchStatusBar()
                    .environmentObject(appState)
                    .padding(.horizontal, MOJOSpacing.lg)
                    .padding(.bottom, MOJOSpacing.lg)
            }
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Module Card

struct ModuleCard: View {
    let module: any MOJOModule
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: module.icon)
                    .font(.title2)
                    .foregroundColor(module.isEnabled ? module.accentColor : .mojoTextSecondary)
                Spacer()
                if !module.isEnabled {
                    StatusBadge(status: .comingSoon, label: "Soon")
                }
            }

            Text(module.displayName)
                .font(.headline)
                .fontWeight(.semibold)

            Text(module.statusSummary)
                .font(.caption)
                .foregroundColor(.mojoTextSecondary)
                .lineLimit(2)

            Spacer()

            MOJOButton(
                title: module.isEnabled ? "Open →" : "Coming Soon",
                style: module.isEnabled ? .primary : .ghost
            ) {}
            .disabled(!module.isEnabled)
        }
        .padding(MOJOSpacing.md)
        .frame(minHeight: 160)
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.lg)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: MOJORadius.lg)
                .strokeBorder(
                    module.isEnabled ? module.accentColor.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Monarch Status Bar

struct MonarchStatusBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monarch Connection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let lastSync = appState.lastSyncDate {
                    Text("Last sync: \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.mojoTextSecondary)
                } else {
                    Text("Never synced")
                        .font(.caption)
                        .foregroundColor(.mojoTextSecondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.isMonarchConnected ? Color.mojoSuccess : Color.mojoDestructive)
                    .frame(width: 8, height: 8)
                Text(appState.isMonarchConnected ? "Connected" : "Disconnected")
                    .font(.subheadline)
                    .foregroundColor(appState.isMonarchConnected ? .mojoSuccess : .mojoDestructive)
            }
        }
        .padding(MOJOSpacing.md)
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.lg)
    }
}
