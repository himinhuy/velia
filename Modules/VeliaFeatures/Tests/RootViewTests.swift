import VeliaCore
import XCTest
@testable import VeliaFeatures

@MainActor
final class RootViewTests: XCTestCase {
    func testRootViewInstantiates() {
        _ = RootView()
    }

    func testStoreSeedsPredictionFromOnboarding() {
        let store = CycleStore()
        XCTAssertNil(store.prediction, "No prediction before any period is known")

        store.completeOnboarding(
            profile: UserProfile(typicalCycleLength: 28, segment: .typical),
            lastPeriodStart: Date()
        )

        XCTAssertTrue(store.hasOnboarded)
        XCTAssertNotNil(store.prediction, "A single seeded period yields a (wide) prediction from the prior")
        XCTAssertEqual(store.periodDays.count, 1)
    }

    /// Contiguous logged days collapse into one run (one period); non-adjacent days form new cycles.
    func testContiguousDaysFormOneRun() throws {
        let store = CycleStore()
        let cal = Calendar.current
        let start = try XCTUnwrap(cal.date(byAdding: .day, value: -40, to: Date()))
        for offset in 0 ..< 5 {
            try store.setFlow(on: XCTUnwrap(cal.date(byAdding: .day, value: offset, to: start)), flow: .medium)
        }
        XCTAssertEqual(store.periodDays.count, 5)
        XCTAssertEqual(store.periodRuns().count, 1, "5 consecutive days = one period")
        XCTAssertEqual(store.loggedCycleCount, 0)
    }

    func testCycleCountAndAverageFromRuns() throws {
        let store = CycleStore()
        let cal = Calendar.current
        var day = try XCTUnwrap(cal.date(byAdding: .day, value: -90, to: Date()))
        for _ in 0 ..< 3 {
            store.setFlow(on: day, flow: .medium) // one-day run
            day = try XCTUnwrap(cal.date(byAdding: .day, value: 29, to: day))
        }
        XCTAssertEqual(store.periodRuns().count, 3)
        XCTAssertEqual(store.loggedCycleCount, 2, "3 runs ⇒ 2 complete cycles")
        XCTAssertEqual(store.averageCycleLength, 29)
        XCTAssertNotNil(store.prediction)
    }

    func testToggleFlowAndSymptom() {
        let store = CycleStore()
        let today = Date()
        store.setFlow(on: today, flow: .heavy)
        XCTAssertEqual(store.flow(on: today), .heavy)
        store.setFlow(on: today, flow: nil)
        XCTAssertFalse(store.isPeriodDay(on: today))

        store.toggleSymptom(TrackCatalog.feelingCategory, "happy", on: today)
        XCTAssertTrue(store.isSymptomSelected(TrackCatalog.feelingCategory, "happy", on: today))
        store.toggleSymptom(TrackCatalog.feelingCategory, "happy", on: today)
        XCTAssertFalse(store.isSymptomSelected(TrackCatalog.feelingCategory, "happy", on: today))
    }

    func testUpdateProfile() {
        let store = CycleStore()
        store.updateProfile(typicalCycleLength: 31, segment: .pcos, birthYear: 1990, periodLength: 6)
        XCTAssertEqual(store.profile.typicalCycleLength, 31)
        XCTAssertEqual(store.profile.segment, .pcos)
        XCTAssertEqual(store.profile.birthYear, 1990)
        XCTAssertEqual(store.typicalPeriodLength, 6)
    }

    /// The re-onboarding bug: state must survive a fresh store backed by the same persistence.
    func testPersistenceRoundTripSurvivesRelaunch() {
        let mock = MockPersistence()
        let store1 = CycleStore(persistence: mock)
        store1.completeOnboarding(
            mode: .conceive,
            profile: UserProfile(typicalCycleLength: 30, segment: .pcos),
            lastPeriodStart: Date(),
            periodLength: 4
        )
        store1.toggleSymptom(TrackCatalog.feelingCategory, "happy", on: Date())
        store1.setFertility(on: Date(), bbtCelsius: 36.6, cervicalMucus: "eggwhite", lhTest: "peak")

        // Simulate relaunch: brand-new store reading the same persistence.
        let store2 = CycleStore(persistence: mock)
        XCTAssertTrue(store2.hasOnboarded, "Onboarding must not reappear after relaunch")
        XCTAssertEqual(store2.mode, .conceive)
        XCTAssertEqual(store2.profile.typicalCycleLength, 30)
        XCTAssertEqual(store2.typicalPeriodLength, 4)
        XCTAssertEqual(store2.periodDays.count, store1.periodDays.count)
        XCTAssertTrue(store2.isSymptomSelected(TrackCatalog.feelingCategory, "happy", on: Date()))
        XCTAssertEqual(store2.fertilityEntry(on: Date())?.cervicalMucus, "eggwhite")
    }

    func testTrackWithoutPeriodSuppressesPrediction() throws {
        let store = CycleStore()
        try store.addPeriod(start: XCTUnwrap(Calendar.current.date(byAdding: .day, value: -10, to: Date())))
        store.setMode(.period)
        XCTAssertNotNil(store.prediction, "Period mode forecasts a cycle")
        store.setMode(.noPeriod)
        XCTAssertNil(store.prediction, "Track-without-period must not fake a forecast")
    }

    func testExclusiveSymptomAndNote() {
        let store = CycleStore()
        let day = Date()
        store.selectExclusiveSymptom(TrackCatalog.energyCategory, "high", on: day)
        XCTAssertTrue(store.isSymptomSelected(TrackCatalog.energyCategory, "high", on: day))
        // Choosing another clears the first (single-choice).
        store.selectExclusiveSymptom(TrackCatalog.energyCategory, "low", on: day)
        XCTAssertFalse(store.isSymptomSelected(TrackCatalog.energyCategory, "high", on: day))
        XCTAssertTrue(store.isSymptomSelected(TrackCatalog.energyCategory, "low", on: day))
        // Re-tapping the selected one clears it.
        store.selectExclusiveSymptom(TrackCatalog.energyCategory, "low", on: day)
        XCTAssertFalse(store.isSymptomSelected(TrackCatalog.energyCategory, "low", on: day))

        store.setNote("nhức đầu nhẹ", on: day)
        XCTAssertEqual(store.note(on: day), "nhức đầu nhẹ")
        store.setNote("   ", on: day)
        XCTAssertEqual(store.note(on: day), "", "Blank note is cleared")
    }

    func testLockLogic() {
        let lock = LockManager()
        lock.isEnabled = true
        XCTAssertTrue(lock.isLocked, "Enabled + not-yet-unlocked ⇒ locked")
        lock.isEnabled = false
        XCTAssertFalse(lock.isLocked, "Disabled ⇒ never locked")
    }

    func testLockedModeIsRejected() {
        let store = CycleStore()
        store.setMode(.pregnancy)
        XCTAssertEqual(store.mode, .period, "Locked modes are not selectable")
        XCTAssertFalse(TrackingMode.pregnancy.isFunctional)
        XCTAssertFalse(TrackingMode.perimenopause.isFunctional)
        XCTAssertTrue(TrackingMode.conceive.isFunctional)
    }
}

/// In-memory persistence double (no Keychain/disk) for tests.
private final class MockPersistence: CyclePersistence, @unchecked Sendable {
    private var state: PersistedState?
    func load() -> PersistedState? {
        state
    }

    func save(_ state: PersistedState) {
        self.state = state
    }
}

/// In-memory auth store double.
private final class MockAuthStore: AuthStore, @unchecked Sendable {
    private var state: AuthState?
    func loadAuth() -> AuthState? {
        state
    }

    func saveAuth(_ state: AuthState) {
        self.state = state
    }
}

@MainActor
final class AuthTests: XCTestCase {
    private func fresh() -> AuthManager {
        AuthManager(store: MockAuthStore())
    }

    /// nil = success, otherwise the error (works around Result<Void, _> not being Equatable).
    private func err(_ r: Result<Void, AuthError>) -> AuthError? {
        if case let .failure(e) = r { return e }; return nil
    }

    func testSignUpThenSessionPersists() {
        let store = MockAuthStore()
        let a = AuthManager(store: store)
        XCTAssertFalse(a.isAuthenticated)
        XCTAssertNil(err(a.signUp(email: "Me@Velia.app", password: "secret1")))
        XCTAssertTrue(a.isAuthenticated)
        XCTAssertEqual(a.currentEmail, "me@velia.app", "Email is normalized")

        // New manager on the same store resumes the session.
        let b = AuthManager(store: store)
        XCTAssertTrue(b.isAuthenticated)
    }

    func testLoginWrongAndRight() {
        let a = fresh()
        a.signUp(email: "u@v.app", password: "secret1")
        a.logOut()
        XCTAssertFalse(a.isAuthenticated)
        XCTAssertEqual(err(a.logIn(email: "u@v.app", password: "wrong")), .wrongPassword)
        XCTAssertEqual(err(a.logIn(email: "nope@v.app", password: "secret1")), .noAccount)
        XCTAssertNil(err(a.logIn(email: "u@v.app", password: "secret1")))
        XCTAssertTrue(a.isAuthenticated)
    }

    func testValidationAndDuplicate() {
        let a = fresh()
        XCTAssertEqual(err(a.signUp(email: "bad", password: "secret1")), .invalidEmail)
        XCTAssertEqual(err(a.signUp(email: "u@v.app", password: "123")), .weakPassword)
        XCTAssertNil(err(a.signUp(email: "u@v.app", password: "secret1")))
        XCTAssertEqual(err(a.signUp(email: "u@v.app", password: "another1")), .emailTaken)
    }

    func testPasswordIsHashedNotStored() throws {
        let store = MockAuthStore()
        let a = AuthManager(store: store)
        a.signUp(email: "u@v.app", password: "secret1")
        let acct = try XCTUnwrap(store.loadAuth()?.accounts[0])
        XCTAssertFalse(acct.hash.isEmpty)
        XCTAssertNotEqual(acct.hash, Data("secret1".utf8), "Stored value is a hash, not the password")
        XCTAssertEqual(acct.hash, AuthManager.pbkdf2("secret1", salt: acct.salt, rounds: acct.rounds))
    }

    func testDeleteAccount() {
        let a = fresh()
        a.signUp(email: "u@v.app", password: "secret1")
        XCTAssertTrue(a.isAuthenticated)
        a.deleteCurrentAccount()
        XCTAssertFalse(a.isAuthenticated, "Deleting the account signs out")
        // The credential is gone — logging in again fails.
        XCTAssertEqual(err(a.logIn(email: "u@v.app", password: "secret1")), .noAccount)
    }

    func testResetPassword() {
        let a = fresh()
        a.signUp(email: "u@v.app", password: "secret1")
        a.logOut()
        a.resetPassword(email: "u@v.app", newPassword: "newpass1")
        XCTAssertEqual(err(a.logIn(email: "u@v.app", password: "secret1")), .wrongPassword)
        XCTAssertNil(err(a.logIn(email: "u@v.app", password: "newpass1")))
    }
}

@MainActor
final class SubscriptionTests: XCTestCase {
    private func fresh() -> SubscriptionManager {
        SubscriptionManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testTrialThenExpiryGatesApp() {
        let sub = fresh()
        XCTAssertTrue(sub.hasAccess, "Fresh install is in the free trial")
        XCTAssertFalse(sub.needsPaywall)
        if case let .trial(days) = sub.status { XCTAssertEqual(days, 7) } else { XCTFail("expected trial") }

        sub.expireTrialForTesting()
        XCTAssertFalse(sub.hasAccess)
        XCTAssertTrue(sub.needsPaywall, "Expired trial gates the app")
        XCTAssertEqual(sub.status, .expired)
    }

    func testSubscribeGrantsPremiumWithRenewal() {
        let sub = fresh()
        sub.expireTrialForTesting()
        sub.subscribe()
        XCTAssertTrue(sub.isSubscribed)
        XCTAssertFalse(sub.needsPaywall, "Subscribing restores access")
        XCTAssertNotNil(sub.renewalDate)
        if case .premium = sub.status {} else { XCTFail("expected premium") }
    }

    func testCancelDropsPremium() {
        let sub = fresh()
        sub.subscribe()
        sub.cancel()
        XCTAssertFalse(sub.isSubscribed)
        XCTAssertNil(sub.renewalDate)
    }
}

/// In-memory registry double (no Keychain/disk).
private final class MockRegistry: RegistryPersistence, @unchecked Sendable {
    private var registry: ProfileRegistry?
    func loadRegistry() -> ProfileRegistry? {
        registry
    }

    func saveRegistry(_ registry: ProfileRegistry) {
        self.registry = registry
    }
}

@MainActor
final class ProfileStoreTests: XCTestCase {
    private func makeStore(stores: @escaping (ProfileInfo) -> CycleStore) -> ProfileStore {
        ProfileStore(registryStore: MockRegistry(), makeStore: stores)
    }

    /// Each profile gets its own store (data isolation); switching is non-destructive.
    func testProfileDataIsolation() {
        var stores: [String: MockPersistence] = [:]
        let ps = makeStore { info in
            let p = stores[info.dataFile] ?? MockPersistence()
            stores[info.dataFile] = p
            return CycleStore(persistence: p)
        }
        // First run seeds one default profile and auto-enters it.
        XCTAssertEqual(ps.profiles.count, 1)
        XCTAssertNotNil(ps.current)
        ps.current?.addPeriod(start: Date())

        // Add a second profile, switch to it: its store is empty (isolated).
        let second = ps.createProfile(name: "Em gái", pin: nil)
        XCTAssertTrue(ps.enter(second.id, pin: nil))
        XCTAssertEqual(ps.current?.periodDays.count, 0, "Second profile has its own empty data")
    }

    func testPINGate() {
        let ps = makeStore { _ in CycleStore() }
        let p = ps.createProfile(name: "Khóa", pin: "1234")
        XCTAssertTrue(ps.profile(p.id)?.hasPIN ?? false)
        XCTAssertFalse(ps.enter(p.id, pin: "0000"), "Wrong PIN is rejected")
        XCTAssertFalse(ps.enter(p.id, pin: nil), "Missing PIN is rejected")
        XCTAssertTrue(ps.enter(p.id, pin: "1234"), "Correct PIN unlocks")
        XCTAssertEqual(ps.activeID, p.id)
    }

    func testCannotDeleteLastProfile() {
        let ps = makeStore { _ in CycleStore() }
        let only = ps.profiles[0].id
        ps.deleteProfile(only)
        XCTAssertEqual(ps.profiles.count, 1, "The last profile can't be deleted")
    }
}
