import SwiftUI
import VeliaFeatures

@main
struct VeliaApp: App {
    var body: some Scene {
        WindowGroup {
            // Local profiles, each with its own encrypted on-device store. No account, no network.
            RootView()
        }
    }
}
