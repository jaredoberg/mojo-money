import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var showOnboarding: Bool
    @Published var lastSyncDate: Date? = nil

    let moduleRegistry   = ModuleRegistry()
    let monarchService   = MonarchService.shared
    let pythonBridge     = PythonBridge.shared

    var isMonarchConnected: Bool { monarchService.isConnected }

    init() {
        showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showOnboarding = false
    }
}
