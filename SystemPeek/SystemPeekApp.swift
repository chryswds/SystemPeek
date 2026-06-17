import SwiftUI

/// SystemPeek is a background ("accessory") menu-bar-style app: it has no Dock
/// icon and no standard window. All UI lives in a floating panel managed by
/// `AppDelegate`, so the SwiftUI `App` only needs to host the delegate and an
/// empty Settings scene to satisfy the `App` protocol.
@main
struct SystemPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
