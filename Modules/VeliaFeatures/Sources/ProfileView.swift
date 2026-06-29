import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Settings / profile. Lets the user change the inputs that seed the prediction prior — average
/// cycle length, cycle regularity (segment), and optional birth year — after onboarding.
struct ProfileView: View {
    let store: CycleStore
    @Environment(LockManager.self) private var lock
    @Environment(LanguageManager.self) private var lang
    @Environment(ProfileStore.self) private var profiles
    @Environment(ReminderManager.self) private var reminders
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(StoreKitService.self) private var storeKit
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var confirmDeleteAccount = false

    @State private var cycleLength: Int
    @State private var periodLength: Int
    @State private var segment: Segment
    @State private var includeAge: Bool
    @State private var birthYear: Int
    @State private var iconOption: AppIconOption = .primary

    private let years = Array(1955 ... 2012).reversed()

    init(store: CycleStore) {
        self.store = store
        _cycleLength = State(initialValue: store.profile.typicalCycleLength ?? 28)
        _periodLength = State(initialValue: store.typicalPeriodLength)
        _segment = State(initialValue: store.profile.segment)
        _includeAge = State(initialValue: store.profile.birthYear != nil)
        _birthYear = State(initialValue: store.profile.birthYear ?? 1995)
    }

    private var subscriptionSection: some View {
        Section {
            switch subscription.status {
            case let .trial(daysLeft):
                LabeledContent(L2("Gói", "Plan"), value: L2("Miễn phí (dùng thử)", "Free (trial)"))
                LabeledContent(
                    L2("Còn lại", "Trial left"),
                    value: L2("\(daysLeft) ngày", "\(daysLeft) days")
                )
                Button { showPaywall = true } label: {
                    Label(L2("Nâng cấp lên Premium", "Upgrade to Premium"), systemImage: "sparkles")
                }
            case let .premium(renewal):
                LabeledContent(L2("Gói", "Plan"), value: "Premium")
                LabeledContent(L2("Gia hạn", "Renews"), value: dateString(renewal))
                Button(role: .destructive) {
                    Task { await storeKit.manageSubscriptions() }
                } label: {
                    Label(L2("Hủy đăng ký", "Cancel Subscription"), systemImage: "xmark.circle")
                }
            case .expired:
                LabeledContent(L2("Gói", "Plan"), value: L2("Miễn phí (đã hết dùng thử)", "Free (trial ended)"))
                Button { showPaywall = true } label: {
                    Label(L2("Nâng cấp lên Premium", "Upgrade to Premium"), systemImage: "sparkles")
                }
            }
        } header: {
            Text(L2("Gói đăng ký", "Subscription"))
        } footer: {
            #if DEBUG
                // Dev-only helpers so the paywall gate can be exercised without waiting 7 days.
                // Compiled out of Release builds — never ships to users.
                HStack {
                    Button(L2("Thử: hết hạn dùng thử", "Test: expire trial")) {
                        subscription.expireTrialForTesting()
                        dismiss() // reveal the paywall gate
                    }
                    Spacer()
                    Button(L2("Đặt lại dùng thử", "Reset trial")) {
                        subscription.resetTrialForTesting()
                    }
                }
                .font(.caption2)
            #endif
        }
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
        df.dateStyle = .medium
        return df.string(from: date)
    }

    /// Binding that writes a reminder setting and reschedules notifications.
    private func reminderBinding<T>(_ keyPath: ReferenceWritableKeyPath<ReminderManager, T>) -> Binding<T> {
        Binding(
            get: { reminders[keyPath: keyPath] },
            set: { reminders[keyPath: keyPath] = $0; Task { await reminders.apply(store: store) } }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        L2(
                            "Độ dài chu kỳ trung bình: \(cycleLength) ngày",
                            "Average cycle length: \(cycleLength) days"
                        ),
                        value: $cycleLength,
                        in: 18 ... 60
                    )
                    Stepper(
                        L2(
                            "Số ngày hành kinh: \(periodLength) ngày",
                            "Period length: \(periodLength) days"
                        ),
                        value: $periodLength,
                        in: 1 ... 10
                    )
                } header: {
                    Text(L2("Chu kỳ", "Cycle"))
                } footer: {
                    Text(L2(
                        "Độ dài chu kỳ = khoảng cách giữa hai lần bắt đầu kỳ kinh. " +
                            "Số ngày hành kinh = kỳ kinh kéo dài bao lâu (thường 2–6 ngày). " +
                            "Velia dùng các số này khi chưa đủ dữ liệu, rồi tự học từ nhật ký của bạn.",
                        "Cycle length = the gap between two period starts. " +
                            "Period length = how long a period lasts (typically 2–6 days). " +
                            "Velia uses these until it has enough data, then learns from your logs."
                    ))
                }

                Section {
                    Picker(L2("Mức độ đều", "Regularity"), selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text(L.segment($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(L2("Tình trạng chu kỳ", "Cycle status"))
                } footer: {
                    Text(L2(
                        "Chu kỳ càng thất thường, Velia càng để khoảng dự đoán rộng hơn cho trung thực.",
                        "The more irregular your cycle, the wider Velia keeps its prediction range — to stay honest."
                    ))
                }

                Section {
                    Toggle(L2("Thêm năm sinh", "Add birth year"), isOn: $includeAge)
                    if includeAge {
                        Picker(L2("Năm sinh", "Birth year"), selection: $birthYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                } footer: {
                    Text(L2(
                        "Tùy chọn. Dữ liệu chỉ ở trên máy này — không tài khoản, không gửi đi đâu cả.",
                        "Optional. Your data stays on this device — no account, never sent anywhere."
                    ))
                }

                subscriptionSection

                Section {
                    if let email = auth.currentEmail {
                        LabeledContent(L2("Email", "Email"), value: email)
                    }
                    Button(role: .destructive) {
                        dismiss()
                        auth.logOut()
                    } label: {
                        Label(L2("Đăng xuất", "Log out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        confirmDeleteAccount = true
                    } label: {
                        Label(L2("Xóa tài khoản", "Delete Account"), systemImage: "trash")
                    }
                } header: {
                    Text(L2("Tài khoản", "Account"))
                }

                Section {
                    NavigationLink {
                        ProfilesManagementView()
                    } label: {
                        Label(L2("Hồ sơ người dùng", "Profiles"), systemImage: "person.2.fill")
                    }
                    Button {
                        dismiss()
                        profiles.lockToGate()
                    } label: {
                        Label(L2("Đổi hồ sơ / khóa", "Switch profile / lock"), systemImage: "arrow.left.arrow.right")
                    }
                } header: {
                    Text(L2("Hồ sơ", "Profiles"))
                }

                Section {
                    Picker(L2("Ngôn ngữ", "Language"), selection: Binding(
                        get: { lang.language }, set: { lang.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(L2("Ngôn ngữ", "Language"))
                }

                Section {
                    Toggle(
                        L2("Nhắc kỳ kinh sắp tới", "Upcoming period reminder"),
                        isOn: reminderBinding(\.periodReminderEnabled)
                    )
                    if reminders.periodReminderEnabled {
                        Stepper(
                            L2("Báo trước \(reminders.periodLeadDays) ngày", "\(reminders.periodLeadDays) days before"),
                            value: reminderBinding(\.periodLeadDays),
                            in: 0 ... 5
                        )
                    }
                    if store.mode == .conceive {
                        Toggle(
                            L2("Nhắc cửa sổ dễ thụ thai", "Fertile window reminder"),
                            isOn: reminderBinding(\.fertileReminderEnabled)
                        )
                    }
                    Toggle(
                        L2("Nhắc ghi nhật ký hằng ngày", "Daily log reminder"),
                        isOn: reminderBinding(\.logNudgeEnabled)
                    )
                    if reminders.logNudgeEnabled {
                        Stepper(
                            L2("Lúc \(reminders.logNudgeHour) giờ", "At \(reminders.logNudgeHour):00"),
                            value: reminderBinding(\.logNudgeHour),
                            in: 6 ... 23
                        )
                    }
                } header: {
                    Text(L2("Nhắc nhở", "Reminders"))
                } footer: {
                    Text(L2(
                        "Thông báo cục bộ trên máy — không gửi đi đâu cả.",
                        "Local notifications on this device — nothing is sent anywhere."
                    ))
                }

                Section {
                    Toggle(L2("Khóa ứng dụng (Face ID / mật mã)", "App lock (Face ID / passcode)"), isOn: Binding(
                        get: { lock.isEnabled }, set: { lock.isEnabled = $0 }
                    ))
                } header: {
                    Text(L2("Riêng tư", "Privacy"))
                } footer: {
                    Text(L2(
                        "Yêu cầu Face ID, Touch ID hoặc mật mã mỗi khi mở Velia. Màn hình cũng được che khi chuyển ứng dụng.",
                        "Requires Face ID, Touch ID or your passcode each time you open Velia. The screen is also hidden in the app switcher."
                    ))
                }

                if AppIconOption.supported {
                    Section {
                        Picker(L2("Biểu tượng", "Icon"), selection: $iconOption) {
                            ForEach(AppIconOption.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .onChange(of: iconOption) { _, new in AppIconOption.apply(new) }
                    } header: {
                        Text(L2("Biểu tượng ứng dụng", "App icon"))
                    } footer: {
                        Text(L2(
                            "Biểu tượng trung tính giúp Velia kín đáo trên màn hình chính. " +
                                "Lưu ý: iOS không cho đổi tên hiển thị khi đang chạy — chỉ đổi được biểu tượng.",
                            "A neutral icon keeps Velia discreet on your home screen. " +
                                "Note: iOS can't change the display name at runtime — only the icon."
                        ))
                    }
                }

                if let avg = store.averageCycleLength {
                    Section(L2("Từ dữ liệu của bạn", "From your data")) {
                        LabeledContent(
                            L2("Độ dài chu kỳ thực tế", "Actual cycle length"),
                            value: L2("\(avg) ngày", "\(avg) days")
                        )
                        LabeledContent(L2("Số chu kỳ đã ghi", "Cycles logged"), value: "\(store.loggedCycleCount)")
                    }
                }
            }
            .navigationTitle(L2("Cài đặt", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .task { iconOption = AppIconOption.current }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onClose: { showPaywall = false })
            }
            .confirmationDialog(
                L2("Xóa tài khoản?", "Delete account?"),
                isPresented: $confirmDeleteAccount,
                titleVisibility: .visible
            ) {
                Button(L2("Xóa tài khoản", "Delete Account"), role: .destructive) {
                    dismiss()
                    auth.deleteCurrentAccount()
                }
                Button(L2("Hủy", "Cancel"), role: .cancel) {}
            } message: {
                Text(L2(
                    "Tài khoản của bạn sẽ bị xóa khỏi thiết bị này. Hành động này không thể hoàn tác.",
                    "Your account will be removed from this device. This can't be undone."
                ))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L2("Hủy", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L2("Lưu", "Save")) {
                        store.updateProfile(
                            typicalCycleLength: cycleLength,
                            segment: segment,
                            birthYear: includeAge ? birthYear : nil,
                            periodLength: periodLength
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
                }
            }
        }
    }
}
