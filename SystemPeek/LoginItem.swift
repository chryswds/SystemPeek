import Foundation
import ServiceManagement

/// Wraps SMAppService to register/unregister SystemPeek as a launch-at-login item.
@MainActor
final class LoginItem: ObservableObject {
    @Published var isEnabled = false

    init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SystemPeek: could not change launch-at-login: \(error.localizedDescription)")
        }
        refresh()
    }
}
