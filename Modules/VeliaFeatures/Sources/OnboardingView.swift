import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// First-run flow. Step 1 picks the tracking mode (it shapes what we ask next); step 2 is the intake
/// that seeds the engine's prior (PRD §4.4). For "track without a period" the cycle questions are
/// skipped, since there's no cycle to forecast.
struct OnboardingView: View {
    let store: CycleStore

    @State private var mode: TrackingMode?
    @State private var lastPeriod = Calendar.current.startOfDay(for: Date())
    @State private var knowsLastPeriod = true
    @State private var cycleLength = 28
    @State private var periodLength = 5
    @State private var segment: Segment = .typical
    @State private var includeAge = false
    @State private var birthYear = 1995

    private let years = Array(1955...2012).reversed()
    private var asksCycle: Bool { mode?.predictsCycle ?? true }

    var body: some View {
        if mode == nil {
            ModePickerView(current: nil, isOnboarding: true,
                           onConfirm: { mode = $0 },
                           onCancel: {})
        } else {
            intake
        }
    }

    private var intake: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L2("Chào mừng đến với Velia", "Welcome to Velia"))
                        .font(.title2.bold())
                    Text(L2("Vài câu hỏi nhanh để Velia hữu ích ngay từ hôm nay. Bạn luôn có thể chỉnh lại sau.",
                            "A few quick questions so Velia is useful from day one. You can change these anytime."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if asksCycle {
                    Section(L2("Kỳ kinh gần nhất", "Last period")) {
                        Toggle(L2("Tôi nhớ ngày bắt đầu", "I remember the start date"), isOn: $knowsLastPeriod)
                        if knowsLastPeriod {
                            DatePicker(L2("Ngày bắt đầu", "Start date"), selection: $lastPeriod,
                                       in: ...Date(), displayedComponents: .date)
                        }
                    }

                    Section(L2("Độ dài chu kỳ thường gặp", "Typical cycle length")) {
                        Stepper(L2("\(cycleLength) ngày", "\(cycleLength) days"), value: $cycleLength, in: 18...60)
                        Text(L2("Khoảng cách giữa hai lần bắt đầu kỳ kinh. Mặc định 28 ngày.",
                                "The gap between two period starts. Default is 28 days."))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section(L2("Số ngày hành kinh", "Period length")) {
                        Stepper(L2("\(periodLength) ngày", "\(periodLength) days"), value: $periodLength, in: 1...10)
                        Text(L2("Kỳ kinh của bạn thường kéo dài bao nhiêu ngày (thường 2–6 ngày).",
                                "How many days your period usually lasts (typically 2–6 days)."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section(L2("Tình trạng của bạn", "Your situation")) {
                    Picker(L2("Phân nhóm", "Group"), selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text(L.segment($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle(L2("Thêm năm sinh (tùy chọn)", "Add birth year (optional)"), isOn: $includeAge)
                    if includeAge {
                        Picker(L2("Năm sinh", "Birth year"), selection: $birthYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                } footer: {
                    Text(L2("Tuổi giúp tinh chỉnh dự đoán. Dữ liệu chỉ ở trên máy của bạn.",
                            "Age helps refine predictions. Your data stays on this device."))
                }

                Section {
                    Button { finish() } label: {
                        Text(L2("Bắt đầu", "Get started")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { mode = nil } label: { Label(L2("Chế độ", "Mode"), systemImage: "chevron.left") }
                        .tint(Theme.accent)
                }
            }
        }
    }

    private func finish() {
        let profile = UserProfile(
            birthYear: includeAge ? birthYear : nil,
            typicalCycleLength: asksCycle ? cycleLength : nil,
            segment: segment
        )
        store.completeOnboarding(
            mode: mode ?? .period,
            profile: profile,
            lastPeriodStart: (asksCycle && knowsLastPeriod) ? lastPeriod : nil,
            periodLength: periodLength
        )
    }
}
