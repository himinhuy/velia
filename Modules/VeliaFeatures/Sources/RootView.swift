import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// App root. A custom bottom bar (Cycle / Calendar / Track＋ / Analysis / Content) with a prominent
/// center Track button (reference screenshot). State lives in one `CycleStore` injected into the
/// environment; predictions are computed on-device by VeliaCore.
public struct RootView: View {
    @State private var profiles: ProfileStore
    @State private var auth = AuthManager()
    @State private var lock = LockManager()
    @State private var lang = LanguageManager()
    @State private var reminders = ReminderManager()
    @State private var subscription = SubscriptionManager()
    @State private var tab: Tab = .cycle
    /// Non-nil while the Track sheet is open, holding the day being logged.
    @State private var trackDate: Date?
    @Environment(\.scenePhase) private var scenePhase

    public enum Tab: Hashable { case cycle, calendar, analysis, content }

    public init(profiles: ProfileStore = ProfileStore()) {
        _profiles = State(initialValue: profiles)
    }

    public var body: some View {
        ZStack {
            if !auth.isAuthenticated {
                AuthView() // must sign in / sign up first
            } else if subscription.needsPaywall {
                PaywallView() // hard gate after the 7-day trial expires
            } else if let store = profiles.current {
                mainContent(store)
            } else {
                ProfileGateView()
            }

            // App-switcher privacy cover: hide content whenever the scene isn't active.
            if scenePhase != .active, !lock.isLocked {
                Theme.screen.ignoresSafeArea()
                    .overlay(Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary))
            }
            // Biometric lock gate (opt-in) — only once signed in.
            if lock.isLocked, auth.isAuthenticated {
                LockScreenView(lock: lock)
                    .transition(.opacity)
            }
        }
        .environment(auth)
        .environment(lock)
        .environment(lang)
        .environment(profiles)
        .environment(reminders)
        .environment(subscription)
        .task(id: profiles.activeID) {
            if let store = profiles.current { await reminders.apply(store: store) }
        }
        .id(lang.language) // rebuild the tree so every L2(...) re-evaluates on language switch
        .task { await lock.authenticate() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await lock.authenticate() }
            case .background:
                lock.lock() // require auth on return
            default:
                break
            }
        }
    }

    private func mainContent(_ store: CycleStore) -> some View {
        ZStack(alignment: .bottom) {
            content(store)
                .environment(store)
            tabBar
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: Binding(get: { !store.hasOnboarded }, set: { _ in })) {
            OnboardingView(store: store)
        }
        .sheet(item: Binding(
            get: { trackDate.map { IdentifiableDate(date: $0) } },
            set: { trackDate = $0?.date }
        ), onDismiss: {
            Task { await reminders.apply(store: store) } // logging may have changed the prediction
        }, content: { wrapper in
            TrackSheet(store: store, selectedDate: wrapper.date)
        })
    }

    @ViewBuilder
    private func content(_: CycleStore) -> some View {
        switch tab {
        case .cycle: TodayView(trackDate: $trackDate)
        case .calendar: CalendarView(trackDate: $trackDate)
        case .analysis: AnalysisView()
        case .content: ContentTabView()
        }
    }

    // MARK: Custom tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.cycle, L2("Chu kỳ", "Cycle"), "circle.dashed")
            tabButton(.calendar, L2("Lịch", "Calendar"), "calendar")
            trackTab
            tabButton(.analysis, L2("Phân tích", "Analysis"), "chart.bar.doc.horizontal")
            tabButton(.content, L2("Nội dung", "Content"), "book")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func tabButton(_ t: Tab, _ label: String, _ symbol: String) -> some View {
        Button {
            tab = t
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(label).font(.system(size: 10))
            }
            .foregroundStyle(tab == t ? Theme.accent : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var trackTab: some View {
        Button {
            trackDate = Calendar.current.startOfDay(for: Date())
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 34)
                    .background(Theme.accent, in: Capsule())
                Text(L2("Theo dõi", "Track")).font(.system(size: 10)).foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Wrapper so a `Date` can drive a `.sheet(item:)`.
private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval {
        date.timeIntervalSince1970
    }
}
