import SwiftUI

protocol MOJOModule: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }
    var accentColor: Color { get }
    var isEnabled: Bool { get }
    var statusSummary: String { get }

    func makeContentView() -> AnyView
    func makeSettingsView() -> AnyView
}
