import SwiftUI
import VeliaFeatures

@main
struct VeliaApp: App {
    var body: some Scene {
        WindowGroup {
            // Encrypted, on-device persistence so data + onboarding survive relaunch.
            RootView(store: CycleStore(persistence: SecureStore.shared))
        }
    }
}
