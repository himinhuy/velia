import CommonCrypto
import Foundation
import Observation
import Security

/// One local account. The password is never stored — only a PBKDF2 hash + its salt.
struct AuthAccount: Codable, Equatable {
    var email: String
    var salt: Data
    var hash: Data
    var rounds: Int
}

/// Persisted auth state: the accounts + the currently signed-in email (session).
struct AuthState: Codable {
    var accounts: [AuthAccount]
    var session: String?
}

/// Persistence boundary (injectable so tests avoid Keychain/disk).
protocol AuthStore: Sendable {
    func loadAuth() -> AuthState?
    func saveAuth(_ state: AuthState)
}

extension SecureStore: AuthStore {
    func loadAuth() -> AuthState? {
        loadCodable(AuthState.self)
    }

    func saveAuth(_ state: AuthState) {
        saveCodable(state)
    }
}

public enum AuthError: Error, Equatable {
    case invalidEmail, weakPassword, emailTaken, noAccount, wrongPassword

    var message: String {
        switch self {
        case .invalidEmail: L2("Email không hợp lệ.", "Invalid email address.")
        case .weakPassword: L2("Mật khẩu cần ít nhất 6 ký tự.", "Password must be at least 6 characters.")
        case .emailTaken: L2("Email này đã được đăng ký.", "That email is already registered.")
        case .noAccount: L2("Không tìm thấy tài khoản với email này.", "No account found for that email.")
        case .wrongPassword: L2("Sai mật khẩu.", "Incorrect password.")
        }
    }
}

/// On-device email/password auth. **No server** — accounts live PBKDF2-hashed in the encrypted store
/// (invariant #1 intact). `signUp`/`logIn` are isolated so a real backend can replace them later.
@MainActor
@Observable
final class AuthManager {
    private(set) var currentEmail: String?

    private var accounts: [AuthAccount]
    private let store: AuthStore

    init(store: AuthStore = SecureStore(fileName: "velia-auth.enc")) {
        self.store = store
        let state = store.loadAuth() ?? AuthState(accounts: [], session: nil)
        accounts = state.accounts
        // Resume the session only if the account still exists.
        currentEmail = state.session.flatMap { email in
            state.accounts.contains { $0.email == email } ? email : nil
        }
    }

    var isAuthenticated: Bool {
        currentEmail != nil
    }

    // MARK: Actions

    @discardableResult
    func signUp(email rawEmail: String, password: String) -> Result<Void, AuthError> {
        let email = normalize(rawEmail)
        guard isValidEmail(email) else { return .failure(.invalidEmail) }
        guard password.count >= 6 else { return .failure(.weakPassword) }
        guard !accounts.contains(where: { $0.email == email }) else { return .failure(.emailTaken) }

        let salt = randomSalt()
        let rounds = 120_000
        let account = AuthAccount(
            email: email,
            salt: salt,
            hash: Self.pbkdf2(password, salt: salt, rounds: rounds),
            rounds: rounds
        )
        accounts.append(account)
        currentEmail = email // auto-login after sign up
        persist()
        return .success(())
    }

    @discardableResult
    func logIn(email rawEmail: String, password: String) -> Result<Void, AuthError> {
        let email = normalize(rawEmail)
        guard let account = accounts.first(where: { $0.email == email }) else { return .failure(.noAccount) }
        let attempt = Self.pbkdf2(password, salt: account.salt, rounds: account.rounds)
        guard constantTimeEqual(attempt, account.hash) else { return .failure(.wrongPassword) }
        currentEmail = email
        persist()
        return .success(())
    }

    func logOut() {
        currentEmail = nil
        persist()
    }

    /// Permanently delete the signed-in account (App Store Guideline 5.1.1(v)). Removes the local
    /// credential and ends the session. (Cycle data lives per-profile, independent of the account.)
    func deleteCurrentAccount() {
        guard let email = currentEmail else { return }
        accounts.removeAll { $0.email == email }
        currentEmail = nil
        persist()
    }

    /// Local password reset (no email service on-device). Sets a new password for an existing email.
    @discardableResult
    func resetPassword(email rawEmail: String, newPassword: String) -> Result<Void, AuthError> {
        let email = normalize(rawEmail)
        guard newPassword.count >= 6 else { return .failure(.weakPassword) }
        guard let idx = accounts.firstIndex(where: { $0.email == email }) else { return .failure(.noAccount) }
        let salt = randomSalt()
        accounts[idx].salt = salt
        accounts[idx].rounds = 120_000
        accounts[idx].hash = Self.pbkdf2(newPassword, salt: salt, rounds: 120_000)
        persist()
        return .success(())
    }

    // MARK: Helpers

    private func persist() {
        store.saveAuth(AuthState(accounts: accounts, session: currentEmail))
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Simple, intentionally permissive check.
        let parts = email.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !email.contains(" ")
    }

    private func randomSalt(_ count: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) {
            diff |= x ^ y
        }
        return diff == 0
    }

    /// PBKDF2-HMAC-SHA256.
    static func pbkdf2(_ password: String, salt: Data, rounds: Int, keyLength: Int = 32) -> Data {
        let pw = Array(password.utf8).map { Int8(bitPattern: $0) }
        let saltBytes = [UInt8](salt)
        var derived = [UInt8](repeating: 0, count: keyLength)
        _ = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            pw,
            pw.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(rounds),
            &derived,
            keyLength
        )
        return Data(derived)
    }
}
