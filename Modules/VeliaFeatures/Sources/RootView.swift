import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// App root. Hosts the main tab bar (Today / Calendar / Log) and gates first run behind onboarding.
/// State lives in a single `CycleStore` injected into the environment; predictions are computed
/// on-device by VeliaCore.
public struct RootView: View {
    @State private var store: CycleStore

    public init(store: CycleStore = CycleStore()) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        TabView {
            TodayView()
                .tabItem { Label(L.today, systemImage: "sun.max.fill") }
            CalendarView()
                .tabItem { Label(L.calendar, systemImage: "calendar") }
            LogView()
                .tabItem { Label(L.log, systemImage: "list.bullet") }
        }
        .tint(Theme.accent)
        .environment(store)
        .fullScreenCover(isPresented: Binding(
            get: { !store.hasOnboarded },
            set: { _ in }
        )) {
            OnboardingView(store: store)
        }
    }
}
