import CryptoKit
import Foundation
import Observation

/// One local user profile. Data lives in its own encrypted file; the optional PIN is an access gate
/// (stored as a salted hash, never plaintext). No server, no account — all on-device (invariant #1).
public struct ProfileInfo: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var dataFile: String
    public var pinSalt: String?
    public var pinHash: String?

    public var hasPIN: Bool {
        pinHash != nil
    }
}

struct ProfileRegistry: Codable {
    var profiles: [ProfileInfo]
    var lastActiveID: UUID?
}

/// Persistence boundary for the profile registry (injectable so tests avoid Keychain/disk).
protocol RegistryPersistence: Sendable {
    func loadRegistry() -> ProfileRegistry?
    func saveRegistry(_ registry: ProfileRegistry)
}

extension SecureStore: RegistryPersistence {
    func loadRegistry() -> ProfileRegistry? {
        loadCodable(ProfileRegistry.self)
    }

    func saveRegistry(_ registry: ProfileRegistry) {
        saveCodable(registry)
    }
}

enum PINCrypto {
    /// Salted SHA-256 of the PIN. The PIN gates access; data-at-rest is encrypted by the device key.
    static func hash(_ pin: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func newSalt() -> String {
        UUID().uuidString
    }
}

/// Manages local profiles and the active profile's `CycleStore`. Switching profiles is
/// non-destructive — each profile reads its own encrypted file.
@MainActor
@Observable
public final class ProfileStore {
    public private(set) var profiles: [ProfileInfo]
    public private(set) var activeID: UUID?
    /// The active profile's store, or nil while gated (awaiting profile pick / PIN).
    public private(set) var current: CycleStore?

    private let registryStore: RegistryPersistence
    private let makeStore: (ProfileInfo) -> CycleStore

    /// Production: encrypted registry + per-profile encrypted stores.
    public convenience init(makeStore: @escaping (ProfileInfo) -> CycleStore = { info in
        CycleStore(persistence: SecureStore(fileName: info.dataFile))
    }) {
        self.init(registryStore: SecureStore(fileName: "velia-registry.enc"), makeStore: makeStore)
    }

    /// Designated init — `registryStore` is injectable so tests avoid Keychain/disk.
    init(
        registryStore: RegistryPersistence,
        makeStore: @escaping (ProfileInfo) -> CycleStore
    ) {
        self.registryStore = registryStore
        self.makeStore = makeStore
        var registry = registryStore.loadRegistry()
            ?? ProfileRegistry(profiles: [], lastActiveID: nil)

        // First run: seed a default profile that inherits the legacy single-profile data file.
        if registry.profiles.isEmpty {
            let def = ProfileInfo(
                id: UUID(),
                name: "",
                dataFile: "velia-state.enc",
                pinSalt: nil,
                pinHash: nil
            )
            registry.profiles = [def]
            registry.lastActiveID = def.id
        }
        profiles = registry.profiles
        persist()

        // Auto-enter when there's a single PIN-less profile (app opens with no gate).
        if profiles.count == 1, !profiles[0].hasPIN {
            enterUnlocked(profiles[0].id)
        }
    }

    public var needsGate: Bool {
        current == nil
    }

    public func profile(_ id: UUID) -> ProfileInfo? {
        profiles.first { $0.id == id }
    }

    /// Display name with a localized fallback for the unnamed default profile.
    public func displayName(_ info: ProfileInfo) -> String {
        info.name.isEmpty ? L2("Của tôi", "Mine") : info.name
    }

    // MARK: Entering / leaving

    /// Enter a profile. Returns false if a PIN is required and wrong.
    @discardableResult
    public func enter(_ id: UUID, pin: String?) -> Bool {
        guard let info = profile(id) else { return false }
        if info.hasPIN {
            guard let pin, let salt = info.pinSalt,
                  PINCrypto.hash(pin, salt: salt) == info.pinHash else { return false }
        }
        enterUnlocked(id)
        return true
    }

    private func enterUnlocked(_ id: UUID) {
        guard let info = profile(id) else { return }
        activeID = id
        current = makeStore(info)
        setLastActive(id)
    }

    /// Return to the gate (switch-profile / sign-out of the current profile).
    public func lockToGate() {
        current = nil
        activeID = nil
    }

    // MARK: Management

    @discardableResult
    public func createProfile(name: String, pin: String?) -> ProfileInfo {
        var info = ProfileInfo(
            id: UUID(),
            name: name,
            dataFile: "velia-state-\(UUID().uuidString).enc",
            pinSalt: nil,
            pinHash: nil
        )
        if let pin, !pin.isEmpty { applyPIN(pin, to: &info) }
        profiles.append(info)
        persist()
        return info
    }

    public func rename(_ id: UUID, to name: String) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[i].name = name
        persist()
    }

    public func setPIN(_ pin: String?, for id: UUID) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        if let pin, !pin.isEmpty {
            applyPIN(pin, to: &profiles[i])
        } else {
            profiles[i].pinSalt = nil
            profiles[i].pinHash = nil
        }
        persist()
    }

    public func deleteProfile(_ id: UUID) {
        guard profiles.count > 1, let info = profile(id) else { return } // never delete the last one
        SecureStore(fileName: info.dataFile).deleteFile()
        profiles.removeAll { $0.id == id }
        if activeID == id { lockToGate() }
        persist()
    }

    public func verifyPIN(_ pin: String, for id: UUID) -> Bool {
        guard let info = profile(id), let salt = info.pinSalt, let hash = info.pinHash else { return false }
        return PINCrypto.hash(pin, salt: salt) == hash
    }

    // MARK: Internals

    private func applyPIN(_ pin: String, to info: inout ProfileInfo) {
        let salt = PINCrypto.newSalt()
        info.pinSalt = salt
        info.pinHash = PINCrypto.hash(pin, salt: salt)
    }

    private func setLastActive(_ id: UUID) {
        registryStore.saveRegistry(ProfileRegistry(profiles: profiles, lastActiveID: id))
    }

    private func persist() {
        registryStore.saveRegistry(ProfileRegistry(profiles: profiles, lastActiveID: activeID))
    }
}
