import SwiftUI

/// Spud (Android Minik Amudu, com.appsbybros.minik.amudu): a standalone app with its own shell.
@main
struct AmuduApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
