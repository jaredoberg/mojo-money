import SwiftUI

@main
struct MojoMoneyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        Window("MOJO Money", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 780)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 560, height: 500)
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        #endif
    }
}
