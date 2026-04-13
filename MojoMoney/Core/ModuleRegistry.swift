import SwiftUI

class ModuleRegistry: ObservableObject {
    let modules: [any MOJOModule]

    init() {
        modules = [
            HDSyncModule(),
            LowesSyncModule(),
            EmailSyncModule(),
            ProjectTrackerModule(),
            ReportBuilderModule()
        ]
    }

    func module(withId id: String) -> (any MOJOModule)? {
        modules.first { $0.id == id }
    }
}
