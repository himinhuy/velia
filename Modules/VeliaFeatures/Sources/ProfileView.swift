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
    @Environment(\.dismiss) private var dismiss

    @State private var cycleLength: Int
    @State private var periodLength: Int
    @State private var segment: Segment
    @State private var includeAge: Bool
    @State private var birthYear: Int
    @State private var iconOption: AppIconOption = .primary

    private let years = Array(1955...2012).reversed()

    init(store: CycleStore) {
        self.store = store
        _cycleLength = State(initialValue: store.profile.typicalCycleLength ?? 28)
        _periodLength = State(initialValue: store.typicalPeriodLength)
        _segment = State(initialValue: store.profile.segment)
        _includeAge = State(initialValue: store.profile.birthYear != nil)
        _birthYear = State(initialValue: store.profile.birthYear ?? 1995)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(L2("Độ dài chu kỳ trung bình: \(cycleLength) ngày",
                               "Average cycle length: \(cycleLength) days"),
                            value: $cycleLength, in: 18...60)
                    Stepper(L2("Số ngày hành kinh: \(periodLength) ngày",
                               "Period length: \(periodLength) days"),
                            value: $periodLength, in: 1...10)
                } header: {
                    Text(L2("Chu kỳ", "Cycle"))
                } footer: {
                    Text(L2("Độ dài chu kỳ = khoảng cách giữa hai lần bắt đầu kỳ kinh. Số ngày hành kinh = kỳ kinh kéo dài bao lâu (thường 2–6 ngày). Velia dùng các số này khi chưa đủ dữ liệu, rồi tự học từ nhật ký của bạn.",
                            "Cycle length = the gap between two period starts. Period length = how long a period lasts (typically 2–6 days). Velia uses these until it has enough data, then learns from your logs."))
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
                    Text(L2("Chu kỳ càng thất thường, Velia càng để khoảng dự đoán rộng hơn cho trung thực.",
                            "The more irregular your cycle, the wider Velia keeps its prediction range — to stay honest."))
                }

                Section {
                    Toggle(L2("Thêm năm sinh", "Add birth year"), isOn: $includeAge)
                    if includeAge {
                        Picker(L2("Năm sinh", "Birth year"), selection: $birthYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                } footer: {
                    Text(L2("Tùy chọn. Dữ liệu chỉ ở trên máy này — không tài khoản, không gửi đi đâu cả.",
                            "Optional. Your data stays on this device — no account, never sent anywhere."))
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
                    Toggle(L2("Khóa ứng dụng (Face ID / mật mã)", "App lock (Face ID / passcode)"), isOn: Binding(
                        get: { lock.isEnabled }, set: { lock.isEnabled = $0 }
                    ))
                } header: {
                    Text(L2("Riêng tư", "Privacy"))
                } footer: {
                    Text(L2("Yêu cầu Face ID, Touch ID hoặc mật mã mỗi khi mở Velia. Màn hình cũng được che khi chuyển ứng dụng.",
                            "Requires Face ID, Touch ID or your passcode each time you open Velia. The screen is also hidden in the app switcher."))
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
                        Text(L2("Biểu tượng trung tính giúp Velia kín đáo trên màn hình chính. Lưu ý: iOS không cho đổi tên hiển thị khi đang chạy — chỉ đổi được biểu tượng.",
                                "A neutral icon keeps Velia discreet on your home screen. Note: iOS can't change the display name at runtime — only the icon."))
                    }
                }

                if let avg = store.averageCycleLength {
                    Section(L2("Từ dữ liệu của bạn", "From your data")) {
                        LabeledContent(L2("Độ dài chu kỳ thực tế", "Actual cycle length"),
                                       value: L2("\(avg) ngày", "\(avg) days"))
                        LabeledContent(L2("Số chu kỳ đã ghi", "Cycles logged"), value: "\(store.loggedCycleCount)")
                    }
                }
            }
            .navigationTitle(L2("Cài đặt", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .task { iconOption = AppIconOption.current }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L2("Hủy", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L2("Lưu", "Save")) {
                        store.updateProfile(typicalCycleLength: cycleLength,
                                            segment: segment,
                                            birthYear: includeAge ? birthYear : nil,
                                            periodLength: periodLength)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
                }
            }
        }
    }
}
