import SwiftUI
import VeliaDesignSystem

/// Login / sign-up gate. Clean, modern, on-brand. Email+password fully functional on-device;
/// "Continue with Apple" is stubbed (real Sign in with Apple needs the paid Developer entitlement).
struct AuthView: View {
    @Environment(AuthManager.self) private var auth

    private enum Mode { case login, signUp }
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var showForgot = false
    @State private var showAppleNote = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacingLarge) {
                Spacer(minLength: 40)
                Image(systemName: "drop.fill").font(.system(size: 52)).foregroundStyle(Theme.accent)
                Text("Velia").font(.largeTitle.bold())
                Text(L2("Riêng tư, của riêng bạn.", "Private, yours alone."))
                    .font(.subheadline).foregroundStyle(.secondary)

                Picker("", selection: $mode) {
                    Text(L2("Đăng nhập", "Log in")).tag(Mode.login)
                    Text(L2("Đăng ký", "Sign up")).tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in error = nil }

                VStack(spacing: Theme.spacing) {
                    field(L2("Email", "Email"), text: $email, secure: false)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    field(L2("Mật khẩu", "Password"), text: $password, secure: true)
                    if mode == .signUp {
                        field(L2("Nhập lại mật khẩu", "Confirm password"), text: $confirm, secure: true)
                    }
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    Text(mode == .login ? L2("Đăng nhập", "Log in") : L2("Tạo tài khoản", "Create account"))
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                if mode == .login {
                    Button(L2("Quên mật khẩu?", "Forgot password?")) { showForgot = true }
                        .font(.footnote).tint(Theme.accent)
                }

                HStack { line; Text(L2("hoặc", "or")).font(.caption).foregroundStyle(.secondary); line }

                Button { showAppleNote = true } label: {
                    Label(L2("Tiếp tục với Apple", "Continue with Apple"), systemImage: "apple.logo")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Text(L2("Tài khoản & mật khẩu được mã hóa, lưu trên máy — không máy chủ.",
                        "Account & password are encrypted on-device — no server."))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Theme.screen)
        .sheet(isPresented: $showForgot) { ForgotPasswordView() }
        .alert(L2("Sắp ra mắt", "Coming soon"), isPresented: $showAppleNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(L2("Đăng nhập với Apple cần tài khoản Apple Developer trả phí. Hãy dùng email & mật khẩu.",
                    "Sign in with Apple requires a paid Apple Developer account. Please use email & password for now."))
        }
    }

    private var line: some View { Rectangle().fill(.secondary.opacity(0.3)).frame(height: 1) }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure { SecureField(placeholder, text: text) }
            else { TextField(placeholder, text: text) }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func submit() {
        error = nil
        let result: Result<Void, AuthError>
        switch mode {
        case .login:
            result = auth.logIn(email: email, password: password)
        case .signUp:
            guard password == confirm else {
                error = L2("Mật khẩu nhập lại không khớp.", "Passwords don't match."); return
            }
            result = auth.signUp(email: email, password: password)
        }
        if case .failure(let e) = result { error = e.message }
        // On success the auth gate switches to the app automatically.
    }
}

/// Local password reset (no email service on-device): verify the email exists, set a new password.
private struct ForgotPasswordView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var newPassword = ""
    @State private var error: String?
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L2("Email", "Email"), text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(L2("Mật khẩu mới", "New password"), text: $newPassword)
                } footer: {
                    Text(L2("Vì dữ liệu chỉ ở trên máy, bạn đặt lại mật khẩu ngay tại đây (không qua email).",
                            "Since data is on-device, you reset the password right here (no email link)."))
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                if done { Text(L2("Đã đặt lại mật khẩu.", "Password reset.")).foregroundStyle(.green).font(.footnote) }
            }
            .navigationTitle(L2("Đặt lại mật khẩu", "Reset password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L2("Đóng", "Close")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L2("Đặt lại", "Reset")) {
                        switch auth.resetPassword(email: email, newPassword: newPassword) {
                        case .success: error = nil; done = true
                        case .failure(let e): error = e.message
                        }
                    }.tint(Theme.accent)
                }
            }
        }
    }
}
