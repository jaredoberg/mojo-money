import SwiftUI

enum NavItem: Hashable {
    case dashboard
    case module(String)
    case settings
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: NavItem? = .dashboard

    var body: some View {
        Group {
            #if os(macOS)
            macContent
            #else
            iosContent
            #endif
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
                #if os(macOS)
                .frame(width: 560, height: 580)
                #endif
        }
    }

    // MARK: - macOS

    #if os(macOS)
    var macContent: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selectedItem: $selectedItem)
                .environmentObject(appState)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.mojoNavy)
        }
        .navigationSplitViewStyle(.balanced)
    }
    #endif

    // MARK: - iOS

    var iosContent: some View {
        TabView {
            NavigationStack {
                DashboardView()
                    .environmentObject(appState)
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            NavigationStack {
                if let hdModule = appState.moduleRegistry.module(withId: "hd-sync") {
                    hdModule.makeContentView()
                }
            }
            .tabItem { Label("HD Sync", systemImage: "bolt.fill") }

            NavigationStack {
                SettingsView()
                    .environmentObject(appState)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(.mojoTeal)
    }

    // MARK: - Detail router (macOS)

    @ViewBuilder
    var detailView: some View {
        switch selectedItem {
        case .dashboard, .none:
            DashboardView()
                .environmentObject(appState)
        case .module(let id):
            if let mod = appState.moduleRegistry.module(withId: id) {
                mod.makeContentView()
            } else {
                EmptyStateView(icon: "questionmark.circle", title: "Module Not Found", message: "")
            }
        case .settings:
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Sidebar (macOS)

#if os(macOS)
struct SidebarView: View {
    @Binding var selectedItem: NavItem?
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader()
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 4)

            List(selection: $selectedItem) {
                NavigationLink(value: NavItem.dashboard) {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

                Section {
                    ForEach(appState.moduleRegistry.modules, id: \.id) { mod in
                        ModuleSidebarRow(module: mod)
                            .tag(NavItem.module(mod.id))
                    }
                } header: {
                    Text("MODULES")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.mojoTextSecondary)
                        .tracking(1.5)
                }

                NavigationLink(value: NavItem.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color.mojoNavy.opacity(0.6))
    }
}

struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.mojoTeal)
                    .frame(width: 34, height: 34)
                Text("M⚡")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("MOJO Money")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Monarch, on autopilot.")
                    .font(.caption2)
                    .foregroundColor(.mojoTextSecondary)
            }
            Spacer()
        }
    }
}

struct ModuleSidebarRow: View {
    let module: any MOJOModule

    var body: some View {
        HStack {
            Image(systemName: module.icon)
                .foregroundColor(module.isEnabled ? module.accentColor : .mojoTextSecondary)
                .frame(width: 16)
            Text(module.displayName)
                .foregroundColor(module.isEnabled ? .primary : .mojoTextSecondary)
            Spacer()
            if !module.isEnabled {
                Text("Soon")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.mojoTextSecondary.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(.mojoTextSecondary)
            }
        }
        .contentShape(Rectangle())
    }
}
#endif
